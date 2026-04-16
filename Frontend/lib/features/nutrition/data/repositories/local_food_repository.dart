import '../../domain/entities/food_item.dart';
import '../../domain/repositories/food_repository.dart';
import '../datasources/asset_food_loader.dart';
import '../datasources/hive_diet_storage.dart';
import '../datasources/open_food_facts_client.dart';
import '../../../recipes/data/recipe_loader.dart';
import '../../../recipes/domain/entities/recipe.dart';

/// Local yiyecek listesi: JSON asset + kullanıcının eklediği özel yemekler (Hive).
/// Arama: name, aliases, tags, category tarar; Türkçe normalizasyon + basit fuzzy.
class LocalFoodRepository implements FoodRepository {
  List<FoodItem>? _assetCache;
  List<FoodItem>? _customCache;
  List<FoodItem>? _recipeCache;
  Map<String, List<String>>? _synonyms;
  final Map<String, _IndexedFood> _indexCache = {};
  List<FoodItem>? _visiblePoolCache;
  final Map<String, List<FoodItem>> _emptyQueryCache = {};
  final Map<String, List<FoodItem>> _searchCache = {};
  final HiveDietStorage _hive;
  final bool _shouldLoadVerifiedExtras;

  LocalFoodRepository({
    List<FoodItem>? assetCache,
    List<FoodItem>? customCache,
    List<FoodItem>? recipeCache,
    Map<String, List<String>>? synonyms,
    HiveDietStorage? hive,
    bool? shouldLoadVerifiedExtras,
  }) : _assetCache = assetCache,
       _customCache = customCache,
       _recipeCache = recipeCache,
       _synonyms = synonyms,
       _hive = hive ?? HiveDietStorage(),
       _shouldLoadVerifiedExtras =
           shouldLoadVerifiedExtras ?? assetCache == null;

  static const Set<String> _turkishPriorityTokens = {
    'yumurta',
    'haslanmis yumurta',
    'menemen',
    'omlet',
    'beyaz peynir',
    'kasar',
    'zeytin',
    'domates',
    'salatalik',
    'yogurt',
    'ayran',
    'kefir',
    'sut',
    'yulaf',
    'yulaf ezmesi',
    'muz',
    'elma',
    'portakal',
    'corba',
    'mercimek corbasi',
    'tavuk',
    'tavuk gogsu',
    'tavuk doner',
    'tavuk durum',
    'tavuk tantuni',
    'et',
    'et durum',
    'durum',
    'doner',
    'tantuni',
    'cig kofte',
    'cig kofte durum',
    'pizza',
    'hamburger',
    'burger',
    'sandvic',
    'tost',
    'lahmacun',
    'pide',
    'kofte',
    'kiyma',
    'pirinc',
    'pirinc pilavi',
    'bulgur',
    'bulgur pilavi',
    'makarna',
    'kurufasulye',
    'nohut',
    'fasulye',
    'pilav',
    'ton baligi',
    'somon',
    'patates',
    'ekmek',
    'simit',
    'baklava',
    'humus',
    'kahve',
    'cay',
  };

  static const Set<String> _turkishPatternTokens = {
    'corba',
    'pilav',
    'kebap',
    'durum',
    'doner',
    'tantuni',
    'pizza',
    'burger',
    'sandvic',
    'lahmacun',
    'pide',
    'kofte',
    'dolma',
    'sarma',
    'borek',
    'pogaca',
    'gozleme',
    'menemen',
    'omlet',
    'ayran',
    'cig kofte',
    'yogurt',
    'peynir',
    'zeytin',
    'kahvalti',
    'mercimek',
    'bulgur',
    'kurufasulye',
    'nohut',
    'makarna',
    'tavuk',
    'balik',
    'salata',
  };

  Future<void> _ensureLoaded() async {
    _assetCache ??= await AssetFoodLoader.loadFoods();
    _customCache ??= await _hive.getCustomFoods();
    _recipeCache ??= await _loadRecipeFoods();
    _synonyms ??= await AssetFoodLoader.loadSynonyms();

    if (_shouldLoadVerifiedExtras &&
        _assetCache != null &&
        !_assetCache!.any((food) => food.id.startsWith('trverified_'))) {
      final verifiedExtras = await AssetFoodLoader.loadVerifiedExtrasFoods();
      if (verifiedExtras.isNotEmpty) {
        final knownIds = _assetCache!.map((food) => food.id).toSet();
        final missingExtras = verifiedExtras
            .where((food) => !knownIds.contains(food.id))
            .toList();

        if (missingExtras.isNotEmpty) {
          _assetCache = [...missingExtras, ..._assetCache!];
          _indexCache.clear();
          _visiblePoolCache = null;
          _emptyQueryCache.clear();
          _searchCache.clear();
        }
      }
    }
  }

