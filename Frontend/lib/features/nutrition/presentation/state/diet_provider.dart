import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/ai_safety_helper.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/food_entry.dart';
import '../../domain/entities/grocery_item.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/nutrition_preferences.dart';
import '../../domain/repositories/diary_repository.dart';
import '../../domain/repositories/food_repository.dart';
import '../../domain/repositories/remote_food_repository.dart';
import '../../domain/usecases/food_calculator.dart';
import '../../domain/usecases/diary_service.dart';
import '../../data/datasources/weekly_meal_plan_storage.dart';
import '../../data/repositories/local_diary_repository.dart';
import '../../data/repositories/local_food_repository.dart';
import '../../data/repositories/open_food_facts_repository.dart';
import '../../data/datasources/hive_diet_storage.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/api/api_client.dart';
import '../../../weight/presentation/providers/weight_provider.dart';
import '../../../workout/providers/workout_provider.dart';
import '../../../../core/services/ai_service.dart';
import '../../models/nutrition_ai_response.dart';
import '../../../../core/models/workout.dart';
import '../../../../core/services/pdf_report_service.dart';
import '../../../../core/models/daily_diet_log.dart';

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

class SuggestedFoodInsight {
  final FoodItem item;
  final double score;
  final List<String> reasons;
  final double suggestedPortionG;
  final bool isFavoriteLike;

  const SuggestedFoodInsight({
    required this.item,
    required this.score,
    required this.reasons,
    required this.suggestedPortionG,
    required this.isFavoriteLike,
  });
}

class DietProvider with ChangeNotifier {
  late final DiaryRepository _diaryRepo;
  final FoodRepository _foodRepo = LocalFoodRepository();
  final RemoteFoodRepository _remoteRepo = OpenFoodFactsRepository();
  late final DiaryService _diaryService;

  DietProvider() {
    _diaryRepo = LocalDiaryRepository();
    _diaryService = DiaryService(_diaryRepo);
  }
  final _hive = HiveDietStorage();
  final _uuid = const Uuid();
  final _weeklyMealPlanStorage = WeeklyMealPlanStorage();

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
  bool _useRemoteSearch = true;
  SuggestionMode _suggestionMode = SuggestionMode.balanced;
  int _currentStreak = 0;
  String? _activeUserSuffix;
  double _waterLiters = 0.0; // V5: Water tracking
  NutritionPreferences _nutritionPreferences = const NutritionPreferences();

  double get waterLiters => _waterLiters;

  void addWater(double amount) {
    setWaterMlForSelectedDate(((_waterLiters + amount) * 1000).round());
  }

  void setWaterMlForSelectedDate(int ml) {
    final safeMl = ml.clamp(0, 6000);
    _waterLiters = safeMl / 1000.0;
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    StorageHelper.saveWaterForDate(dateKey, safeMl);
    notifyListeners();
  }

  void setWaterGlassesForSelectedDate(int glasses) {
    setWaterMlForSelectedDate(glasses.clamp(0, 24) * 250);
  }

  static double getCategoryDefaultGrams(String? category) {
    if (category == null) return 100.0;
    final c = category.toLowerCase();
    if (c.contains('çorba')) return 250.0;
    if (c.contains('pilav') || c.contains('makarna')) {
      return 150.0; // Reduced to 150
    }
    if (c.contains('et') || c.contains('tavuk') || c.contains('balık')) {
      return 150.0;
    }
    if (c.contains('fırın') || c.contains('unlu') || c.contains('hamur')) {
      return 80.0;
    }
    if (c.contains('atıştırmalık') || c.contains('tatlı')) return 50.0;
    if (c.contains('fast food') || c.contains('burger')) return 150.0;
    return 100.0;
  }

  static String getSmartUnit(String name, String category) {
    if (name.isEmpty) return 'Porsiyon';
    final lower = name.toLowerCase();
    final cat = category.toLowerCase();

    // Tane / Adet
    if (lower.contains('burger') ||
        lower.contains('hamburger') ||
        lower.contains('yumurta') ||
        lower.contains('elma') ||
        lower.contains('muz') ||
        lower.contains('sandviç') ||
        lower.contains('tost') ||
        lower.contains('kurabiye') ||
        lower.contains('lahmacun') ||
        lower.contains('dürüm') ||
        lower.contains('pizza') ||
        lower.contains('poğaça') ||
        lower.contains('simit') ||
        lower.contains('pide') ||
        lower.contains('köfte') ||
        lower.contains('içli köfte') ||
        lower.contains('sarma') ||
        lower.contains('dolma') ||
        cat.contains('fast food')) {
      return 'Tane';
    }

    // Dilim
    if (lower.contains('ekmek') ||
        lower.contains('pasta') ||
        lower.contains('kek') ||
        lower.contains('börek')) {
      return 'Dilim';
    }

    // Kase
    if (lower.contains('çorba') ||
        cat.contains('çorba') ||
        lower.contains('bowl') ||
        lower.contains('kase') ||
        lower.contains('salata') ||
        lower.contains('yoğurt') ||
        lower.contains('yulaf')) {
      return 'Kase';
    }

    // Bardak / Fincan
    if (lower.contains('kahve') ||
        lower.contains('çay') ||
        lower.contains('fincan')) {
      return 'Fincan';
    }
    if (lower.contains('su') ||
        lower.contains('kola') ||
        lower.contains('ayran') ||
        lower.contains('süt') ||
        cat.contains('içecek') ||
        cat.contains('icecek')) {
      return 'Bardak';
    }

    // Tabak
    if (cat.contains('ana yemek') ||
        cat.contains('yemek') ||
        lower.contains('pilav') ||
        lower.contains('makarna') ||
        lower.contains('sebze') ||
        lower.contains('sote') ||
        lower.contains('kavurma') ||
        lower.contains('fasulye') ||
        lower.contains('nohut')) {
      return 'Tabak';
    }

    return 'Porsiyon';
  }

  static double getDefaultPortionForFood(FoodItem food) {
    if (food.servings.isNotEmpty) {
      final defaults = food.servings.where((item) => item.isDefault);
      if (defaults.isNotEmpty) return defaults.first.grams;
      return food.servings.first.grams;
    }
    return getCategoryDefaultGrams(food.category);
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
  int get currentStreak => _currentStreak;
  NutritionPreferences get nutritionPreferences => _nutritionPreferences;

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

    return todayWorkouts.fold<double>(
      0,
      (sum, w) => sum + (w.caloriesBurned?.toDouble() ?? 0.0),
    );
  }

  /// Seçili güne ait antrenman listesi.
  List<Workout> get todayWorkouts {
    if (_workoutProvider == null) return [];
    return _workoutProvider!.workouts.where((w) {
      final wDate = w.workoutDate;
      return wDate.year == _selectedDate.year &&
          wDate.month == _selectedDate.month &&
          wDate.day == _selectedDate.day;
    }).toList();
  }

  /// Bazal hedef + Antrenman bonusu = Toplam yakılabilir kalori
  double get effectiveTargetKcal =>
      (_dailyTargetKcal ?? 2000) + todayBurnedKcal;

  void setSuggestionMode(SuggestionMode mode) {
    if (_suggestionMode == mode) return;
    _suggestionMode = mode;
    notifyListeners();
  }

