import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_entry.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/repositories/diary_repository.dart';
import '../../domain/repositories/food_repository.dart';
import '../../domain/repositories/remote_food_repository.dart';
import '../../domain/usecases/food_calculator.dart';
import '../../domain/usecases/diary_service.dart';
import '../../data/repositories/local_diary_repository.dart';
import '../../data/repositories/local_food_repository.dart';
import '../../data/repositories/open_food_facts_repository.dart';
import '../../data/datasources/hive_diet_storage.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../weight/presentation/providers/weight_provider.dart';
import '../../../weight/domain/entities/weight_entry.dart';
import '../../../workout/providers/workout_provider.dart';
import '../../../../core/services/ai_service.dart';

/// Günlük makro hedefleri (gram).
class MacroTargets {
  final double protein;
  final double carb;
  final double fat;
  const MacroTargets({
    required this.protein,
    required this.carb,
    required this.fat,
  });
}

enum SuggestionMode { balanced, highProtein, lowCarb }

class DietProvider with ChangeNotifier {
  final DiaryRepository _diaryRepo = LocalDiaryRepository();
  final FoodRepository _foodRepo = LocalFoodRepository();
  final RemoteFoodRepository _remoteRepo = OpenFoodFactsRepository();
  final DiaryService _diaryService = DiaryService(LocalDiaryRepository());
  final _hive = HiveDietStorage();
  final _uuid = const Uuid();

  // Dependency
  WeightProvider? _weightProvider;
  WorkoutProvider? _workoutProvider;
  AIService? _aiService;

  UserProfile? _profile;
  double? _dailyTargetKcal;
  DateTime _selectedDate = DateTime.now();
  List<FoodEntry> _entries = [];
  DiaryTotals _totals = const DiaryTotals();
  List<String> _frequentFoodIds = []; // En sık yenen yemek ID'leri
  bool _loading = false;
  String? _error;
  bool _useRemoteSearch = false;
  SuggestionMode _suggestionMode = SuggestionMode.balanced;

  static double getCategoryDefaultGrams(String? category) {
    if (category == null) return 100.0;
    final c = category.toLowerCase();
    if (c.contains('çorba')) return 250.0;
    if (c.contains('pilav') || c.contains('makarna')) return 200.0;
    if (c.contains('et') || c.contains('tavuk') || c.contains('balık')) return 150.0;
    if (c.contains('fırın') || c.contains('unlu')) return 80.0;
    if (c.contains('atıştırmalık')) return 40.0;
    return 100.0;
  }

  UserProfile? get profile => _profile;
  double? get dailyTargetKcal => _dailyTargetKcal;
  DateTime get selectedDate => _selectedDate;
  List<FoodEntry> get entries => _entries;
  DiaryTotals get totals => _totals;
  bool get loading => _loading;
  String? get error => _error;
  bool get useRemoteSearch => _useRemoteSearch;
  FoodRepository get foodRepository => _foodRepo;
  SuggestionMode get suggestionMode => _suggestionMode;

  /// Antrenmanlardan yakılan bugünkü toplam kalori.
  double get todayBurnedKcal {
    if (_workoutProvider == null) return 0;
    
    // Sadece seçili güne (selectedDate) ait antrenmanları topla
    final todayWorkouts = _workoutProvider!.workouts.where((w) {
      final wDate = w.workoutDate;
      return wDate.year == _selectedDate.year &&
             wDate.month == _selectedDate.month &&
             wDate.day == _selectedDate.day;
    });

    return todayWorkouts.fold<double>(0, (sum, w) => sum + (w.caloriesBurned?.toDouble() ?? 0.0));
  }

  /// Bazal hedef + Antrenman bonusu = Toplam yakılabilir kalori
  double get effectiveTargetKcal => (_dailyTargetKcal ?? 2000) + todayBurnedKcal;

  void setSuggestionMode(SuggestionMode mode) {
    if (_suggestionMode == mode) return;
    _suggestionMode = mode;
    notifyListeners();
  }

  /// Son eklenen kaydı geri alır (siler).
  Future<void> undoLastEntry() async {
    if (_entries.isEmpty) return;
    // En son eklenen (createdAt'e göre) kaydı bul
    final last = [..._entries]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await deleteEntry(last.first.id);
  }


  void setWorkoutProvider(WorkoutProvider provider) {
    _workoutProvider = provider;
    _recalculateTarget();
    notifyListeners();
  }

