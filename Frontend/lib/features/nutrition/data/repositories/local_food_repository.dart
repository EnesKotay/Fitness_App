import '../../domain/entities/food_item.dart';
import '../../domain/repositories/food_repository.dart';
import '../datasources/asset_food_loader.dart';
import '../datasources/hive_diet_storage.dart';
import '../datasources/open_food_facts_client.dart';

/// Local yiyecek listesi: JSON asset + kullanıcının eklediği özel yemekler (Hive).
/// Arama: name, aliases, tags, category tarar; Türkçe normalizasyon + basit fuzzy.
class LocalFoodRepository implements FoodRepository {
  List<FoodItem>? _assetCache;
  List<FoodItem>? _customCache;
  Map<String, List<String>>? _synonyms;
  final Map<String, _IndexedFood> _indexCache = {};
  List<FoodItem>? _visiblePoolCache;
  final Map<String, List<FoodItem>> _emptyQueryCache = {};
  final Map<String, List<FoodItem>> _searchCache = {};
  final HiveDietStorage _hive = HiveDietStorage();

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
    _synonyms ??= await AssetFoodLoader.loadSynonyms();
  }

  /// Türkçe karakterleri normalize eder, özel karakterleri temizler
  static String normalize(String input) {
    return input
        .toLowerCase()
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

  void invalidateCache() {
    _customCache = null;
    _indexCache.clear();
    _visiblePoolCache = null;
    _emptyQueryCache.clear();
    _searchCache.clear();
  }

  List<FoodItem> _userFacingPool() {
    return _visiblePoolCache ??= [
      ..._customCache!,
      ..._assetCache!,
    ].where(_isUserFacingFood).toList(growable: false);
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
    };

    final padded = ' $name ';
    for (final phrase in bannedPhrases) {
      if (padded.contains(phrase)) return true;
    }

    if (name.contains(' and ') || name.contains(' with ')) return true;
    return false;
  }

  static const Set<String> _foreignNoiseTokens = {
    'abalon',
    'adobo',
    'ambrosia',
    'antipasto',
    'arepa',
    'armadillo',
    'bagel',
    'barfi',
    'burfi',
    'biscuit',
    'blackeyed',
    'chowder',
    'coleslaw',
    'cornbread',
    'croissant',
    'english muffin',
    'griddle',
    'horseradish',
    'jute',
    'mousse',
    'tapenade',
    'timbale',
    'zwieback',
  };

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
    final haystack = normalize([
      food.name,
      food.category,
      ...food.aliases,
      ...food.tags,
    ].join(' '));
    for (final token in _foreignNoiseTokens) {
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
    if (food.id.startsWith('tr_') || food.id.startsWith('trverified_')) {
      return true;
    }
    if (food.tags.any((tag) => normalize(tag) == 'trcore')) {
      return true;
    }
    final surveyLooksOverdescribed =
        food.id.startsWith('survey_') &&
        (food.name.contains(' veya ') ||
            food.name.contains(' ile ') ||
            ((food.name.length > 48 || ','.allMatches(food.name).length >= 2) &&
                (food.name.contains(' ve/') || food.name.contains(' , '))));
    if (surveyLooksOverdescribed) {
      return false;
    }
    if (food.id.startsWith('survey_')) {
      if (_containsForeignNoise(food)) return false;
      if (!_hasRelevantTurkishSignal(food) && !_isSimpleEverydayFood(food)) {
        return false;
      }
    }
    if (!_looksMachineTranslated(food.name)) {
      return true;
    }

    final aliasLooksClean = food.aliases.any(
      (alias) => !_looksMachineTranslated(alias) && normalize(alias).length >= 4,
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

    final searchTerms = {normalizedQuery};
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
      final matchedTokenCount = queryTokens.where(
        (token) => searchableFields.any((field) => _containsToken(field, token)),
      ).length;
      final exactPhraseMatch = searchableFields.any(
        (field) => field == normalizedQuery || field.contains(normalizedQuery),
      );
      final strongNameMatch =
          nName == normalizedQuery ||
          nName.startsWith(normalizedQuery) ||
          _wordStartsWith(nName, normalizedQuery);

      if (queryTokens.length >= 2 &&
          !exactPhraseMatch &&
          matchedTokenCount < queryTokens.length) {
        continue;
      }

      // 1) İsim: tam > başlangıç > kelime başı > içerik
      if (nName == normalizedQuery) {
        score += 100;
      } else if (nName.startsWith(normalizedQuery)) {
        score += 60;
      } else if (_wordStartsWith(nName, normalizedQuery)) {
        score += 50;
      } else if (nName.contains(normalizedQuery)) {
        score += 20;
      }

      // 2) Token bazlı (çok kelimeli sorgu): her token isimde geçiyorsa
      for (final token in queryTokens) {
        if (nName.contains(token)) score += 5;
        if (_wordStartsWith(nName, token)) score += 8;
      }

      // 3) Aliases: tam > başlangıç > içerik (sadece en yüksek puanı al)
      int maxAliasScore = 0;
      for (final nAlias in indexed.aliases) {
        int currentAliasScore = 0;
        if (nAlias == normalizedQuery) {
          currentAliasScore = 40;
        } else if (nAlias.startsWith(normalizedQuery)) {
          currentAliasScore = 35;
        } else if (nAlias.contains(normalizedQuery)) {
          currentAliasScore = 15;
        } else if (_wordStartsWith(nAlias, normalizedQuery)) {
          currentAliasScore = 25;
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
        score += indexed.priorityScore;
        scoredItems.add(_ScoredFood(food, score));
      }
    }

    scoredItems.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
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

      final localMatch = _assetCache?.where((f) => f.barcode == barcode).firstOrNull;
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
  final int score;
  _ScoredFood(this.item, this.score);
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