  /// Son eklenen kaydı geri alır (siler).
  Future<void> undoLastEntry() async {
    if (_entries.isEmpty) return;
    // En son eklenen (createdAt'e göre) kaydı bul
    final last = [..._entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

    // Kilo güncellendiyse profili senkronla; burada otomatik başlangıç kaydı ekleme yapma.
    if (_profile != null) {
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
    // Bazal + Bonus - Tüketilen (negatif olabilir)
    return effectiveTargetKcal - _totals.totalKcal;
  }

  /// Profil hedefine göre makro hedefleri (g).
  /// Protein: 1.6-2.0g/kg, Yağ: Toplam kalorinin %25-30'u, Karb: Kalan kaloriler.
  MacroTargets get macroTargets {
    final w =
        _weightProvider?.latestEntry?.weightKg ?? _profile?.weight ?? 70.0;
    final kcal = _dailyTargetKcal ?? 2000.0;
    final goal = _profile?.goal ?? Goal.maintain;

    // 1. Protein — hedefe göre g/kg
    double proteinPerKg;
    double fatPercent;
    switch (goal) {
      case Goal.cut:
        proteinPerKg = 2.0; // Kas koruma için yüksek
        fatPercent = 0.25; // %25
        break;
      case Goal.bulk:
        proteinPerKg = 1.8; // Kas büyütme
        fatPercent = 0.25; // %25
        break;
      case Goal.strength:
        proteinPerKg = 1.8; // Güç performansı
        fatPercent = 0.30; // %30 (hormon desteği)
        break;
      case Goal.maintain:
        proteinPerKg = 1.6; // Koruma
        fatPercent = 0.30; // %30
        break;
    }

    final proteinG = (w * proteinPerKg).roundToDouble();
    final proteinKcal = proteinG * 4;

    // 2. Yağ — toplam kalorinin %'si
    final fatKcal = kcal * fatPercent;
    final fatG = (fatKcal / 9).roundToDouble();

    // 3. Karb — kalan kalori
    final carbKcal = (kcal - proteinKcal - fatKcal).clamp(0.0, double.infinity);
    final carbG = (carbKcal / 4).roundToDouble();

    return MacroTargets(protein: proteinG, carb: carbG, fat: fatG);
  }

  /// Calculates the simulated daily calorie and protein targets if the user were to switch to [simulatedGoal].
  ({double targetKcal, double proteinTarget}) getSimulatedTargets(
    Goal simulatedGoal,
  ) {
    if (_profile == null) return (targetKcal: 2000.0, proteinTarget: 140.0);

    final currentWeight =
        _weightProvider?.latestEntry?.weightKg ?? _profile!.weight;

    final fakeProfile = UserProfile(
      name: _profile!.name,
      age: _profile!.age,
      weight: currentWeight,
      height: _profile!.height,
      gender: _profile!.gender,
      activityLevel: _profile!.activityLevel,
      goal: simulatedGoal,
      customKcalTarget: _profile!.customKcalTarget,
    );

    final baseKcal = fakeProfile.targetCalories;
    final simulatedKcal = baseKcal + todayBurnedKcal;

    double proteinPerKg;
    switch (simulatedGoal) {
      case Goal.cut:
        proteinPerKg = 2.0;
        break;
      case Goal.bulk:
        proteinPerKg = 1.8;
        break;
      case Goal.strength:
        proteinPerKg = 1.8;
        break;
      case Goal.maintain:
        proteinPerKg = 1.6;
        break;
    }
    final proteinTarget = (currentWeight * proteinPerKg).roundToDouble();

    return (targetKcal: simulatedKcal, proteinTarget: proteinTarget);
  }

  /// Vücut Kitle Endeksi (BMI) hesaplaması.
  double get bmi {
    final w =
        _weightProvider?.latestEntry?.weightKg ?? _profile?.weight ?? 70.0;
    final h = (_profile?.height ?? 170.0) / 100.0;
    if (h == 0) return 0;
    return double.parse((w / (h * h)).toStringAsFixed(1));
  }

  /// BMI Kategorisi.
  String get bmiCategory {
    final val = bmi;
    if (val < 18.5) return 'Zayıf';
    if (val < 25) return 'Normal';
    if (val < 30) return 'Fazla Kilolu';
    return 'Kilolu / Obez';
  }

  /// BMI bazlı tavsiye metni.
  String get bmiAdvice {
    final val = bmi;
    if (val < 18.5) {
      return 'Sağlıklı kilo alımı için protein ağırlıklı beslenme ve direnç egzersizi önerilir.';
    }
    if (val < 25) {
      return 'İdeal kilonuzdasınız. Formunuzu korumak için dengeli beslenmeye devam edin.';
    }
    if (val < 30) {
      return 'Kardiyo egzersizlerini artırarak hafif kalori kısıtlaması uygulamanız faydalı olabilir.';
    }
    return 'Düşük tempolu egzersizler ve sıkı kalori takibi ile kilonuzu kontrol altına alabilirsiniz.';
  }

  /// Hesap değişince çağrılır (login/register). Önceki kullanıcının bellekte kalan verisini temizleyip
  /// yeni kullanıcının Hive/SharedPreferences verisini yükler; böylece her hesabın kendi profili olur.
  Future<void> init() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _ensureUserScope();
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
    _activeUserSuffix = StorageHelper.getUserStorageSuffix();
    _profile = await _diaryRepo.getProfile();
    _nutritionPreferences = NutritionPreferences.fromJson(
      StorageHelper.getNutritionPreferences(),
    );
    debugPrint(
      'DietProvider: active suffix ${StorageHelper.getUserStorageSuffix()}, profile name=${_profile?.name ?? "null"}',
    );
    _recalculateTarget();
    final dateToLoad = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    if (_weightProvider != null) {
      await _ensureWeightEntriesReady();
      await _loadDayInternal(dateToLoad);
    } else {
      await _loadDayInternal(dateToLoad);
    }
  }

  Future<void> _ensureWeightEntriesReady() async {
    final wp = _weightProvider;
    if (wp == null) return;

    // Kayıtlar henüz yüklenmediyse senkron kararından önce mutlaka yükle.
    if (wp.entries.isEmpty && !wp.isLoading) {
      await wp.loadEntries();
      return;
    }

    // Splash akışında loadEntries arka planda çalışıyor olabilir; bitmesini bekle (max 4s).
    if (wp.isLoading) {
      await Future.any([
        Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 50));
          return wp.isLoading;
        }),
        Future.delayed(const Duration(seconds: 4)),
      ]);
    }
  }

  Future<void> _loadDayInternal(DateTime date) async {
    _selectedDate = date;
    _entries = await _diaryService.getEntriesByDate(date);
    _totals = await _diaryService.getTotalsByDate(date);
    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final savedMl = StorageHelper.getWaterForDate(dateKey);
    _waterLiters = savedMl / 1000.0;
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
    final dateStr = DateFormat('yyyy-MM-dd').format(normalized);
    try {
      _selectedDate = normalized;
      _error = null;
      _entries = await _diaryService.getEntriesByDate(_selectedDate);
      _totals = await _diaryRepo.getTotalsByDate(dateStr);
      _currentStreak = await _diaryRepo.getCurrentStreak();
      _error = null;
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
      // Kilo değişimi backend tarafından profile güncellendiğinde otomatik olarak
      // Kilo Geçmişi'ne (WeightRecord) yansıtılmaktadır.
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

  Future<void> saveNutritionPreferences(
    NutritionPreferences preferences,
  ) async {
    _nutritionPreferences = preferences;
    await StorageHelper.saveNutritionPreferences(preferences.toJson());
    notifyListeners();
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

  Future<void> toggleDislikedFood(String foodId) async {
    await StorageHelper.toggleDislike(foodId);
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

    final safety = AiSafetyHelper.instance;

    // Rate limit kontrolü
    if (!(await safety.canMakeRequest())) {
      debugPrint('DietProvider.aiSearch: Günlük limit aşıldı');
      return searchFoods(query);
    }

    try {
      // Cache kontrolü
      final cached = safety.getCachedSearch(query);
      List<String> items;
      if (cached != null) {
        items = cached;
        debugPrint('DietProvider.aiSearch: Cache\'den geldi → $items');
      } else {
        items = await _aiService!.extractFoodItems(query);
        safety.recordRequest();
        if (items.isNotEmpty) {
          safety.cacheSearchResult(query, items);
        }
      }

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

  Map<String, dynamic> getNutritionAiContext({String? mealType}) {
    final context = <String, dynamic>{
      'summaryText': getDietContext(),
      'dailySummary': {
        'calories': totals.totalKcal.round(),
        'water': double.parse(_waterLiters.toStringAsFixed(1)),
      },
    };

    final profile = _profile;
    if (profile != null) {
      context['goal'] = _goalLabel(profile.goal);
      context['userAge'] = profile.age;
      context['userWeightKg'] = profile.weight;
      context['userHeightCm'] = profile.height;
      context['userGender'] = profile.gender.name;
      context['activityLevel'] = profile.activityLevel.name;
      context['targetCalories'] = profile.targetCalories.round();
      // Protein target: ~1.8g per kg for most fitness goals
      context['proteinTargetG'] = (profile.weight * 1.8).round();
    }
    if (mealType != null && mealType.trim().isNotEmpty) {
      context['mealType'] = mealType.trim();
    }

    final prefs = _nutritionPreferences;
    final activePrefs = <String>[];
    if (prefs.vegetarian) activePrefs.add('Vegetarian');
    if (prefs.vegan) activePrefs.add('Vegan');
    if (prefs.lactoseFree) activePrefs.add('Lactose-Free');
    if (prefs.glutenFree) activePrefs.add('Gluten-Free');
    if (prefs.excludePork) activePrefs.add('Pork-Free');

    if (activePrefs.isNotEmpty) {
      context['dietaryRestrictions'] = activePrefs;
    }

    final availableIngredients = _entries
        .map((entry) => entry.foodName.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .take(12)
        .toList();
    if (availableIngredients.isNotEmpty) {
      context['availableIngredients'] = availableIngredients;
    }

    context['workoutLocation'] = StorageHelper.getWorkoutLocation();
    context['equipmentType'] = StorageHelper.getEquipmentType();

    return context;
  }

  DateTime currentWeekStart([DateTime? reference]) {
    final date = reference ?? DateTime.now();
    final weekStart = date.subtract(Duration(days: date.weekday - 1));
    return DateTime(weekStart.year, weekStart.month, weekStart.day);
  }

  Future<WeeklyMealPlan> loadWeeklyMealPlan({DateTime? weekStart}) {
    return _weeklyMealPlanStorage.load(currentWeekStart(weekStart));
  }

  Future<void> saveWeeklyMealPlan(
    WeeklyMealPlan plan, {
    DateTime? weekStart,
  }) async {
    await _weeklyMealPlanStorage.save(currentWeekStart(weekStart), plan);
  }

  Future<List<GroceryItem>> generateSmartGroceryItems({
    DateTime? weekStart,
    bool includePersonalSuggestions = true,
  }) async {
    final plan = await loadWeeklyMealPlan(weekStart: weekStart);
    final groceries = <String, GroceryItem>{};

    void mergeItem(GroceryItem item) {
      if (item.name.trim().isEmpty) return;
      final rawKey = item.normalizedName.isNotEmpty
          ? item.normalizedName
          : _normalizeGroceryName(item.name);
      final key = rawKey.isNotEmpty ? rawKey : item.name.trim().toLowerCase();
      final existing = groceries[key];
      if (existing == null) {
        groceries[key] = item;
        return;
      }
      final mergedMeals = {
        ...existing.linkedMeals,
        ...item.linkedMeals,
      }.toList()..sort();
      groceries[key] = GroceryItem(
        name: existing.name.length >= item.name.length
            ? existing.name
            : item.name,
        normalizedName: key,
        category: existing.category.isNotEmpty
            ? existing.category
            : item.category,
        totalGrams: existing.totalGrams + item.totalGrams,
        quantityLabel: existing.quantityLabel ?? item.quantityLabel,
        linkedMeals: mergedMeals,
        source: existing.source == 'planned' ? existing.source : item.source,
      );
    }

    final sortedDays = plan.keys.toList()..sort();
    for (final dayIndex in sortedDays) {
      final slots = plan[dayIndex];
      if (slots == null) continue;
      for (final slotEntry in slots.entries) {
        final meal = slotEntry.value;
        if (meal == null || meal.name.trim().isEmpty) continue;
        final mealLabel =
            '${_weekdayShortLabel(dayIndex)} ${meal.mealType.label}';

        if (meal.ingredients.isNotEmpty) {
          for (final ingredient in meal.ingredients) {
            mergeItem(
              GroceryItem(
                name: ingredient,
                normalizedName: _normalizeGroceryName(ingredient),
                category: meal.category,
                totalGrams: 0,
                quantityLabel: null,
                linkedMeals: [mealLabel],
                source: 'planned',
              ),
            );
          }
          continue;
        }

        String category = meal.category;
        if (category.isEmpty &&
            meal.foodId != null &&
            meal.foodId!.isNotEmpty) {
          final food = await _foodRepo.getFoodById(meal.foodId!);
          if (food != null) category = food.category;
        }

        mergeItem(
          GroceryItem(
            name: meal.name,
            normalizedName: _normalizeGroceryName(meal.name),
            category: category,
            totalGrams: meal.portionGrams,
            quantityLabel: null,
            linkedMeals: [mealLabel],
            source: 'planned',
          ),
        );
      }
    }

    if (includePersonalSuggestions) {
      final favoriteIds = StorageHelper.getFavoriteFoodIds();
      for (final foodId in favoriteIds.take(4)) {
        final food = await _foodRepo.getFoodById(foodId);
        if (food == null) continue;
        final normalized = _normalizeGroceryName(food.name);
        if (groceries.containsKey(normalized)) continue;
        mergeItem(
          GroceryItem(
            name: food.name,
            normalizedName: normalized,
            category: food.category,
            totalGrams: _defaultPortionForFood(food),
            linkedMeals: ['Favorilerinden'],
            source: 'favorite',
          ),
        );
      }
    }

    final items = groceries.values.toList()
      ..sort((a, b) {
        final sourceCompare = a.source.compareTo(b.source);
        if (sourceCompare != 0) {
          if (a.source == 'planned') return -1;
          if (b.source == 'planned') return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return items;
  }

  Future<List<Map<String, dynamic>>> getWeeklyPlanSummaryAsync({
    DateTime? weekStart,
  }) async {
    final plan = await loadWeeklyMealPlan(weekStart: weekStart);
    final summary = <Map<String, dynamic>>[];
    final sortedDays = plan.keys.toList()..sort();
    for (final dayIndex in sortedDays) {
      final slots = plan[dayIndex];
      if (slots == null) continue;
      for (final slot in slots.entries) {
        final meal = slot.value;
        if (meal == null || meal.name.trim().isEmpty) continue;
        summary.add({
          'day': _weekdayShortLabel(dayIndex),
          'slot': meal.mealType.label,
          'name': meal.name,
          'kcal': meal.kcal,
          'portionGrams': meal.portionGrams,
          if (meal.ingredients.isNotEmpty) 'ingredients': meal.ingredients,
        });
      }
    }
    return summary;
  }

  String _normalizeGroceryName(String input) {
    final lower = input.trim().toLowerCase();
    return lower
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }

  double _defaultPortionForFood(FoodItem food) {
    return getDefaultPortionForFood(food);
  }

  String _weekdayShortLabel(int dayIndex) {
    const labels = ['Pzt', 'Sal', 'Car', 'Per', 'Cum', 'Cmt', 'Paz'];
    if (dayIndex < 0 || dayIndex >= labels.length) return 'Gun';
    return labels[dayIndex];
  }

  String _goalLabel(Goal goal) {
    switch (goal) {
      case Goal.bulk:
        return 'Kas kazanımı ve kilo alma';
      case Goal.cut:
        return 'Yağ yakımı ve kilo verme';
      case Goal.maintain:
        return 'Kilo koruma';
      case Goal.strength:
        return 'Güç artışı';
    }
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

  Future<NutritionAiResponseModel?> getStructuredNutritionResponse(
    String message, {
    String task = 'chat',
    Map<String, dynamic>? nutritionContext,
  }) async {
    if (_aiService == null || !_aiService!.isReady) return null;
    try {
      return await _aiService!.getStructuredNutritionResponse(
        message,
        getDietContext(),
        task: task,
        nutritionContext: nutritionContext ?? getNutritionAiContext(),
      );
    } catch (e) {
      debugPrint('DietProvider.getStructuredNutritionResponse error: $e');
      return null;
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

  /// Son 7 günlük kalori özetini getirir.
  Future<Map<String, DiaryTotals>> getWeeklySummary() async {
    final result = <String, DiaryTotals>{};
    try {
      final today = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final day = today.subtract(Duration(days: i));
        final dateStr =
            '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final totals = await _diaryService.getTotalsByDate(day);
        result[dateStr] = totals;
      }
    } catch (e) {
      debugPrint('DietProvider.getWeeklySummary hatası: $e');
    }
    return result;
  }

  /// Son [days] günlük kalori + makro özetini getirir.
  /// getWeeklySummary'nin genelleştirilmiş hali.
  Future<Map<String, DiaryTotals>> getSummaryForRange(int days) async {
    final result = <String, DiaryTotals>{};
    try {
      final today = DateTime.now();
      for (int i = days - 1; i >= 0; i--) {
        final day = today.subtract(Duration(days: i));
        final dateStr =
            '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final totals = await _diaryService.getTotalsByDate(day);
        result[dateStr] = totals;
      }
    } catch (e) {
      debugPrint('DietProvider.getSummaryForRange hatası: $e');
    }
    return result;
  }

  /// Favori yemekleri yükler.
  Future<List<FoodItem>> loadFavorites() async {
    try {
      final ids = StorageHelper.getFavoriteFoodIds();
      if (ids.isEmpty) return [];
      final items = <FoodItem>[];
      for (final id in ids) {
        final item = await _foodRepo.getFoodById(id);
        if (item != null) items.add(item);
      }
      return items;
    } catch (e) {
      debugPrint('DietProvider.loadFavorites hatası: $e');
      return [];
    }
  }

  /// Favori durumunu değiştirir.
  void toggleFavorite(String foodId) {
    StorageHelper.toggleFavorite(foodId);
    notifyListeners();
  }

  /// Bir besinin favori olup olmadığını kontrol eder.
  bool isFavorite(String foodId) => StorageHelper.isFavorite(foodId);

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
    final f = await _foodRepo.getFoodById(id);
    if (f != null) return f;
    if (_useRemoteSearch) {
      return await _remoteRepo.getFoodById(id);
    }
    return null;
  }

  /// Barkod ile besin getir
  Future<FoodItem?> getFoodByBarcode(String barcode) async {
    final f = await _foodRepo.getFoodByBarcode(barcode);
    if (f != null) return f;
    // Barkodta remote fallback her zaman denensin.
    final result = await _remoteRepo.getByBarcode(barcode);
    if (result != null) {
      return result;
    }
    return null;
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
        protein: _safeDouble(food.proteinPer100g * ratio),
        carb: _safeDouble(food.carbPer100g * ratio),
        fat: _safeDouble(food.fatPer100g * ratio),
        createdAt: DateTime.now(),
      );
      await _diaryRepo.addEntry(entry);
      await loadDay(DateTime(date.year, date.month, date.day));
    } catch (e) {
      debugPrint('DietProvider.addEntry hatası: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Birden fazla besini tek seferde ekler (çoklu seçim özelliği için).
  Future<void> addMultipleEntries({
    required List<({FoodItem food, double grams})> items,
    required MealType mealType,
    required DateTime date,
  }) async {
    if (items.isEmpty) return;
    try {
      final normalizedDate = DiaryService.normalizeDate(date);
      for (final item in items) {
        final grams = item.grams;
        if (grams <= 0 || grams.isNaN || grams.isInfinite) continue;
        final food = item.food;
        final kcal = FoodCalculator.calculateCalories(food, grams);
        final ratio = grams / 100;
        final entry = FoodEntry(
          id: _uuid.v4(),
          date: normalizedDate,
          mealType: mealType,
          foodId: food.id,
          foodName: food.name,
          grams: grams,
          calculatedKcal: kcal.isNaN || kcal.isInfinite ? 0 : kcal,
          protein: _safeDouble(food.proteinPer100g * ratio),
          carb: _safeDouble(food.carbPer100g * ratio),
          fat: _safeDouble(food.fatPer100g * ratio),
          createdAt: DateTime.now(),
        );
        await _diaryRepo.addEntry(entry);
      }
      await loadDay(DateTime(date.year, date.month, date.day));
    } catch (e) {
      debugPrint('DietProvider.addMultipleEntries hatası: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // ── Kayıtlı Öğünler ────────────────────────────────────────────────────────

  List<SavedMeal> getSavedMeals() => StorageHelper.getSavedMeals();

  Future<void> saveCurrentSelectionAsMeal({
    required String name,
    required List<({FoodItem food, double grams})> items,
  }) async {
    if (name.trim().isEmpty || items.isEmpty) return;
    final meal = SavedMeal(
      id: _uuid.v4(),
      name: name.trim(),
      items: items
          .map(
            (e) => SavedMealItem(
              foodId: e.food.id,
              foodName: e.food.name,
              grams: e.grams,
            ),
          )
          .toList(),
      createdAt: DateTime.now(),
    );
    await StorageHelper.saveSavedMeal(meal);
    notifyListeners();
  }

  Future<void> deleteSavedMeal(String mealId) async {
    await StorageHelper.deleteSavedMeal(mealId);
    notifyListeners();
  }

  /// Kayıtlı öğündeki tüm besinleri günlüğe ekler.
  Future<void> addSavedMealToDay({
    required SavedMeal meal,
    required MealType mealType,
    required DateTime date,
  }) async {
    final foodItems = <({FoodItem food, double grams})>[];
    for (final item in meal.items) {
      final food = await getFoodById(item.foodId);
      if (food != null) {
        foodItems.add((food: food, grams: item.grams));
      }
    }
    await addMultipleEntries(items: foodItems, mealType: mealType, date: date);
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

  /// Mevcut bir günlük kaydını günceller (gramaj, öğün tipi değişikliği).
  Future<void> updateEntry({
    required String entryId,
    required double newGrams,
    required MealType newMealType,
  }) async {
    if (newGrams <= 0 || newGrams.isNaN || newGrams.isInfinite) {
      debugPrint('DietProvider.updateEntry: Geçersiz gram: $newGrams');
      return;
    }
    try {
      // Mevcut entry'yi bul
      final existing = _entries.firstWhere(
        (e) => e.id == entryId,
        orElse: () => throw StateError('Entry not found: $entryId'),
      );

      // Orijinal besin değerlerini 100g başına geri hesapla
      final oldRatio = existing.grams > 0 ? existing.grams / 100 : 1;
      final per100Kcal = oldRatio > 0 ? existing.calculatedKcal / oldRatio : 0;
      final per100Protein = oldRatio > 0 ? existing.protein / oldRatio : 0;
      final per100Carb = oldRatio > 0 ? existing.carb / oldRatio : 0;
      final per100Fat = oldRatio > 0 ? existing.fat / oldRatio : 0;

      // Yeni gramajla hesapla
      final newRatio = newGrams / 100;
      final updatedEntry = FoodEntry(
        id: existing.id,
        date: existing.date,
        mealType: newMealType,
        foodId: existing.foodId,
        foodName: existing.foodName,
        grams: newGrams,
        calculatedKcal: per100Kcal * newRatio,
        protein: per100Protein * newRatio,
        carb: per100Carb * newRatio,
        fat: per100Fat * newRatio,
        createdAt: existing.createdAt,
      );

      await _diaryRepo.updateEntry(updatedEntry);
      await loadDay(_selectedDate);
    } catch (e) {
      debugPrint('DietProvider.updateEntry hatası: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// AI önerilen yemeği doğrudan günlüğe ekle (FoodItem olmadan, makro değerleriyle)
  Future<void> addAiMealToDiary({
    required String mealName,
    required double kcal,
    required double protein,
    required double carbs,
    required double fat,
    required MealType mealType,
    DateTime? date,
    double grams = 100, // seçilen gramaja göre ölçekle
  }) async {
    if (kcal <= 0 || kcal.isNaN || kcal.isInfinite) {
      debugPrint('DietProvider.addAiMealToDiary: Geçersiz kcal değeri: $kcal');
      return;
    }
    try {
      final targetDate = date ?? _selectedDate;
      // Makroları gramaja göre ölçekle
      final scale = grams / 100.0;
      final entry = FoodEntry(
        id: _uuid.v4(),
        date: DiaryService.normalizeDate(targetDate),
        mealType: mealType,
        foodId: 'ai_meal_${DateTime.now().millisecondsSinceEpoch}',
        foodName: mealName,
        grams: grams,
        calculatedKcal: (kcal * scale).isNaN || (kcal * scale).isInfinite
            ? 0
            : kcal * scale,
        protein: _safeDouble(protein * scale),
        carb: _safeDouble(carbs * scale),
        fat: _safeDouble(fat * scale),
        createdAt: DateTime.now(),
      );
      await _diaryRepo.addEntry(entry);
      await loadDay(
        DateTime(targetDate.year, targetDate.month, targetDate.day),
      );

      // Send feedback to backend for taste learning (fire and forget)
      _sendMealFeedback(mealName, <String>[], mealType.name);
    } catch (e) {
      debugPrint('DietProvider.addAiMealToDiary hatası: $e');
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Send meal feedback to backend for taste profile learning
  Future<void> _sendMealFeedback(
    String mealName,
    List<String> tags,
    String mealType,
  ) async {
    try {
      await ApiClient().post(
        '/api/ai/nutrition/feedback',
        data: {'mealName': mealName, 'tags': tags, 'mealType': mealType},
      );
      debugPrint('Feedback sent: $mealName');
    } catch (e) {
      // Silent fail - feedback is not critical
      debugPrint('Feedback send failed (ignored): $e');
    }
  }

  /// Haftalık rapor taslağını oluşturur ve PDF paylaşımını tetikler
  Future<void> generateWeeklyPdfReport() async {
    try {
      final now = DateTime.now();
      final weekStart = now.subtract(const Duration(days: 6));

      List<DailyDietLog> logs = [];

      for (int i = 0; i < 7; i++) {
        final date = weekStart.add(Duration(days: i));
        // O günün entry'lerini çek
        final entriesForDay = await _diaryRepo.getEntriesByDate(
          DiaryService.normalizeDate(date),
        );

        double kcal = 0;
        double pro = 0;
        double carb = 0;
        double fat = 0;

        for (var e in entriesForDay) {
          kcal += e.calculatedKcal;
          pro += e.protein;
          carb += e.carb;
          fat += e.fat;
        }

        logs.add(
          DailyDietLog(
            date: date,
            totalCalories: kcal,
            totalProtein: pro,
            totalCarbs: carb,
            totalFat: fat,
          ),
        );
      }

      await PdfReportService.generateAndShareWeeklyReport(
        userName: _profile?.name ?? 'Kullanıcı',
        weekStart: weekStart,
        weekEnd: now,
        dailyLogs: logs,
      );
    } catch (e) {
      debugPrint('DietProvider.generateWeeklyPdfReport hatası: $e');
      _error = 'Rapor oluşturulurken hata meydana geldi.';
      notifyListeners();
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
    if (effectiveTargetKcal <= 0) {
      return {'kcal': 0, 'protein': 0, 'carb': 0, 'fat': 0};
    }

    final factor = amountG / 100.0;
    final targets = macroTargets;

    return {
      'kcal': (item.kcalPer100g * factor) / effectiveTargetKcal,
      'protein': targets.protein > 0
          ? (item.proteinPer100g * factor) / targets.protein
          : 0,
      'carb': targets.carb > 0 ? (item.carbPer100g * factor) / targets.carb : 0,
      'fat': targets.fat > 0 ? (item.fatPer100g * factor) / targets.fat : 0,
    };
  }

  /// Türkçe karakterleri ASCII'ye çevirir (eşleşme için).
  static String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('i', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's');
  }

  /// Öğüne uygun anahtar kelimeler (kategori / tag / isim eşleşmesi için).
  static List<String> _mealKeywords(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return [
          'kahvalti',
          'kahvaltilik',
          'yumurta',
          'peynir',
          'sut',
          'yogurt',
          'ekmek',
          'recel',
          'bal',
          'misir',
          'gevregi',
          'zeytin',
          'domates',
          'salatalik',
          'borek',
          'pogaca',
          'simit',
          'cay',
          'tahil',
          'sut urun',
        ];
      case MealType.lunch:
        return [
          'ogle',
          'corba',
          'ana yemek',
          'yemek',
          'pilav',
          'makarna',
          'et',
          'tavuk',
          'balik',
          'kofte',
          'kebap',
          'salata',
          'sebze',
          'bakliyat',
          'mercimek',
          'fasulye',
          'borek',
          'pide',
          'lahmacun',
        ];
      case MealType.dinner:
        return [
          'aksam',
          'corba',
          'yemek',
          'et',
          'tavuk',
          'balik',
          'salata',
          'sebze',
          'pilav',
          'makarna',
          'zeytinyagli',
          'bakliyat',
          'ana yemek',
        ];
      case MealType.snack:
        return [
          'atistirma',
          'atistirmalik',
          'meyve',
          'kuruyemis',
          'biskivi',
          'cikolata',
          'kek',
          'kurabiye',
          'cips',
          'kraker',
          'smoothie',
          'meyve suyu',
          'findik',
          'ceviz',
          'badem',
          'elma',
          'muz',
          'portakal',
        ];
    }
  }

  /// Kalan kalori ve makrolara göre "Ne ekleyeyim?" önerisi.
  /// [query] verilirse sadece o kelimeyle eşleşen yemekler arasından önerilir (örn. "lavaş" → lavaşlı yemekler).
  /// Öğün tipine göre öncelikli ve hariç tutulan kategorileri döner.
  static ({List<String> primary, List<String> excluded}) _mealCategories(
    MealType type,
  ) {
    switch (type) {
      case MealType.breakfast:
        return (
          primary: ['Kahvaltılık', 'Süt Ürünleri'],
          excluded: ['Fast Food', 'Tatlı', 'İçecek'],
        );
      case MealType.lunch:
        return (
          primary: [
            'Yemek',
            'Et / Tavuk',
            'Çorba',
            'Salata',
            'Tahıl & Bakliyat',
            'Sebze',
          ],
          excluded: ['Kahvaltılık', 'Atıştırmalık', 'Tatlı', 'İçecek'],
        );
      case MealType.dinner:
        return (
          primary: [
            'Yemek',
            'Et / Tavuk',
            'Çorba',
            'Sebze',
            'Salata',
            'Tahıl & Bakliyat',
          ],
          excluded: ['Kahvaltılık', 'Atıştırmalık', 'Fast Food', 'İçecek'],
        );
      case MealType.snack:
        return (
          primary: [
            'Atıştırmalık',
            'Meyve',
            'Meyve & Sebze',
            'Süt Ürünleri',
            'Kuruyemiş',
          ],
          excluded: ['Yemek', 'Et / Tavuk', 'Çorba', 'Fast Food', 'Tatlı'],
        );
    }
  }

  static const List<String> _treatSuggestionKeywords = [
    'baklava',
    'sobiyet',
    'şobiyet',
    'şöbiyet',
    'kadayif',
    'kadayif',
    'kunefe',
    'künefe',
    'revani',
    'tulumba',
    'sekerpare',
    'şekerpare',
    'lokma',
    'helva',
    'kazandibi',
    'profiterol',
    'sutlac',
    'sütlaç',
    'cheesecake',
    'tiramisu',
    'waffle',
    'donut',
    'dondurma',
    'pasta',
    'kurabiye',
    'kek',
    'cikolata',
    'çikolata',
    'serbet',
    'şerbet',
    'tatli',
    'tatlı',
  ];

  bool _queryExplicitlyAllowsTreats(String? query) {
    final normalized = _norm(query ?? '');
    if (normalized.isEmpty) return false;
    for (final keyword in _treatSuggestionKeywords) {
      if (normalized.contains(_norm(keyword))) return true;
    }
    return false;
  }

  bool _isTreatLikeFood(FoodItem item) {
    final normalizedBlob = _norm(
      [item.name, item.category, ...item.aliases, ...item.tags].join(' '),
    );
    if (_norm(item.category).contains('tatli')) return true;
    if (_norm(item.category).contains('icecek') && item.kcalPer100g > 70) {
      return true;
    }
    for (final keyword in _treatSuggestionKeywords) {
      if (normalizedBlob.contains(_norm(keyword))) return true;
    }
    final highSugarLowProtein =
        item.carbPer100g >= 35 &&
        item.proteinPer100g <= 6 &&
        item.kcalPer100g >= 220;
    return highSugarLowProtein;
  }

  Future<List<FoodItem>> getSuggestedFoods(
    MealType mealType, {
    int limit = 24,
    String? query,
  }) async {
    final insights = await getSuggestedFoodInsights(
      mealType,
      limit: limit,
      query: query,
    );
    return insights.map((e) => e.item).toList();
  }

  Future<List<SuggestedFoodInsight>> getSuggestedFoodInsights(
    MealType mealType, {
    int limit = 24,
    String? query,
  }) async {
    final remKcal = remainingKcal;
    final searchQuery = query?.trim();
    final useQuery = searchQuery != null && searchQuery.isNotEmpty;
    final allowTreats = _queryExplicitlyAllowsTreats(searchQuery);
    final cats = _mealCategories(mealType);
    final dislikedIds = StorageHelper.getDislikedFoodIds().toSet();

    try {
      final recentSignals = await _buildRecentPreferenceSignals();
      List<FoodItem> pool;

      if (useQuery) {
        // Arama sorgusunda kategori filtresi uygulanmaz — tüm havuzda ara
        pool = await _foodRepo.searchFoods(searchQuery, category: null);
      } else {
        // Önce birincil kategorilerden yemekleri çek
        final primaryPool = <FoodItem>[];
        for (final cat in cats.primary) {
          final items = await _foodRepo.searchFoods('', category: cat);
          primaryPool.addAll(items);
        }

        if (primaryPool.length >= limit) {
          pool = primaryPool;
        } else {
          // Yeterli sonuç yoksa hariç tutulanlar dışındaki kategorilerden tamamla
          final full = await _foodRepo.searchFoods('', category: null);
          final extras = full
              .where(
                (f) =>
                    !cats.primary.contains(f.category) &&
                    !cats.excluded.contains(f.category) &&
                    !primaryPool.any((p) => p.id == f.id),
              )
              .toList();
          pool = [...primaryPool, ...extras];
        }
      }

      final eatenIds = _entries.map((e) => e.foodId).toSet();
      final List<_ScoredSuggestion> scored = [];

      for (final item in pool) {
        if (dislikedIds.contains(item.id)) continue;
        if (!_matchesNutritionPreferences(item)) {
          continue;
        }
        if (!allowTreats && _isTreatLikeFood(item)) {
          continue;
        }
        double score = 0;
        final reasons = <String>[];
        final isRecipeSuggestion = item.id.startsWith('recipe_');

        // 0. Arama sorgusu alaka düzeyi bonusu — isim eşleşmesi önce gelir
        if (useQuery) {
          final qn = _norm(searchQuery);
          final nameNorm = _norm(item.name);
          final tagNorm = _norm(item.tags.join(' '));
          final catNorm = _norm(item.category);
          if (nameNorm == qn) {
            score += 350;
            reasons.add('Aradığın yiyecekle tam eşleşme');
          } else if (nameNorm.startsWith(qn)) {
            score += 220;
            reasons.add('Aradığın isimle başlıyor');
          } else if (nameNorm.contains(qn)) {
            score += 130;
          } else if (tagNorm.contains(qn)) {
            score += 75;
          } else if (catNorm.contains(qn)) {
            score += 45;
          }
        }

        // 1. Kategori uyumu — birincil kategorideyse büyük bonus
        final isPrimary = cats.primary.contains(item.category);
        final isExcluded = cats.excluded.contains(item.category);
        if (isPrimary) {
          score += 120;
          reasons.add('Bu öğün için uygun kategoride');
        } else if (isExcluded) {
          score -= 150; // hariç tutulanlar neredeyse hiç gelmez
        }
        if (isRecipeSuggestion) {
          score += 26;
          reasons.add('Hazır tarif olarak uygulayabilirsin');
        }

        // 2. Kalori uyumu
        final itemKcal = item.kcalPer100g;
        final kcalDiff = (remKcal - itemKcal).abs();
        score += (500 - kcalDiff).clamp(0, 500) / 10;
        if (itemKcal > 0 && remKcal > 0 && itemKcal <= remKcal * 1.15) {
          reasons.add('Kalan kaloriye rahat sığar');
        }

        // 3. Makro uyumu (moda göre)
        double weightP = 1.0, weightC = 1.0, weightF = 1.0;
        switch (_suggestionMode) {
          case SuggestionMode.highProtein:
            weightP = 2.5;
            weightC = 0.5;
            break;
          case SuggestionMode.lowCarb:
            weightC = 0.1;
            weightP = 1.5;
            weightF = 1.2;
            break;
          case SuggestionMode.balanced:
            break;
        }
        score += (item.proteinPer100g * weightP * 2);
        score += (item.carbPer100g * weightC);
        score += (item.fatPer100g * weightF);
        if (_suggestionMode == SuggestionMode.highProtein &&
            item.proteinPer100g >= 18) {
          reasons.add('Protein açığını kapatmaya yardımcı olur');
        } else if (_suggestionMode == SuggestionMode.lowCarb &&
            item.carbPer100g <= 8) {
          reasons.add('Karbonhidratı düşük tutar');
        } else if (_suggestionMode == SuggestionMode.balanced &&
            item.proteinPer100g >= 10 &&
            item.carbPer100g <= 35 &&
            item.fatPer100g <= 18) {
          reasons.add('Makro dengesi günlük hedefe uyumlu');
        }

        if (_nutritionPreferences.vegetarian || _nutritionPreferences.vegan) {
          reasons.add('Seçtiğin beslenme tercihine uygun');
        }
        if (_nutritionPreferences.glutenFree) {
          reasons.add('Glutensiz filtreye göre seçildi');
        }
        if (_nutritionPreferences.lactoseFree) {
          reasons.add('Laktozsuz filtreye göre seçildi');
        }

        // 4. Yenilen ürün cezası
        if (eatenIds.contains(item.id)) {
          score -= 20;
        }

        // 5. Favori Yemek Bonusu
        final isFavoriteLike = _frequentFoodIds.contains(item.id);
        if (isFavoriteLike) {
          score += 40;
          reasons.add('Sık tercih ettiğin seçeneklere benziyor');
        }

        // 6. Keyword bonus (tag/isim eşleşmesi)
        final mealKeywords = _mealKeywords(mealType);
        final tagsNorm = _norm(item.tags.join(' '));
        final nameNorm = _norm(item.name);
        for (final kw in mealKeywords) {
          if (tagsNorm.contains(kw) || nameNorm.contains(kw)) {
            score += 30;
            break;
          }
        }

        // 7. Son günlerdeki gerçek tercihlere göre kişiselleştirme
        final recentCount = recentSignals.recentFoodCounts[item.id] ?? 0;
        final mealTypeCount =
            recentSignals.mealTypeFoodCounts['${mealType.name}:${item.id}'] ??
            0;
        if (recentCount > 0) {
          score += (recentCount * 6).clamp(0, 24);
          if (!reasons.contains('Sık tercih ettiğin seçeneklere benziyor')) {
            reasons.add('Son günlerde benzer seçimlerin olmuş');
          }
        }
        if (mealTypeCount > 0) {
          score += (mealTypeCount * 10).clamp(0, 30);
          reasons.add('Bu öğünde daha önce de iyi uyum sağlamış');
        }

        // 8. Hedefe göre yönlendirme
        switch (_profile?.goal) {
          case Goal.cut:
            score += (200 - item.kcalPer100g).clamp(0, 150) / 5;
            if (item.kcalPer100g <= 120) {
              reasons.add('Kalori açığında güvenli seçenek');
            } else if (item.kcalPer100g <= 180 && item.proteinPer100g >= 10) {
              reasons.add('Doyurucu ama hafif');
            }
            if (item.proteinPer100g >= 18 && item.kcalPer100g <= 200) {
              reasons.add('Kas korur, yağ yakar');
            }
            break;
          case Goal.bulk:
            score += item.kcalPer100g.clamp(0, 400) / 5;
            if (item.kcalPer100g >= 250) {
              reasons.add('Kalori artırımı için uygun');
            } else if (item.kcalPer100g >= 150 && item.proteinPer100g >= 15) {
              reasons.add('Kaliteli kalori + protein');
            }
            if (item.proteinPer100g >= 20) {
              reasons.add('Kas inşası için protein açısından zengin');
            }
            break;
          case Goal.strength:
            score += item.proteinPer100g * 1.5;
            if (item.proteinPer100g >= 25) {
              reasons.add('Kas onarımı için güçlü protein kaynağı');
            } else if (item.proteinPer100g >= 15) {
              reasons.add('Antrenman sonrası kas desteği sağlar');
            }
            if (item.carbPer100g >= 20 && item.proteinPer100g >= 10) {
              reasons.add('Güç egzersizi için karbonhidrat + protein dengesi');
            }
            break;
          case Goal.maintain:
            if (item.proteinPer100g >= 12 &&
                item.kcalPer100g <= 250 &&
                item.fatPer100g <= 15) {
              reasons.add('Dengeyi korumak için ideal seçim');
            }
            break;
          case null:
            break;
        }

        // 9. Çevresel Faktörler (Hava / Mevsimsel)
        final month = DateTime.now().month;
        final hour = DateTime.now().hour;
        final lowerName = _norm(item.name);
        if (month >= 5 && month <= 9) {
          // Yaz ve sıcak aylar
          if (lowerName.contains('soguk') ||
              lowerName.contains('smoothie') ||
              lowerName.contains('salata') ||
              item.category == 'Meyve') {
            score += 25;
            if (!reasons.contains('Hava sıcak; ferahlatıcı bir seçenek.')) {
              reasons.add('Hava sıcak; ferahlatıcı bir seçenek.');
            }
          }
        } else if (month >= 11 || month <= 3) {
          // Kış ve soğuk aylar
          if (lowerName.contains('sicak') ||
              lowerName.contains('corba') ||
              lowerName.contains('firin') ||
              item.category.contains('Sulu Yemek')) {
            score += 25;
            if (!reasons.contains('Soğuk havalar için sıcak bir alternatif.')) {
              reasons.add('Soğuk havalar için sıcak bir alternatif.');
            }
          }
        }

        // Gece geç saatler (Sirkadiyen Ritim Uyumlu)
        if (hour >= 21) {
          if (item.kcalPer100g > 250) {
            score -= 60; // Geç saatte ağır şeyleri engelle
          } else if (item.kcalPer100g < 120 &&
              !lowerName.contains('kahve') &&
              !lowerName.contains('kafein')) {
            score += 35;
            if (!reasons.contains(
              'Geç saatler için uyku kaçırmayan, hafif bir atıştırmalık.',
            )) {
              reasons.add(
                'Geç saatler için uyku kaçırmayan, hafif bir atıştırmalık.',
              );
            }
          }
        }

        // 9. Öğün tipine göre uyum bonusu + saat bazlı ağırlık
        switch (mealType) {
          case MealType.breakfast:
            if (item.carbPer100g >= 20) {
              score += 12;
            }
            if (item.category.contains('Süt') ||
                item.category.contains('Kahvaltı')) {
              score += 10;
            }
            if (item.proteinPer100g >= 15) {
              score += 8;
            }
            // Sabah saati (07-10) kahvaltı kategorisi boost
            if (hour >= 7 && hour <= 10) {
              if (item.category.contains('Kahvaltı') ||
                  item.category.contains('Süt')) {
                score += 15;
              }
            }
            break;
          case MealType.dinner:
            if (item.kcalPer100g > 350) {
              score -= 18;
            }
            if (item.proteinPer100g >= 15 && item.kcalPer100g <= 220) {
              score += 14;
            }
            if (item.category.contains('Çorba') ||
                item.category.contains('Sebze')) {
              score += 8;
            }
            if (item.fatPer100g <= 10 && item.proteinPer100g >= 10) {
              score += 8;
            }
            // Geç akşam (21+) ağır yiyeceklere ek ceza, hafife bonus
            if (hour >= 21) {
              if (item.kcalPer100g > 400) {
                score -= 20;
              }
              if (item.kcalPer100g <= 150 && item.proteinPer100g >= 10) {
                score += 18;
                if (reasons.length < 3) {
                  reasons.add('Geç saatte hafif ve doyurucu');
                }
              }
            }
            break;
          case MealType.snack:
            if (item.kcalPer100g > 300) {
              score -= 20;
            }
            if (item.kcalPer100g <= 100) {
              score += 15;
            }
            if (item.category.contains('Meyve') ||
                item.category.contains('Kuruyemiş')) {
              score += 12;
            }
            break;
          case MealType.lunch:
            // Öğle için sebze ve bakliyat bonusu
            if (item.category.contains('Sebze') ||
                item.category.contains('Salata')) {
              score += 8;
            }
            break;
        }

        // 10. Protein verimi bonusu (protein / kalori oranı)
        if (item.kcalPer100g > 0) {
          final proteinEfficiency =
              item.proteinPer100g / item.kcalPer100g * 100;
          if (proteinEfficiency >= 40) {
            score += 32;
            if (reasons.length < 3) {
              reasons.add('Kaloriye göre protein verimi çok yüksek');
            }
          } else if (proteinEfficiency >= 25) {
            score += 16;
            if (reasons.length < 3) reasons.add('Verimli protein kaynağı');
          }
        }

        // 11. Sebze / bakliyat mikro besin bonusu (dengeli modda)
        if (_suggestionMode == SuggestionMode.balanced) {
          final isVeg =
              item.category.contains('Sebze') ||
              item.category.contains('Salata');
          final nameNorm = _norm(item.name);
          final isLegume =
              item.category.contains('Bakliyat') ||
              nameNorm.contains('mercimek') ||
              nameNorm.contains('nohut') ||
              nameNorm.contains('fasulye') ||
              nameNorm.contains('bulgur');
          if (isVeg || isLegume) {
            score += 14;
            if (reasons.length < 3 && reasons.isEmpty) {
              reasons.add('Lif ve mikro besin açısından zengin');
            }
          }
        }

        // Snack porsiyon üst sınırını düşür
        final rawPortionG = _suggestedPortionForRemaining(item, remKcal);
        final suggestedPortionG = mealType == MealType.snack
            ? rawPortionG.clamp(25.0, 140.0)
            : rawPortionG;
        if (score > 0) {
          scored.add(
            _ScoredSuggestion(
              item,
              score,
              reasons.toSet().take(3).toList(),
              suggestedPortionG,
              isFavoriteLike,
            ),
          );
        }
      }

      scored.sort((a, b) => b.score.compareTo(a.score));

      final List<SuggestedFoodInsight> finalResults = [];
      final Map<String, int> catCounter = {};

      // Arama sorgusunda kategori sınırını gevşet (kullanıcı belirli bir şey arıyor)
      final catCap = useQuery ? 12 : 5;

      for (final s in scored) {
        if (finalResults.length >= limit) break;
        // Tek kategoriden çok fazla yemek gelmesin
        final catCount = catCounter[s.item.category] ?? 0;
        if (catCount >= catCap) continue;
        finalResults.add(
          SuggestedFoodInsight(
            item: s.item,
            score: s.score,
            reasons: s.reasons,
            suggestedPortionG: s.suggestedPortionG,
            isFavoriteLike: s.isFavoriteLike,
          ),
        );
        catCounter[s.item.category] = catCount + 1;
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

  void reset() {
    _profile = null;
    _dailyTargetKcal = null;
    _entries = [];
    _totals = const DiaryTotals();
    _error = null;
    _loading = false;
    _currentStreak = 0;
    _activeUserSuffix = null;
    _waterLiters = 0.0;
    _nutritionPreferences = const NutritionPreferences();
    notifyListeners();
  }

  void _ensureUserScope() {
    final current = StorageHelper.getUserStorageSuffix();
    if (_activeUserSuffix == null) {
      _activeUserSuffix = current;
      return;
    }
    if (_activeUserSuffix != current) {
      _profile = null;
      _dailyTargetKcal = null;
      _entries = [];
      _totals = const DiaryTotals();
      _error = null;
      _currentStreak = 0;
      _waterLiters = 0.0;
      _nutritionPreferences = NutritionPreferences.fromJson(
        StorageHelper.getNutritionPreferences(),
      );
      _activeUserSuffix = current;
    }
  }

  static double _safeDouble(double v) =>
      v.isNaN || v.isInfinite ? 0.0 : v;

  static const Set<String> _porkTokens = {
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

  static const Set<String> _meatTokens = {
    'et',
    'etli',
    'kirmizi et',
    'beef',
    'veal',
    'lamb',
    'kuzu',
    'kuzulu',
    'dana',
    'danali',
    'tavuk',
    'tavuklu',
    'chicken',
    'hindi',
    'turkey',
    'balik',
    'balikli',
    'fish',
    'somon',
    'ton baligi',
    'tuna',
    'shrimp',
    'karides',
    'anchovy',
    'hamsi',
    'meat',
    'kofte',
    'kebap',
    'kavurma',
    'sosis',
    'sucuk',
    'salam',
    'pastirma',
    'biftek',
    'antrikot',
  };

  static const Set<String> _veganExtraTokens = {
    'yumurta',
    'yumurtali',
    'egg',
    'sut',
    'sutlu',
    'milk',
    'peynir',
    'peynirli',
    'cheese',
    'yogurt',
    'yogurtlu',
    'ayran',
    'kefir',
    'butter',
    'tereyagi',
    'tereyagli',
    'cream',
    'krema',
    'kremali',
    'whey',
    'bal',
    'balli',
    'honey',
    'sutlac',
    'kasein',
    'casein',
  };

  static const Set<String> _lactoseTokens = {
    'sut',
    'sutlu',
    'milk',
    'peynir',
    'peynirli',
    'cheese',
    'yogurt',
    'yogurtlu',
    'ayran',
    'kefir',
    'whey',
    'cream',
    'krema',
    'kremali',
    'tereyagi',
    'tereyagli',
    'butter',
    'sutlac',
    'kasein',
    'casein',
  };

  static const Set<String> _glutenTokens = {
    'bugday',
    'wheat',
    'arpa',
    'barley',
    'cavdar',
    'rye',
    'bulgur',
    'makarna',
    'pasta',
    'bread',
    'ekmek',
    'lavas',
    'lavash',
    'durum',
    'wrap',
    'noodle',
    'sehriye',
    'un',
    'unlu',
    'borek',
    'pogaca',
    'simit',
    'kraker',
    'biskuvi',
    'kek',
    'kurabiye',
    'pizza',
    'pide',
    'lahmacun',
    'waffle',
    'krep',
    'pancake',
    'kruvasan',
    'tart',
    'gevrek',
    'galeta',
    'manti',
    'eriste',
  };

  bool _matchesNutritionPreferences(FoodItem item) {
    final prefs = _nutritionPreferences;
    if (!prefs.hasAnyFilter && !prefs.excludePork) return true;
    final haystack =
        ' ${_norm([item.name, item.category, ...item.aliases, ...item.tags].join(' '))} ';

    // Etsiz veya vegan/bitkisel olarak isimlendirilmiş ürünler için basit bayrak
    final isEtsizOrVegan =
        haystack.contains(' etsiz ') ||
        haystack.contains(' vegan ') ||
        haystack.contains(' bitkisel ');

    bool containsAny(Set<String> tokens) {
      for (final token in tokens) {
        if (haystack.contains(' $token ')) {
          return true;
        }
      }
      return false;
    }

    if (prefs.excludePork && containsAny(_porkTokens)) return false;

    if (prefs.vegetarian &&
        !isEtsizOrVegan &&
        containsAny(_meatTokens.union(_porkTokens))) {
      return false;
    }

    if (prefs.vegan &&
        !isEtsizOrVegan &&
        containsAny(_meatTokens.union(_porkTokens).union(_veganExtraTokens))) {
      return false;
    }

    if (prefs.lactoseFree &&
        !haystack.contains(' laktozsuz ') &&
        containsAny(_lactoseTokens)) {
      return false;
    }

    if (prefs.glutenFree &&
        !haystack.contains(' glutensiz ') &&
        containsAny(_glutenTokens)) {
      return false;
    }

    return true;
  }

  /// Get logs for the last N days (for AI Coach analysis)
  Future<List<DailyDietLog>> getRecentDaysLogs(int days) async {
    final List<DailyDietLog> logs = [];
    final today = DateTime.now();

    for (int i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T').first;
      final entries = await _diaryRepo.getEntriesByDate(dateStr);
      final totals = await _diaryRepo.getTotalsByDate(dateStr);

      logs.add(
        DailyDietLog(
          date: date,
          totalKcal: totals.totalKcal,
          totalProtein: totals.totalProtein,
          totalCarb: totals.totalCarb,
          totalFat: totals.totalFat,
          entries: entries,
        ),
      );
    }
    return logs;
  }

  Future<_RecentPreferenceSignals> _buildRecentPreferenceSignals() async {
    final recentFoodCounts = <String, int>{};
    final mealTypeFoodCounts = <String, int>{};
    final today = DateTime.now();

    for (int i = 0; i < 10; i++) {
      final date = today.subtract(Duration(days: i));
      final entriesForDay = await _diaryRepo.getEntriesByDate(
        DiaryService.normalizeDate(date),
      );
      for (final entry in entriesForDay) {
        recentFoodCounts.update(entry.foodId, (v) => v + 1, ifAbsent: () => 1);
        final mealKey = '${entry.mealType.name}:${entry.foodId}';
        mealTypeFoodCounts.update(mealKey, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    return _RecentPreferenceSignals(
      recentFoodCounts: recentFoodCounts,
      mealTypeFoodCounts: mealTypeFoodCounts,
    );
  }

  double _suggestedPortionForRemaining(FoodItem item, double remKcal) {
    if (item.kcalPer100g <= 0 || remKcal <= 0) {
      return getCategoryDefaultGrams(item.category);
    }
    final targetGrams = (remKcal / item.kcalPer100g) * 100;
    return targetGrams.clamp(60.0, 260.0);
  }
}

class _ScoredSuggestion {
  final FoodItem item;
  final double score;
  final List<String> reasons;
  final double suggestedPortionG;
  final bool isFavoriteLike;

  _ScoredSuggestion(
    this.item,
    this.score,
    this.reasons,
    this.suggestedPortionG,
    this.isFavoriteLike,
  );
}

class _RecentPreferenceSignals {
  final Map<String, int> recentFoodCounts;
  final Map<String, int> mealTypeFoodCounts;

  const _RecentPreferenceSignals({
    required this.recentFoodCounts,
    required this.mealTypeFoodCounts,
  });
}