  void setWeightProvider(WeightProvider provider) {
    // Reaktivite için her ProxyProvider tetiklendiğinde güncelliği sağla
    _weightProvider = provider;
    _recalculateTarget();
    
    // Sync ve yükleme işlemleri
    if (_profile != null) {
      if (!_didSyncInitialWeight) {
        Future.microtask(() => _syncInitialWeight());
      }
      // Kilo değişmiş olabilir, re-init gerekebilir veya sadece notify
      onWeightUpdated();
    }
  }

  void setAIService(AIService service) {
    if (service == _aiService) return;
    _aiService = service;
  }

  AIService? get aiService => _aiService;

  void setUseRemoteSearch(bool value) {
    if (_useRemoteSearch == value) return;
    _useRemoteSearch = value;
    notifyListeners();
  }

  double get remainingKcal {
    // Bazal + Bonus - Tüketilen
    return (effectiveTargetKcal - _totals.totalKcal).clamp(0, double.infinity);
  }

  /// Profil kiloya göre makro hedefleri (g): protein 1.6g/kg, kalan kalori %50 karb / %50 yağ.
  MacroTargets get macroTargets {
    final w = _weightProvider?.latestEntry?.weightKg ?? _profile?.weight ?? 70.0;
    final kcal = _dailyTargetKcal ?? 2000.0;
    final proteinG = (w * 1.6).roundToDouble();
    final proteinKcal = proteinG * 4;
    final remaining = (kcal - proteinKcal).clamp(0.0, double.infinity);
    final carbKcal = remaining * 0.5;
    final fatKcal = remaining * 0.5;
    return MacroTargets(
      protein: proteinG,
      carb: (carbKcal / 4).roundToDouble(),
      fat: (fatKcal / 9).roundToDouble(),
    );
  }