  /// Türkçe karakterleri normalize eder, özel karakterleri temizler
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp('[\u0307\u0327\u0308\u0306\u0302]'), '')
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }

  /// Kelime sınırında sorgu eşleşmesi (örn. "tavuk" -> "Tavuklu pilav" içinde kelime başı)
  static bool _wordStartsWith(String text, String query) {
    if (query.isEmpty) return false;
    final idx = text.indexOf(query);
    if (idx < 0) return false;
    if (idx == 0) return true;
    return text[idx - 1] == ' ' || text[idx - 1] == '\t';
  }

  /// Sorgu, metinde tam kelime olarak geçiyor mu? (kelime sınırları boşluk veya string ucu)
  static bool _isWholeWord(String text, String query) {
    if (query.isEmpty) return false;
    final idx = text.indexOf(query);
    if (idx < 0) return false;
    final afterIdx = idx + query.length;
    final startOk = idx == 0 || text[idx - 1] == ' ' || text[idx - 1] == '\t';
    final endOk =
        afterIdx == text.length ||
        text[afterIdx] == ' ' ||
        text[afterIdx] == '\t';
    return startOk && endOk;
  }

  static bool _startsWithWholeWord(String text, String query) {
    if (!text.startsWith(query) || query.isEmpty) return false;
    final afterIdx = query.length;
    return afterIdx == text.length ||
        text[afterIdx] == ' ' ||
        text[afterIdx] == '\t';
  }

  /// Levenshtein mesafesi 1 veya 2 (kısa kelimelerde 1, uzunlarda 2)
  static int _levenshtein(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length, n = b.length;
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      d[0][j] = j;
    }
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
    }
    return d[m][n];
  }

  /// Tek kelime için fuzzy eşleşme: 1–2 harf hatası kabul (makrna -> makarna)
  static bool _fuzzyMatch(String normalizedQuery, String token) {
    if (token.isEmpty || normalizedQuery.isEmpty) return false;
    if (token == normalizedQuery) return true;
    if (token.contains(normalizedQuery) || normalizedQuery.contains(token)) {
      return true;
    }
    final len = normalizedQuery.length;
    if (len < 3) return false;
    final dist = _levenshtein(normalizedQuery, token);
    return (len <= 5 && dist <= 1) || (len > 5 && dist <= 2);
  }

  static bool _containsToken(String text, String token) {
    if (token.isEmpty) return false;
    return text.contains(token) || _wordStartsWith(text, token);
  }

  static Set<String> _queryVariants(String query) {
    final variants = <String>{query};

    void addIfMeaningful(String value) {
      final cleaned = value.trim();
      if (cleaned.length >= 3) {
        variants.add(cleaned);
      }
    }

    addIfMeaningful(query.replaceAll('&', ' ve '));
    addIfMeaningful(query.replaceAll('&', ' '));
    addIfMeaningful(query.replaceAll('/', ' '));

    const directReplacements = {
      'hamburger': 'burger',
      'burger': 'hamburger',
      'cheeseburger': 'cheese burger',
      'cheese burger': 'cheeseburger',
      'tavuk burger': 'chicken burger',
      'chicken burger': 'tavuk burger',
    };

    for (final entry in directReplacements.entries) {
      if (query.contains(entry.key)) {
        addIfMeaningful(query.replaceAll(entry.key, entry.value));
        addIfMeaningful(entry.value);
      }
    }

    const suffixReplacements = {
      'corbasi': 'corba',
      'kebabi': 'kebap',
      'koftesi': 'kofte',
      'pilavi': 'pilav',
      'tatlisi': 'tatli',
      'salatasi': 'salata',
      'dolmasi': 'dolma',
      'sarmasi': 'sarma',
      'kizartmasi': 'kizartma',
      'haslamasi': 'haslama',
    };

    for (final entry in suffixReplacements.entries) {
      if (query.contains(entry.key)) {
        addIfMeaningful(query.replaceAll(entry.key, entry.value));
      }
    }

    return variants;
  }

  void invalidateCache() {
    _customCache = null;
    _recipeCache = null;
    _indexCache.clear();
    _visiblePoolCache = null;
    _emptyQueryCache.clear();
    _searchCache.clear();
  }

  List<FoodItem> _userFacingPool() {
    return _visiblePoolCache ??= [
      ..._customCache!,
      ..._recipeCache!,
      ..._assetCache!,
    ].where(_isUserFacingFood).toList(growable: false);
  }

  Future<List<FoodItem>> _loadRecipeFoods() async {
    final recipes = await RecipeLoader.loadAll();
    return recipes.map(_mapRecipeToFoodItem).toList(growable: false);
  }

  static FoodItem _mapRecipeToFoodItem(Recipe recipe) {
    final category = _recipeFoodCategory(recipe);
    final aliases = {
      recipe.name,
      if (recipe.category == 'bowl') '${recipe.name} bowl',
      if (recipe.category == 'smoothie') '${recipe.name} smoothie',
    }.toList();
    final tags = {
      'tarif',
      'recipe',
      recipe.category,
      recipe.difficulty,
      ...recipe.tags,
    }.toList();

    return FoodItem(
      id: 'recipe_${recipe.id}',
      name: recipe.name,
      category: category,
      basis: const FoodBasis(amount: 1, unit: 'portion'),
      nutrients: Nutrients(
        kcal: recipe.kcalPerServing,
        protein: recipe.proteinPerServing,
        carb: recipe.carbPerServing,
        fat: recipe.fatPerServing,
      ),
      servings: const [
        ServingUnit(
          id: 'recipe_portion',
          label: '1 Porsiyon',
          grams: 100,
          isDefault: true,
        ),
      ],
      aliases: aliases,
      tags: tags,
    );
  }

  static String _recipeFoodCategory(Recipe recipe) {
    final normalizedTags = recipe.tags.map(normalize).toList();
    if (normalizedTags.any((tag) => tag.contains('sabah')) ||
        normalizedTags.any((tag) => tag.contains('kahvalti')) ||
        normalizedTags.any((tag) => tag.contains('kahvaltilik'))) {
      return 'Kahvaltılık';
    }
    if (recipe.category == 'salata') return 'Salata';
    if (recipe.category == 'smoothie' ||
        recipe.category == 'atistirmalik' ||
        normalizedTags.any((tag) => tag.contains('ara ogun')) ||
        normalizedTags.any((tag) => tag.contains('pre-workout')) ||
        normalizedTags.any((tag) => tag.contains('post-workout'))) {
      return 'Atıştırmalık';
    }
    return 'Yemek';
  }

  List<FoodItem> _poolForCategory(String? category) {
    final base = _userFacingPool();
    if (category == null || category == 'Tümü') return base;
    return base.where((f) => f.category == category).toList(growable: false);
  }

  static bool _looksMachineTranslated(String value) {
    final name = normalize(value);
    if (name.isEmpty) return false;

    const bannedPhrases = {
      ' from ',
      ' made ',
      ' school lunch',
      ' school cafeteria',
      ' thin crust',
      ' thick crust',
      ' medium crust',
      ' stuffed crust',
      ' dondurulmus',
      ' sandvic wrap',
      ' and ',
      ' with ',
      ' or ',
      ' not ',
      ' for ',
      ' into ',
    };

    final padded = ' $name ';
    for (final phrase in bannedPhrases) {
      if (padded.contains(phrase)) return true;
    }

    return false;
  }

  // İngilizce USDA teknik ve hazırlık terimleri — Türkçe yemek adında geçmemeli
  static const Set<String> _foreignNoiseTokens = {
    // Egzotik / yabancı mutfak
    'abalon', 'adobo', 'ambrosia', 'antipasto', 'arepa', 'armadillo',
    'bagel', 'barfi', 'burfi', 'biscuit', 'blackeyed', 'chowder',
    'coleslaw', 'cornbread', 'croissant', 'english muffin', 'griddle',
    'horseradish', 'jute', 'mousse', 'tapenade', 'timbale', 'zwieback',
    'pretzel', 'muffin', 'waffle', 'pancake', 'brownie', 'cupcake',
    'cheesecake', 'corndog', 'hotdog', 'hot dog', 'beef jerky',
    // USDA yapısal/işlem tanımlayıcıları
    'restructured', 'multigrain', 'whole grain', 'multicolor',
    'enriched', 'fortified', 'textured', 'extruded', 'reconstituted',
    'hydrolyzed', 'emulsified', 'dehydrated', 'powdered', 'modified',
    'composite', 'substitute', 'imitation', 'analog', 'analogue',
    'pasteurized', 'homogenized', 'ultra pasteurized',
    // İngilizce pişirme/hazırlık tanımlayıcıları
    'broiled', 'scrambled', 'hash brown', 'hash browns', 'creamed',
    'au gratin', 'en papillote', 'blanched', 'parboiled', 'braised',
    // İngilizce besin etiket terimleri
    'nonfat', 'lowfat', 'low fat', 'reduced fat', 'fat free',
    'low sodium', 'no salt', 'sugar free', 'calorie free',
    'low calorie', 'low carb', 'high protein', 'high fiber',
    // USDA survey kalıpları
    'ns as to', 'not specified', 'nos', 'restaurant style',
    'chain restaurant', 'commercially prepared', 'home prepared',
    'home recipe', 'ready to eat', 'heat and serve',
    'fast food restaurant', 'take out', 'carry out',
    // Saf İngilizce yiyecek sıfatları
    'flavored', 'flavoured', 'homestyle', 'assorted', 'variety pack',
    'mixed flavors', 'seasonal', 'gourmet', 'artisan', 'artisanal',
    'organic blend', 'natural flavor',
    // İngilizce hayvan/et kesimleri
    'chuck', 'sirloin', 'tenderloin', 'ribeye', 'brisket',
    'short ribs', 'flank', 'shank', 'loin', 'rump', 'spare ribs',
    'round steak', 'top round', 'bottom round',
    // İngilizce süt ürünü terimleri
    'skim milk', 'whole milk', 'evaporated', 'condensed', 'half and half',
    'heavy cream', 'light cream', 'sour cream', 'cream cheese',
    'cottage cheese', 'ricotta', 'brie', 'camembert', 'gouda',
    // Diğer İngilizce gıda terimleri
    'sourdough', 'pumpernickel', 'rye bread', 'flatbread',
    'pita bread', 'naan', 'focaccia', 'ciabatta',
    'chili', 'chilli', 'salsa', 'guacamole', 'burrito', 'quesadilla',
    'taco', 'nachos', 'enchilada', 'fajita',
    'sushi', 'sashimi', 'tempura', 'miso', 'teriyaki', 'ramen',
    'pad thai', 'dim sum', 'wonton', 'spring roll', 'egg roll',
    'tikka masala', 'curry', 'chutney', 'samosa',
  };

  // Survey_ ID'li yiyecek adlarında geçmemesi gereken İngilizce kelimeler
  static const Set<String> _englishDescriptorWords = {
    'restructured',
    'multigrain',
    'enriched',
    'fortified',
    'flavored',
    'flavoured',
    'textured',
    'extruded',
    'reconstituted',
    'hydrolyzed',
    'dehydrated',
    'powdered',
    'modified',
    'composite',
    'substitute',
    'imitation',
    'pasteurized',
    'homogenized',
    'broiled',
    'scrambled',
    'nonfat',
    'lowfat',
    'reduced',
    'commercial',
    'processed',
    'prepared',
    'homestyle',
    'assorted',
    'variety',
    'seasonal',
    'gourmet',
    'artisan',
    'organic',
    'natural',
    'artificial',
    'frozen',
    'canned',
    'dried',
    'instant',
    'precooked',
    'boneless',
    'skinless',
    'trimmed',
    'untrimmed',
    'breaded',
    'battered',
    'coated',
    'marinated',
    'smoked',
    'cured',
    'salted',
    'unsalted',
    'sweetened',
    'unsweetened',
    'whole',
    'ground',
    'minced',
    'chopped',
    'sliced',
    'diced',
    'shredded',
    'grated',
    'pureed',
    'mashed',
    'creamed',
    'blended',
    'mixed',
    'combined',
    'strained',
    'filtered',
    'clarified',
    'skimmed',
    'chunk',
    'chunks',
    'pieces',
    'strips',
    'bits',
    'style',
    'type',
    'kind',
    'brand',
    'grade',
    'extra',
    'premium',
    'select',
    'choice',
    'prime',
    'regular',
    'standard',
    'generic',
    'store',
    'with',
    'without',
    'added',
    'containing',
    'cooked',
    'uncooked',
    'baked',
    'fried',
    'grilled',
    'roasted',
    'boiled',
    'steamed',
    'sauteed',
    'poached',
    'stewed',
    'simmered',
    'braised',
    'blanched',
  };

  /// Survey_ yiyecek adındaki kelimeleri tek tek kontrol eder;
  /// 4+ harfli, tümü ASCII (Türkçe karakter içermeyen) ve İngilizce
  /// tanımlayıcı listesinde olan herhangi bir kelime varsa true döner.
  static bool _surveyNameContainsEnglish(String rawName) {
    // normalize() Türkçe karakterleri ASCII'ye çevirir, bu yüzden
    // ham isme bakıyoruz — İngilizce sözcükler büyük harf başlar veya
    // tamamen ASCII'dir, Türkçe'de ise en az bir Türkçe harf bulunur.
    final words = rawName.split(RegExp(r'[\s,/()-]+'));
    for (final word in words) {
      if (word.length < 4) continue;
      // Türkçe özel karakter varsa (ğ,ş,ı,ö,ü,ç,İ,Ğ,Ş,Ö,Ü,Ç) → Türkçe kelime
      final hasTurkishChar = word.contains(RegExp(r'[ğşıöüçĞŞİÖÜÇ]'));
      if (hasTurkishChar) continue;
      // Tamamen ASCII ve 4+ harf: İngilizce descriptor listesinde mi?
      final wordLower = word.toLowerCase();
      if (_englishDescriptorWords.contains(wordLower)) return true;
    }
    return false;
  }

  static bool _hasRelevantTurkishSignal(FoodItem food) {
    final fields = <String>[
      normalize(food.name),
      normalize(food.category),
      ...food.aliases.map(normalize),
      ...food.tags.map(normalize),
    ];

    for (final field in fields) {
      for (final token in _turkishPriorityTokens) {
        if (field.contains(token)) return true;
      }
      for (final token in _turkishPatternTokens) {
        if (field.contains(token)) return true;
      }
    }
    return false;
  }

  static bool _containsForeignNoise(FoodItem food) {
    final haystack = normalize(
      [food.name, food.category, ...food.aliases, ...food.tags].join(' '),
    );
    for (final token in _foreignNoiseTokens) {
      if (haystack.contains(token)) return true;
    }
    return false;
  }

  static const Set<String> _excludedAnimalTokens = {
    'domuz',
    'pork',
    'pig',
    'hog',
    'boar',
    'bacon',
    'ham',
    'prosciutto',
    'pancetta',
  };

  static bool _containsExcludedAnimal(FoodItem food) {
    final haystack = normalize(
      [food.name, food.category, ...food.aliases, ...food.tags].join(' '),
    );
    for (final token in _excludedAnimalTokens) {
      if (haystack.contains(token)) return true;
    }
    return false;
  }

  static bool _isSimpleEverydayFood(FoodItem food) {
    const basicCategories = {
      'Kahvaltılık',
      'Süt Ürünleri',
      'Tahıl',
      'Sebze',
      'Meyve',
      'İçecek',
    };
    return basicCategories.contains(food.category) &&
        food.name.length <= 28 &&
        !food.name.contains(',') &&
        !food.name.contains('(') &&
        !_containsForeignNoise(food) &&
        !_looksMachineTranslated(food.name);
  }

  static bool _isUserFacingFood(FoodItem food) {
    if (food.id.startsWith('recipe_')) {
      return true;
    }
    if (_containsExcludedAnimal(food)) {
      return false;
    }
    if (food.id.startsWith('tr_') || food.id.startsWith('trverified_')) {
      return true;
    }
    if (food.tags.any((tag) => normalize(tag) == 'trcore')) {
      return true;
    }
    // Uzun / doğal olmayan USDA çevirisi görünen isimleri filtrele
    if (food.id.startsWith('survey_')) {
      final name = food.name;
      final nameLower = name.toLowerCase();
      final commaCount = ','.allMatches(name).length;
      // "Üzerinde" kalıbı → "pasted on bread" USDA tarifi
      if (nameLower.contains('üzerinde')) return false;
      // 1+ virgül + 45 karakter üzeri → "Döner, Fırında, Üzerinde..." tarzı
      if (commaCount >= 1 && name.length > 45) return false;
      // Tek başına anlamsız sandviç kombinasyonları
      if (name.contains('Sosisli Sandviç') || name.contains('Sandviç Ekmeği')) {
        return false;
      }
      // Çok uzun tek isim (65+ karakter)
      if (name.length > 65) return false;
      // Klasik overdescription
      if (name.contains(' veya ') ||
          name.contains(' ile ') ||
          name.contains(' ve/') ||
          name.contains(' , ')) {
        return false;
      }
    }
    if (food.id.startsWith('survey_')) {
      if (_containsForeignNoise(food)) return false;
      // İsimde İngilizce USDA teknik kelimesi varsa → çevrilmemiş / makine çevirisi
      if (_surveyNameContainsEnglish(food.name)) return false;
      if (!_hasRelevantTurkishSignal(food) && !_isSimpleEverydayFood(food)) {
        return false;
      }
    }
    if (!_looksMachineTranslated(food.name)) {
      return true;
    }

    final aliasLooksClean = food.aliases.any(
      (alias) =>
          !_looksMachineTranslated(alias) && normalize(alias).length >= 4,
    );
    return aliasLooksClean;
  }

  static int _computeTurkishPriorityScore(_IndexedFood food) {
    int score = 0;
    for (final field in food.searchFields) {
      for (final token in _turkishPriorityTokens) {
        if (field.contains(token)) {
          score += 14;
        }
      }
      for (final token in _turkishPatternTokens) {
        if (field.contains(token)) {
          score += 6;
        }
      }
    }

    final name = food.name;
    if (name.contains('turk') || name.contains('turkish')) {
      score += 12;
    }
    if (food.tags.any((tag) => tag == 'trcore')) {
      score += 36;
    }
    if (food.raw.category == 'Kahvaltılık' ||
        food.raw.category == 'Yemek' ||
        food.raw.category == 'Et / Protein' ||
        food.raw.category == 'Tahıl' ||
        food.raw.category == 'Süt Ürünleri') {
      score += 8;
    }
    if (food.brand == null || food.brand!.trim().isEmpty) {
      score += 4;
    }
    return score;
  }

  _IndexedFood _indexFor(FoodItem food) {
    return _indexCache.putIfAbsent(food.id, () {
      final normalizedAliases = food.aliases.map(normalize).toList();
      final normalizedTags = food.tags.map(normalize).toList();
      final indexed = _IndexedFood(
        raw: food,
        name: normalize(food.name),
        category: normalize(food.category),
        brand: food.brand == null ? null : normalize(food.brand!),
        aliases: normalizedAliases,
        tags: normalizedTags,
        searchFields: [
          normalize(food.name),
          normalize(food.category),
          ...normalizedAliases,
          ...normalizedTags,
        ],
      );
      return indexed.copyWith(
        priorityScore: _computeTurkishPriorityScore(indexed),
      );
    });
  }

  @override
  Future<List<FoodItem>> searchFoods(String query, {String? category}) async {
    await _ensureLoaded();

    final normalizedQueryInput = normalize(query.trim());
    final cacheKey = '${category ?? 'all'}|$normalizedQueryInput';
    final cachedResults = _searchCache[cacheKey];
    if (cachedResults != null) {
      return cachedResults;
    }

    final pool = _poolForCategory(category);

    if (normalizedQueryInput.isEmpty) {
      final emptyKey = category ?? 'all';
      final cachedEmpty = _emptyQueryCache[emptyKey];
      if (cachedEmpty != null) {
        return cachedEmpty;
      }
      final sortedPool = [...pool];
      sortedPool.sort((a, b) {
        final aScore = _indexFor(a).priorityScore;
        final bScore = _indexFor(b).priorityScore;
        final byScore = bScore.compareTo(aScore);
        if (byScore != 0) return byScore;
        final byCategory = a.category.compareTo(b.category);
        if (byCategory != 0) return byCategory;
        return a.name.length.compareTo(b.name.length);
      });
      final results = sortedPool.take(280).toList(growable: false);
      _emptyQueryCache[emptyKey] = results;
      return results;
    }

    final normalizedQuery = normalizedQueryInput;
    final queryTokens = normalizedQuery
        .split(' ')
        .where((t) => t.isNotEmpty)
        .toList();

    final searchTerms = _queryVariants(normalizedQuery);
    _synonyms?.forEach((key, values) {
      if (normalize(key).contains(normalizedQuery)) {
        searchTerms.addAll(values.map(normalize));
      }
      for (final v in values) {
        if (normalize(v).contains(normalizedQuery)) {
          searchTerms.add(normalize(key));
        }
      }
    });

    final scoredItems = <_ScoredFood>[];

    for (final food in pool) {
      final indexed = _indexFor(food);
      int score = 0;
      final nName = indexed.name;
      final nCategory = indexed.category;
      final nBrand = indexed.brand;
      final searchableFields = <String>[
        nName,
        nCategory,
        ...(nBrand == null ? const <String>[] : <String>[nBrand]),
        ...indexed.aliases,
        ...indexed.tags,
      ];
      final matchedTokenCount = queryTokens
          .where(
            (token) =>
                searchableFields.any((field) => _containsToken(field, token)),
          )
          .length;
      final exactPhraseMatch = searchableFields.any(
        (field) => field == normalizedQuery || field.contains(normalizedQuery),
      );
      final strongNameMatch =
          nName == normalizedQuery ||
          _startsWithWholeWord(nName, normalizedQuery) ||
          _isWholeWord(nName, normalizedQuery);

      if (queryTokens.length >= 2 &&
          !exactPhraseMatch &&
          matchedTokenCount < queryTokens.length) {
        continue;
      }

      // 1) İsim: tam > başlangıç > tam kelime > kelime başı > içerik
      if (nName == normalizedQuery) {
        score += 100;
      } else if (_startsWithWholeWord(nName, normalizedQuery)) {
        score += 72;
      } else if (_isWholeWord(nName, normalizedQuery)) {
        // "nohutlu pilav" — sorgu isimde tam kelime olarak geçiyor
        score += 58;
        // Son kelimeyse (ana yemek ismi genellikle sonda) ekstra bonus
        if (nName.endsWith(normalizedQuery)) score += 12;
      } else if (_wordStartsWith(nName, normalizedQuery) &&
          !nName.startsWith(normalizedQuery)) {
        // "pilavlı patlıcan" — sorgu bir kelimenin başı, tam kelime değil
        score += 35;
      } else if (nName.startsWith(normalizedQuery)) {
        // "yumurtali" gibi birleşik ilk kelime eşleşmeleri,
        // tam kelime eşleşmesinin önüne geçmemeli.
        score += 24;
      } else if (nName.contains(normalizedQuery)) {
        score += 20;
      }

      // 2) Token bazlı (çok kelimeli sorgu): her token isimde geçiyorsa
      for (final token in queryTokens) {
        if (nName.contains(token)) score += 5;
        if (_startsWithWholeWord(nName, token) ||
            (_wordStartsWith(nName, token) && !nName.startsWith(token))) {
          score += 8;
        }
      }

      // 3) Aliases: tam > başlangıç > içerik (sadece en yüksek puanı al)
      int maxAliasScore = 0;
      for (final nAlias in indexed.aliases) {
        int currentAliasScore = 0;
        if (nAlias == normalizedQuery) {
          currentAliasScore = 40;
        } else if (_startsWithWholeWord(nAlias, normalizedQuery)) {
          currentAliasScore = 35;
        } else if (_isWholeWord(nAlias, normalizedQuery)) {
          currentAliasScore = 30;
        } else if (_wordStartsWith(nAlias, normalizedQuery) &&
            !nAlias.startsWith(normalizedQuery)) {
          currentAliasScore = 25;
        } else if (nAlias.startsWith(normalizedQuery)) {
          currentAliasScore = 18;
        } else if (nAlias.contains(normalizedQuery)) {
          currentAliasScore = 15;
        }
        if (currentAliasScore > maxAliasScore) {
          maxAliasScore = currentAliasScore;
        }
      }
      score += maxAliasScore;

      // 4) Tags: tam > içerik (tavuk yazınca "tavuk" tag'li tüm yemekler - sadece en yüksek puan)
      int maxTagScore = 0;
      for (final nTag in indexed.tags) {
        int currentTagScore = 0;
        if (nTag == normalizedQuery) {
          currentTagScore = 30;
        } else if (nTag.contains(normalizedQuery) ||
            normalizedQuery.contains(nTag)) {
          currentTagScore = 15;
        }
        if (currentTagScore > maxTagScore) {
          maxTagScore = currentTagScore;
        }
      }
      score += maxTagScore;

      // 5) Category: tam > içerik
      if (nCategory == normalizedQuery) {
        score += 25;
      } else if (nCategory.contains(normalizedQuery)) {
        score += 10;
      }

      // 6) Marka
      if (nBrand != null && nBrand.contains(normalizedQuery)) {
        score += 15;
      }

      // 7) Eş anlamlı (synonym)
      if (score == 0) {
        for (final term in searchTerms) {
          if (nName.contains(term)) {
            score += 10;
            break;
          }
          for (final alias in indexed.aliases) {
            if (alias.contains(term)) {
              score += 10;
              break;
            }
          }
        }
      }

      // 8) Basit fuzzy: 1–2 harf hatası (makrna -> makarna)
      if (score == 0 &&
          queryTokens.length == 1 &&
          normalizedQuery.length >= 3) {
        final words = [...nName.split(RegExp(r'\s+'))];
        for (final a in indexed.aliases) {
          words.addAll(a.split(RegExp(r'\s+')));
        }
        for (final t in indexed.tags) {
          words.addAll(t.split(RegExp(r'\s+')));
        }
        for (final w in words) {
          if (w.length >= 2 && _fuzzyMatch(normalizedQuery, w)) {
            score += 12;
            break;
          }
        }
      }

      final queryMentionsBrand =
          nBrand != null && normalizedQuery.contains(nBrand);
      final isGenericQuery = !queryMentionsBrand;

      // Generic aramalarda markasız sonuçları üste taşı.
      if (score > 0 && isGenericQuery) {
        if (food.brand == null || food.brand!.trim().isEmpty) {
          score += 18;
          if (nName.startsWith(normalizedQuery)) {
            score += 14;
          }
        } else {
          score -= 22;
        }
      }

      final minimumScore = switch (queryTokens.length) {
        >= 3 => strongNameMatch ? 18 : 34,
        2 => strongNameMatch ? 14 : 24,
        _ => normalizedQuery.length >= 5 ? 12 : 8,
      };

      if (score > 0) {
        if (score < minimumScore) {
          continue;
        }
        scoredItems.add(_ScoredFood(food, score, indexed.priorityScore));
      }
    }

    scoredItems.sort((a, b) {
      final byScore = b.relevanceScore.compareTo(a.relevanceScore);
      if (byScore != 0) return byScore;
      final byPriority = b.priorityScore.compareTo(a.priorityScore);
      if (byPriority != 0) return byPriority;
      final aBrandless = a.item.brand == null || a.item.brand!.trim().isEmpty;
      final bBrandless = b.item.brand == null || b.item.brand!.trim().isEmpty;
      if (aBrandless != bBrandless) {
        return aBrandless ? -1 : 1;
      }
      return a.item.name.length.compareTo(b.item.name.length);
    });
    final results = scoredItems.map((s) => s.item).toList(growable: false);
    if (_searchCache.length > 80) {
      _searchCache.remove(_searchCache.keys.first);
    }
    _searchCache[cacheKey] = results;
    return results;
  }

  @override
  Future<FoodItem?> getFoodById(String id) async {
    await _ensureLoaded();
    try {
      return _customCache!.firstWhere(
        (f) => f.id == id,
        orElse: () {
          return _assetCache!.firstWhere((f) => f.id == id);
        },
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    await _ensureLoaded();
    try {
      // Önce custom (kullanıcı eklediği barkodlu besinler), sonra lokal JSON
      final customMatch = _customCache
          ?.where((f) => f.barcode == barcode)
          .firstOrNull;
      if (customMatch != null) return customMatch;

      final localMatch = _assetCache
          ?.where((f) => f.barcode == barcode)
          .firstOrNull;
      if (localMatch != null) return localMatch;

      // Eğer lokalde bulamadıysa OpenFoodFacts API üzerinden sorgula
      final offClient = OpenFoodFactsClient();
      final offMatch = await offClient.searchByBarcode(barcode);
      return offMatch;
    } catch (_) {
      return null;
    }
  }
}

class _ScoredFood {
  final FoodItem item;
  final int relevanceScore;
  final int priorityScore;
  _ScoredFood(this.item, this.relevanceScore, this.priorityScore);
}

class _IndexedFood {
  final FoodItem raw;
  final String name;
  final String category;
  final String? brand;
  final List<String> aliases;
  final List<String> tags;
  final List<String> searchFields;
  final int priorityScore;

  const _IndexedFood({
    required this.raw,
    required this.name,
    required this.category,
    required this.brand,
    required this.aliases,
    required this.tags,
    required this.searchFields,
    this.priorityScore = 0,
  });

  _IndexedFood copyWith({int? priorityScore}) {
    return _IndexedFood(
      raw: raw,
      name: name,
      category: category,
      brand: brand,
      aliases: aliases,
      tags: tags,
      searchFields: searchFields,
      priorityScore: priorityScore ?? this.priorityScore,
    );
  }
}