  /// Hesap değişince çağrılır (login/register). Önceki kullanıcının bellekte kalan verisini temizleyip
  /// yeni kullanıcının Hive/SharedPreferences verisini yükler; böylece her hesabın kendi profili olur.
  Future<void> init() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    // Önceki hesabın verisini hemen temizle; yeni hesap verisi yüklenene kadar eski profil görünmesin
    _profile = null;
    _entries = [];
    _dailyTargetKcal = null;
    _totals = const DiaryTotals();
    _selectedDate = DateTime.now();
    notifyListeners();
    try {
      await _loadFrequentFoods(); // Favorileri yükle (StorageHelper artık kullanıcıya göre)
      await _initInternal().timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw TimeoutException('DietProvider.init'),
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('DietProvider.init hatası: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _initInternal() async {
    _profile = await _diaryRepo.getProfile();
    debugPrint('DietProvider: active suffix ${StorageHelper.getUserStorageSuffix()}, profile name=${_profile?.name ?? "null"}');
    _recalculateTarget();
    final dateToLoad = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    if (_weightProvider != null) {
      await Future.wait([
        _syncInitialWeight(),
        _loadDayInternal(dateToLoad),
      ]);
    } else {
      await _loadDayInternal(dateToLoad);
    }
  }

  Future<void> _loadDayInternal(DateTime date) async {
    _selectedDate = date;
    _entries = await _diaryService.getEntriesByDate(date);
    _totals = await _diaryService.getTotalsByDate(date);
  }

  void _recalculateTarget() {
    if (_profile == null) {
      _dailyTargetKcal = null;
      return;
    }

    // WeightProvider'dan güncel kiloyu al, yoksa profildeki kiloyu kullan
    // Not: UserProfile artık weight alanını 'double' olarak tutuyor (kg)
    final currentWeight =
        _weightProvider?.latestEntry?.weightKg ?? _profile!.weight;

    // Hedef kalori hesabı için profili kopyalamak yerine
    // sadece hesaplama metoduna parametre geçebiliriz ama
    // CalorieCalculator muhtemelen UserProfile bekliyor.
    // O yüzden güncel kilo ile yeni bir UserProfile (kopya) oluşturuyoruz.
    
    final profileForCalc = UserProfile(
      name: _profile!.name,
      age: _profile!.age,
      weight: currentWeight,
      height: _profile!.height,
      gender: _profile!.gender,
      activityLevel: _profile!.activityLevel,
      goal: _profile!.goal,
      customKcalTarget: _profile!.customKcalTarget,
    );

    // UserProfile içinde zaten targetCalories getter'ı var.
    // Ayrıca CalorieCalculator sınıfına gerek kalmayabilir.
    // Ancak mevcut yapı bozulmasın diye şimdilik profilin kendi metodunu kullanıyorum.
    _dailyTargetKcal = profileForCalc.targetCalories;
  }

  Future<void> loadDay(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    try {
      _selectedDate = normalized;
      _error = null;
      _entries = await _diaryService.getEntriesByDate(_selectedDate);
      _totals = await _diaryService.getTotalsByDate(_selectedDate);
      notifyListeners();
    } catch (e) {
      debugPrint('DietProvider.loadDay hatası: $e');
      _error = e.toString();
      _entries = [];
      _totals = const DiaryTotals();
      notifyListeners();
    }
  }

  Future<void> saveUserProfile(UserProfile p) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Kilo değiştiyse Tracking tarafına da ekle (Senkronizasyon)
      if (_weightProvider != null &&
          _profile != null &&
          (p.weight - _profile!.weight).abs() > 0.1) {
        final entry = WeightEntry(
          id: _uuid.v4(),
          date: DateTime.now(),
          weightKg: p.weight,
        );
        // Arka planda ekle, await etmeye gerek yok (UI bloklanmasın)
        _weightProvider!.addEntry(entry);
      }

      await _diaryRepo.saveProfile(p);
      _profile = p;
      _recalculateTarget();
      await loadDay(_selectedDate);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Takip sayfasından kilo eklendiğinde profili senkronize et.
  /// Sadece profildeki kiloyu günceller; WeightProvider'a tekrar eklemez.
  Future<void> updateProfileWeightFromTracking(double weightKg) async {
    if (_profile == null) return;
    final updated = UserProfile(
      name: _profile!.name,
      age: _profile!.age,
      weight: weightKg,
      height: _profile!.height,
      gender: _profile!.gender,
      activityLevel: _profile!.activityLevel,
      goal: _profile!.goal,
      customKcalTarget: _profile!.customKcalTarget,
      targetWeight: _profile!.targetWeight,
    );
    await _diaryRepo.saveProfile(updated);
    _profile = updated;
    _recalculateTarget();
    notifyListeners();
  }

  Future<List<FoodItem>> searchFoods(String query, {String? category}) async {
    try {
      final local = await _foodRepo.searchFoods(query, category: category);
      if (!_useRemoteSearch) return local;
      try {
        final remote = await _remoteRepo.searchRemoteFoods(query);
        final localIds = local.map((e) => e.id).toSet();
        final extra = remote.where((r) => !localIds.contains(r.id)).toList();
        return [...local, ...extra];
      } catch (e) {
        debugPrint('DietProvider.searchFoods remote hatası: $e');
        return local; // Remote hata olsa bile local sonuçları döndür
      }
    } catch (e) {
      debugPrint('DietProvider.searchFoods hatası: $e');
      return [];
    }
  }

  /// Doğal dildeki sorguyu Gemini ile parçalar ve yerel veritabanında arar.
  Future<List<FoodItem>> aiSearch(String query) async {
    if (_aiService == null || !_aiService!.isReady) {
      return searchFoods(query);
    }

    try {
      final items = await _aiService!.extractFoodItems(query);
      if (items.isEmpty) return searchFoods(query);

      final List<FoodItem> results = [];
      for (final name in items) {
        final localResults = await _foodRepo.searchFoods(name);
        if (localResults.isNotEmpty) {
          results.add(localResults.first);
        }
      }
      return results;
    } catch (e) {
      debugPrint('DietProvider.aiSearch error: $e');
      return searchFoods(query);
    }
  }

  /// Mevcut beslenme durumunu kısa bir metin olarak döner (Gemini için context)
  String getDietContext() {
    final kcal = totals.totalKcal.round();
    final target = dailyTargetKcal?.round() ?? 0;
    final remaining = remainingKcal.round();
    final p = totals.totalProtein.round();
    final c = totals.totalCarb.round();
    final f = totals.totalFat.round();
    
    return 'Bugün $kcal kcal alındı. Hedef: $target kcal. Kalan: $remaining kcal. Makrolar: $p/P, $c/C, $f/F.';
  }

  /// Önerilen yemekler için AI ile açıklama üretir.
  Future<String> getAISuggestionReasoning(List<FoodItem> items) async {
    if (_aiService == null || !_aiService!.isReady || items.isEmpty) return '';
    try {
      final names = items.take(3).map((e) => e.name).join(', ');
      return await _aiService!.getSuggestionReasoning(names, getDietContext());
    } catch (e) {
      debugPrint('DietProvider.getAISuggestionReasoning error: $e');
      return '';
    }
  }

  Future<List<FoodItem>> loadRecentFoods() async {
    try {
      final ids = await _diaryRepo.getRecentFoodIds(10);
      if (ids.isEmpty) return [];
      
      final items = <FoodItem>[];
      for (final id in ids) {
        final item = await _foodRepo.getFoodById(id);
        if (item != null) {
          items.add(item);
        } else if (_useRemoteSearch) {
          // Localde yoksa ve remote açıksa belki remote cache'de vardır
          // Şu anlık sadece local bakıyoruz, ama ileride remote cache'den de bakılabilir
        }
      }
      return items;
    } catch (e) {
      debugPrint('DietProvider.loadRecentFoods hatası: $e');
      return [];
    }
  }

  Future<List<FoodItem>> loadFrequentFoods() async {
    try {
      final ids = await _diaryRepo.getFrequentFoodIds(10);
      if (ids.isEmpty) return [];
      
      final items = <FoodItem>[];
      for (final id in ids) {
        final item = await _foodRepo.getFoodById(id);
        if (item != null) items.add(item);
      }
      return items;
    } catch (e) {
      debugPrint('DietProvider.loadFrequentFoods hatası: $e');
      return [];
    }
  }

  Future<void> addCustomFood(FoodItem food) async {
    try {
      await _hive.addCustomFood(food);
      (_foodRepo as LocalFoodRepository).invalidateCache();
      notifyListeners();
    } catch (e) {
      debugPrint('DietProvider.addCustomFood hatası: $e');
      rethrow;
    }
  }

  Future<FoodItem?> getFoodById(String id) async {
    try {
      return await _foodRepo.getFoodById(id);
    } catch (e) {
      debugPrint('DietProvider.getFoodById hatası: $e');
      return null;
    }
  }

  double calculateCaloriesForFood(FoodItem food, double grams) {
    return FoodCalculator.calculateCalories(food, grams);
  }

  /// Porsiyon için makro hesapla (gram/100 * per100g).
  void macrosForPortion(
    FoodItem food,
    double grams, {
    required Function(double p, double c, double f) set,
  }) {
    final ratio = grams / 100;
    set(
      food.proteinPer100g * ratio,
      food.carbPer100g * ratio,
      food.fatPer100g * ratio,
    );
  }

  Future<void> addEntry({
    required FoodItem food,
    required double grams,
    required MealType mealType,
    required DateTime date,
  }) async {
    if (grams <= 0 || grams.isNaN || grams.isInfinite) {
      debugPrint('DietProvider.addEntry: Geçersiz gram değeri: $grams');
      return;
    }
    try {
      final kcal = FoodCalculator.calculateCalories(food, grams);
      final ratio = grams / 100;
      final entry = FoodEntry(
        id: _uuid.v4(),
        date: DiaryService.normalizeDate(date),
        mealType: mealType,
        foodId: food.id,
        foodName: food.name,
        grams: grams,
        calculatedKcal: kcal.isNaN || kcal.isInfinite ? 0 : kcal,
        protein: (food.proteinPer100g * ratio).isNaN ? 0 : food.proteinPer100g * ratio,
        carb: (food.carbPer100g * ratio).isNaN ? 0 : food.carbPer100g * ratio,
        fat: (food.fatPer100g * ratio).isNaN ? 0 : food.fatPer100g * ratio,
        createdAt: DateTime.now(),
      );
      await _diaryRepo.addEntry(entry);
      await loadDay(_selectedDate);
    } catch (e) {
      debugPrint('DietProvider.addEntry hatası: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteEntry(String entryId) async {
    try {
      await _diaryRepo.deleteEntry(entryId);
      await loadDay(_selectedDate);
    } catch (e) {
      debugPrint('DietProvider.deleteEntry hatası: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  List<FoodEntry> entriesForMeal(MealType type) {
    return _entries.where((e) => e.mealType == type).toList();
  }

  /// Sık yenen yemekleri yükler
  Future<void> _loadFrequentFoods() async {
    try {
      _frequentFoodIds = await _diaryRepo.getFrequentFoodIds(15);
    } catch (e) {
      debugPrint('DietProvider._loadFrequentFoods hatası: $e');
    }
  }

  /// Bir besinin belirli bir miktarının (gram) günlük hedeflere etkisini hesaplar (%)
  Map<String, double> calculateMacroImpact(FoodItem item, double amountG) {
    if (effectiveTargetKcal <= 0) return {'kcal': 0, 'protein': 0, 'carb': 0, 'fat': 0};
    
    final factor = amountG / 100.0;
    final targets = macroTargets;
    
    return {
      'kcal': (item.kcalPer100g * factor) / effectiveTargetKcal,
      'protein': targets.protein > 0 ? (item.proteinPer100g * factor) / targets.protein : 0,
      'carb': targets.carb > 0 ? (item.carbPer100g * factor) / targets.carb : 0,
      'fat': targets.fat > 0 ? (item.fatPer100g * factor) / targets.fat : 0,
    };
  }

  /// Türkçe karakterleri ASCII'ye çevirir (eşleşme için).
  static String _norm(String s) {
    return s.toLowerCase()
        .replaceAll('ı', 'i').replaceAll('İ', 'i').replaceAll('i', 'i')
        .replaceAll('ğ', 'g').replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u').replaceAll('Ü', 'u')
        .replaceAll('ö', 'o').replaceAll('Ö', 'o')
        .replaceAll('ç', 'c').replaceAll('Ç', 'c')
        .replaceAll('ş', 's').replaceAll('Ş', 's');
  }

  /// Öğüne uygun anahtar kelimeler (kategori / tag / isim eşleşmesi için).
  static List<String> _mealKeywords(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return ['kahvalti', 'kahvaltilik', 'yumurta', 'peynir', 'sut', 'yogurt', 'ekmek', 'recel', 'bal', 'misir', 'gevregi', 'zeytin', 'domates', 'salatalik', 'borek', 'pogaca', 'simit', 'cay', 'tahil', 'sut urun'];
      case MealType.lunch:
        return ['ogle', 'corba', 'ana yemek', 'yemek', 'pilav', 'makarna', 'et', 'tavuk', 'balik', 'kofte', 'kebap', 'salata', 'sebze', 'bakliyat', 'mercimek', 'fasulye', 'borek', 'pide', 'lahmacun'];
      case MealType.dinner:
        return ['aksam', 'corba', 'yemek', 'et', 'tavuk', 'balik', 'salata', 'sebze', 'pilav', 'makarna', 'zeytinyagli', 'bakliyat', 'ana yemek'];
      case MealType.snack:
        return ['atistirma', 'atistirmalik', 'meyve', 'kuruyemis', 'biskivi', 'cikolata', 'kek', 'kurabiye', 'cips', 'kraker', 'smoothie', 'meyve suyu', 'findik', 'ceviz', 'badem', 'elma', 'muz', 'portakal'];
    }
  }

  /// Kalan kalori ve makrolara göre "Ne ekleyeyim?" önerisi.
  /// [query] verilirse sadece o kelimeyle eşleşen yemekler arasından önerilir (örn. "lavaş" → lavaşlı yemekler).
  Future<List<FoodItem>> getSuggestedFoods(MealType mealType, {int limit = 24, String? query}) async {
    final remKcal = remainingKcal;
    final mealKeywords = _mealKeywords(mealType);
    final searchQuery = query?.trim();
    final useQuery = searchQuery != null && searchQuery.isNotEmpty;

    try {
      final pool = useQuery
          ? await _foodRepo.searchFoods(searchQuery!, category: null)
          : await _foodRepo.searchFoods('', category: null);
      final eatenIds = _entries.map((e) => e.foodId).toSet();
      final List<_ScoredSuggestion> scored = [];

      for (final item in pool) {
        double score = 0;

        // 1. Kalori uyumu
        final itemKcal = item.kcalPer100g;
        final kcalDiff = (remKcal - itemKcal).abs();
        score += (500 - kcalDiff).clamp(0, 500) / 10;

        // 2. Makro uyumu (moda göre)
        double weightP = 1.0, weightC = 1.0, weightF = 1.0;
        switch (_suggestionMode) {
          case SuggestionMode.highProtein: weightP = 2.5; weightC = 0.5; break;
          case SuggestionMode.lowCarb: weightC = 0.1; weightP = 1.5; weightF = 1.2; break;
          case SuggestionMode.balanced: break;
        }
        score += (item.proteinPer100g * weightP * 2);
        score += (item.carbPer100g * weightC);
        score += (item.fatPer100g * weightF);

        // 3. Yenilen ürün cezası
        if (eatenIds.contains(item.id)) score -= 20;

        // 4. Favori Yemek Bonusu (+40 puan)
        if (_frequentFoodIds.contains(item.id)) {
          score += 40;
        }

        // 5. Öğüne göre uyum (kahvaltıda kahvaltılık, öğlede çorba/yemek vb. öne çıksın)
        final catNorm = _norm(item.category);
        final tagsNorm = _norm(item.tags.join(' '));
        final nameNorm = _norm(item.name);
        for (final kw in mealKeywords) {
          if (catNorm.contains(kw) || tagsNorm.contains(kw) || nameNorm.contains(kw)) {
            score += 55;
            break;
          }
        }
        if (_norm(mealType.label).isNotEmpty && (tagsNorm.contains(_norm(mealType.label)))) score += 20;

        // 5. Kullanıcı araması: isim/tag/category arama kelimesiyle eşleşiyorsa ek puan
        if (useQuery) {
          final qNorm = _norm(searchQuery!);
          if (nameNorm.contains(qNorm) || tagsNorm.contains(qNorm) || catNorm.contains(qNorm)) {
            score += 80;
          }
        }

        if (score > 0) scored.add(_ScoredSuggestion(item, score));
      }

      scored.sort((a, b) => b.score.compareTo(a.score));

      final List<FoodItem> finalResults = [];
      final Map<String, int> tagCounter = {};

      for (final s in scored) {
        if (finalResults.length >= limit) break;
        bool skip = false;
        for (final tag in s.item.tags) {
          if ((tagCounter[tag] ?? 0) >= 3) {
            skip = true;
            break;
          }
        }
        if (!skip) {
          finalResults.add(s.item);
          for (final tag in s.item.tags) {
            tagCounter[tag] = (tagCounter[tag] ?? 0) + 1;
          }
        }
      }

      return finalResults;
    } catch (e) {
      debugPrint('DietProvider.getSuggestedFoods: $e');
      return [];
    }
  }

  // WeightProvider'dan bildirim gelince çağrılır
  void onWeightUpdated() {
    // 1. Hedef kaloriyi güncelle
    _recalculateTarget();

    // 2. Profildeki kiloyu da güncelle (UI ve tutarlılık için)
    if (_weightProvider?.latestEntry != null && _profile != null) {
      final newWeight = _weightProvider!.latestEntry!.weightKg;
      // Sadece fark varsa güncelle ve kaydet
      if ((newWeight - _profile!.weight).abs() > 0.1) {
        final updatedProfile = UserProfile(
          name: _profile!.name,
          age: _profile!.age,
          weight: newWeight, // Güncel kilo
          height: _profile!.height,
          gender: _profile!.gender,
          activityLevel: _profile!.activityLevel,
          goal: _profile!.goal,
          customKcalTarget: _profile!.customKcalTarget,
        );
        
        // Döngüye girmemesi için direkt repoya kaydedip local değişkeni güncelliyoruz
        // saveUserProfile çağırmıyoruz çünkü o da tracking'e ekleme yapmaya çalışır.
        _diaryRepo.saveProfile(updatedProfile).then((_) {
          _profile = updatedProfile;
          notifyListeners();
        });
      }
    }
    notifyListeners();
  }

  /// Uygulama oturumunda sadece bir kez çalışsın (geçmiş kayıtların sürekli artmasını önler)
  bool _didSyncInitialWeight = false;

  // Başlangıçta Profildeki kiloyu Tracking'e aktar (Eğer tracking boşsa)
  Future<void> _syncInitialWeight() async {
    if (_didSyncInitialWeight) return;
    if (_weightProvider == null || _profile == null) return;
    if (_weightProvider!.entries.isNotEmpty) return;
    // Bugün için aynı kilo zaten varsa ekleme (yinelenen kayıt önlemi)
    final now = DateTime.now();
    final todaySameWeight = _weightProvider!.entries.any((e) {
      return e.date.year == now.year && e.date.month == now.month && e.date.day == now.day &&
          (e.weightKg - _profile!.weight).abs() < 0.01;
    });
    if (todaySameWeight) {
      _didSyncInitialWeight = true;
      return;
    }

    _didSyncInitialWeight = true;
    final entry = WeightEntry(
      id: _uuid.v4(),
      date: DateTime.now(),
      weightKg: _profile!.weight,
    );
    debugPrint('DietProvider: Profil kilosu (${_profile!.weight}) Tracking geçmişine tek seferlik ekleniyor.');
    await _weightProvider!.addEntry(entry);
  }

  void reset() {
    _profile = null;
    _dailyTargetKcal = null;
    _entries = [];
    _totals = const DiaryTotals();
    _error = null;
    _loading = false;
    notifyListeners();
  }
}

class _ScoredSuggestion {
  final FoodItem item;
  final double score;
  _ScoredSuggestion(this.item, this.score);
}
