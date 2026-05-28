import 'package:flutter/foundation.dart';
import '../../../../core/models/meal.dart';
import '../../../../core/models/meal_models.dart';
import '../../../../core/api/services/nutrition_service.dart' as nutrition_api;
import '../../../../core/utils/storage_helper.dart';
import '../../domain/entities/food_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/repositories/diary_repository.dart';
import '../datasources/hive_diet_storage.dart';

abstract class NutritionRemoteGateway {
  Future<Meal> createMeal(int userId, MealRequest request);
  Future<List<Meal>> getMealsByDate(int userId, DateTime date);
  Future<List<Meal>> getUserMeals(int userId, {int? limit});
  Future<Meal> updateMeal(int userId, int mealId, MealRequest request);
  Future<void> deleteMeal(int userId, int mealId);
  Future<void> deleteAllMeals(int userId);
}

class NutritionRemoteGatewayImpl implements NutritionRemoteGateway {
  final nutrition_api.NutritionService _service;

  NutritionRemoteGatewayImpl([nutrition_api.NutritionService? service])
    : _service = service ?? nutrition_api.NutritionService();

  @override
  Future<Meal> createMeal(int userId, MealRequest request) =>
      _service.createMeal(userId, request);

  @override
  Future<void> deleteMeal(int userId, int mealId) =>
      _service.deleteMeal(userId, mealId);

  @override
  Future<List<Meal>> getMealsByDate(int userId, DateTime date) =>
      _service.getMealsByDate(userId, date);

  @override
  Future<List<Meal>> getUserMeals(int userId, {int? limit}) =>
      _service.getUserMeals(userId, limit: limit);

  @override
  Future<Meal> updateMeal(int userId, int mealId, MealRequest request) =>
      _service.updateMeal(userId, mealId, request);

  @override
  Future<void> deleteAllMeals(int userId) => _service.deleteAllMeals(userId);
}

class LocalDiaryRepository implements DiaryRepository {
  final HiveDietStorage _storage;
  final NutritionRemoteGateway _remote;
  final int? _userIdOverride;
  final String? _tokenOverride;
  static const String _remoteIdPrefix = 'api_';
  static const String _metaPrefix = '__app_meta__:';
  static const Duration _entriesCacheTtl = Duration(seconds: 20);
  static const Duration _userMealsCacheTtl = Duration(seconds: 60);
  final Map<String, _DayEntriesCache> _entriesCache = {};
  final Map<String, Future<List<FoodEntry>>> _entriesInFlight = {};

  // Dedup: /api/nutrition/me/meals paralel çağrılarını tek isteğe indirir
  Future<List<Meal>>? _userMealsInFlight;
  List<Meal>? _userMealsCache;
  DateTime? _userMealsCachedAt;

  LocalDiaryRepository({
    HiveDietStorage? storage,
    NutritionRemoteGateway? remote,
    int? userIdOverride,
    String? tokenOverride,
  }) : _storage = storage ?? HiveDietStorage(),
       _remote = remote ?? NutritionRemoteGatewayImpl(),
       _userIdOverride = userIdOverride,
       _tokenOverride = tokenOverride;

  @override
  Future<UserProfile?> getProfile() => _storage.getProfile();

  @override
  Future<void> saveProfile(UserProfile profile) =>
      _storage.saveProfile(profile);

  @override
  Future<void> addEntry(FoodEntry entry) async {
    if (_canUseRemote) {
      try {
        final created = await _remote.createMeal(
          _userId,
          _toMealRequest(entry),
        );
        final createdEntry = _fromMeal(created);
        await _upsertLocal(createdEntry);
        _invalidateDate(createdEntry.date);
        return;
      } catch (e) {
        debugPrint('LocalDiaryRepository.addEntry remote fallback: $e');
      }
    }
    try {
      final list = await _storage.getAllEntries();
      list.add(entry);
      await _storage.saveAllEntries(list);
      _invalidateDate(entry.date);
    } catch (e) {
      debugPrint('LocalDiaryRepository.addEntry hatası: $e');
      rethrow;
    }
  }

  @override
  Future<List<FoodEntry>> getEntriesByDate(String date) async {
    final cached = _freshCachedEntries(date);
    if (cached != null) return cached;

    final inFlight = _entriesInFlight[date];
    if (inFlight != null) return inFlight;

    final request = _fetchEntriesByDate(date);
    _entriesInFlight[date] = request;
    try {
      return await request;
    } finally {
      if (identical(_entriesInFlight[date], request)) {
        _entriesInFlight.remove(date);
      }
    }
  }

  Future<List<FoodEntry>> _fetchEntriesByDate(String date) async {
    if (_canUseRemote) {
      try {
        final parsedDate = DateTime.tryParse(date);
        if (parsedDate != null) {
          await _syncUnsyncedLocalEntriesForDate(date);
          final meals = await _remote.getMealsByDate(_userId, parsedDate);
          final entries = meals.map(_fromMeal).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          await _replaceLocalDay(date, entries);
          final merged = await _storage.getAllEntries();
          final dayEntries = merged.where((e) => e.date == date).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _rememberEntries(date, dayEntries);
          return List<FoodEntry>.of(dayEntries);
        }
      } catch (e) {
        debugPrint('LocalDiaryRepository.getEntriesByDate remote fallback: $e');
      }
    }
    try {
      final list = await _storage.getAllEntries();
      final dayEntries = list.where((e) => e.date == date).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _rememberEntries(date, dayEntries);
      return List<FoodEntry>.of(dayEntries);
    } catch (e) {
      debugPrint('LocalDiaryRepository.getEntriesByDate hatası: $e');
      return [];
    }
  }

  @override
  Future<DiaryTotals> getTotalsByDate(String date) async {
    try {
      final dayEntries = await getEntriesByDate(date);
      return _totalsFromEntries(dayEntries);
    } catch (e) {
      debugPrint('LocalDiaryRepository.getTotalsByDate hatası: $e');
      return const DiaryTotals();
    }
  }

  @override
  Future<Map<MealType, double>> getTotalsByMeal(String date) async {
    final dayEntries = await getEntriesByDate(date);
    final map = <MealType, double>{};
    for (final t in MealType.values) {
      map[t] = dayEntries
          .where((e) => e.mealType == t)
          .fold(0.0, (s, e) => s + e.calculatedKcal);
    }
    return map;
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    String? removedDate;
    if (_canUseRemote) {
      final remoteId = _parseRemoteId(entryId);
      if (remoteId != null) {
        try {
          await _remote.deleteMeal(_userId, remoteId);
        } catch (e) {
          // API id'li kayıtta silme başarısızsa local'i silmeyip tutarlılığı koru.
          debugPrint('LocalDiaryRepository.deleteEntry remote failed: $e');
          rethrow;
        }
      }
    }
    try {
      final list = await _storage.getAllEntries();
      for (final entry in list) {
        if (entry.id == entryId) {
          removedDate = entry.date;
          break;
        }
      }
      list.removeWhere((e) => e.id == entryId);
      await _storage.saveAllEntries(list);
      if (removedDate != null) _invalidateDate(removedDate);
    } catch (e) {
      debugPrint('LocalDiaryRepository.deleteEntry hatası: $e');
      rethrow;
    }
  }

  @override
  Future<void> updateEntry(FoodEntry entry) async {
    if (_canUseRemote) {
      final remoteId = _parseRemoteId(entry.id);
      if (remoteId != null) {
        try {
          final updated = await _remote.updateMeal(
            _userId,
            remoteId,
            _toMealRequest(entry),
          );
          final updatedEntry = _fromMeal(updated);
          await _upsertLocal(updatedEntry);
          _invalidateDate(updatedEntry.date);
          return;
        } catch (e) {
          debugPrint('LocalDiaryRepository.updateEntry remote failed: $e');
          rethrow;
        }
      } else {
        // Offline eklenmiş local kayıt online iken düzenlenirse remote'a çıkar.
        try {
          final created = await _remote.createMeal(
            _userId,
            _toMealRequest(entry),
          );
          final createdEntry = _fromMeal(created);
          final list = await _storage.getAllEntries();
          FoodEntry? oldEntry;
          for (final localEntry in list) {
            if (localEntry.id == entry.id) {
              oldEntry = localEntry;
              break;
            }
          }
          list.removeWhere((e) => e.id == entry.id);
          list.add(createdEntry);
          await _storage.saveAllEntries(list);
          if (oldEntry != null) _invalidateDate(oldEntry.date);
          _invalidateDate(createdEntry.date);
          return;
        } catch (e) {
          debugPrint(
            'LocalDiaryRepository.updateEntry remote create failed: $e',
          );
        }
      }
    }
    try {
      final list = await _storage.getAllEntries();
      final index = list.indexWhere((e) => e.id == entry.id);
      if (index == -1) {
        throw StateError('Entry not found: ${entry.id}');
      }
      list[index] = entry;
      await _storage.saveAllEntries(list);
      _invalidateDate(entry.date);
    } catch (e) {
      debugPrint('LocalDiaryRepository.updateEntry hatası: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAllEntries() async {
    if (_canUseRemote) {
      try {
        await _remote.deleteAllMeals(_userId);
      } catch (e) {
        debugPrint('LocalDiaryRepository.clearAllEntries remote failed: $e');
        rethrow;
      }
    }
    await _storage.saveAllEntries([]);
    _entriesCache.clear();
    _entriesInFlight.clear();
  }

  /// Tek HTTP isteğiyle dönen meals listesi; paralel çağrılarda dedup yapar.
  Future<List<Meal>> _fetchUserMeals() {
    final now = DateTime.now();
    final cached = _userMealsCache;
    final cachedAt = _userMealsCachedAt;
    if (cached != null &&
        cachedAt != null &&
        now.difference(cachedAt) < _userMealsCacheTtl) {
      return Future.value(cached);
    }
    _userMealsInFlight ??= _remote.getUserMeals(_userId, limit: 240).then((meals) {
      _userMealsCache = meals;
      _userMealsCachedAt = DateTime.now();
      _userMealsInFlight = null;
      return meals;
    }, onError: (e) {
      _userMealsInFlight = null;
      throw e;
    });
    return _userMealsInFlight!;
  }

  @override
  Future<List<String>> getRecentFoodIds(int limit) async {
    if (_canUseRemote) {
      try {
        final meals = await _fetchUserMeals();
        final seen = <String>{};
        final result = <String>[];
        for (final meal in meals) {
          final foodId = _extractFoodId(meal);
          if (foodId.isEmpty || seen.contains(foodId)) continue;
          seen.add(foodId);
          result.add(foodId);
          if (result.length >= limit) break;
        }
        if (result.isNotEmpty) return result;
      } catch (e) {
        debugPrint('LocalDiaryRepository.getRecentFoodIds remote fallback: $e');
      }
    }
    return _storage.getRecentFoodIds(limit);
  }

  @override
  Future<List<String>> getFrequentFoodIds(int limit) async {
    if (_canUseRemote) {
      try {
        final meals = await _fetchUserMeals();
        final counts = <String, int>{};
        for (final meal in meals) {
          final foodId = _extractFoodId(meal);
          if (foodId.isEmpty) continue;
          counts[foodId] = (counts[foodId] ?? 0) + 1;
        }
        if (counts.isNotEmpty) {
          final sorted = counts.keys.toList()
            ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
          return sorted.take(limit).toList();
        }
      } catch (e) {
        debugPrint(
          'LocalDiaryRepository.getFrequentFoodIds remote fallback: $e',
        );
      }
    }
    return _storage.getFrequentFoodIds(limit);
  }

  bool get _canUseRemote {
    final token = _tokenOverride ?? StorageHelper.getToken();
    return token != null &&
        token.isNotEmpty &&
        (_userIdOverride ?? StorageHelper.getUserId()) != null;
  }

  @override
  Future<int> getCurrentStreak() async {
    try {
      final all = await _storage.getAllEntries();
      if (all.isEmpty) return 0;

      // Get unique dates
      final uniqueDates = all.map((e) => e.date).toSet().toList();
      uniqueDates.sort((a, b) => b.compareTo(a)); // Descending

      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T').first;
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayStr = yesterday.toIso8601String().split('T').first;

      if (!uniqueDates.contains(todayStr) &&
          !uniqueDates.contains(yesterdayStr)) {
        return 0; // Eğer bugün veya dün giriş yoksa seri 0'dır
      }

      int streak = 0;
      DateTime currentDate = uniqueDates.contains(todayStr) ? today : yesterday;

      while (true) {
        final currentStr = currentDate.toIso8601String().split('T').first;
        if (uniqueDates.contains(currentStr)) {
          streak++;
          currentDate = currentDate.subtract(const Duration(days: 1));
        } else {
          break; // Zincir koptu
        }
      }

      return streak;
    } catch (_) {
      return 0;
    }
  }

  int get _userId => _userIdOverride ?? StorageHelper.getUserId() ?? 0;

  MealType _mealTypeFromApi(String value) {
    switch (value.toUpperCase()) {
      case 'BREAKFAST':
        return MealType.breakfast;
      case 'LUNCH':
        return MealType.lunch;
      case 'DINNER':
        return MealType.dinner;
      case 'SNACK':
      default:
        return MealType.snack;
    }
  }

  String _mealTypeToApi(MealType value) {
    switch (value) {
      case MealType.breakfast:
        return 'BREAKFAST';
      case MealType.lunch:
        return 'LUNCH';
      case MealType.dinner:
        return 'DINNER';
      case MealType.snack:
        return 'SNACK';
    }
  }

  MealRequest _toMealRequest(FoodEntry entry) {
    final parsedDay = DateTime.tryParse(entry.date);
    final mealDate = parsedDay != null
        ? DateTime(
            parsedDay.year,
            parsedDay.month,
            parsedDay.day,
            entry.createdAt.hour,
            entry.createdAt.minute,
            entry.createdAt.second,
          )
        : entry.createdAt;

    return MealRequest(
      name: entry.foodName,
      mealType: _mealTypeToApi(entry.mealType),
      calories: entry.calculatedKcal.round(),
      protein: entry.protein,
      carbs: entry.carb,
      fat: entry.fat,
      mealDate: mealDate,
      notes: _encodeMeta(entry.foodId, entry.grams),
    );
  }

  FoodEntry _fromMeal(Meal meal) {
    final meta = _decodeMeta(meal.notes);
    final grams = meta?.grams ?? 100.0;
    final mealDate = meal.createdAt ?? meal.mealDate;
    return FoodEntry(
      id: '$_remoteIdPrefix${meal.id}',
      date: meal.mealDate.toIso8601String().split('T').first,
      mealType: _mealTypeFromApi(meal.mealType),
      foodId: meta?.foodId ?? _fallbackFoodId(meal),
      foodName: meal.name,
      grams: grams,
      calculatedKcal: meal.calories.toDouble(),
      protein: meal.protein ?? 0,
      carb: meal.carbs ?? 0,
      fat: meal.fat ?? 0,
      createdAt: mealDate,
    );
  }

  String _fallbackFoodId(Meal meal) => 'meal_${meal.id}';

  String _extractFoodId(Meal meal) =>
      _decodeMeta(meal.notes)?.foodId ?? _fallbackFoodId(meal);

  String _encodeMeta(String foodId, double grams) {
    final safeFoodId = foodId.trim().isEmpty ? 'unknown' : foodId.trim();
    final safeGrams = grams.isFinite ? grams : 100.0;
    return '$_metaPrefix$safeFoodId|${safeGrams.toStringAsFixed(2)}';
  }

  _EntryMeta? _decodeMeta(String? notes) {
    if (notes == null || !notes.startsWith(_metaPrefix)) return null;
    final payload = notes.substring(_metaPrefix.length);
    final parts = payload.split('|');
    if (parts.isEmpty) return null;
    final foodId = parts.first.trim();
    if (foodId.isEmpty) return null;
    final grams = parts.length > 1 ? double.tryParse(parts[1]) : null;
    return _EntryMeta(foodId: foodId, grams: grams ?? 100.0);
  }

  int? _parseRemoteId(String entryId) {
    if (!entryId.startsWith(_remoteIdPrefix)) return null;
    final raw = entryId.substring(_remoteIdPrefix.length);
    return int.tryParse(raw);
  }

  DiaryTotals _totalsFromEntries(List<FoodEntry> entries) {
    double kcal = 0;
    double protein = 0;
    double carb = 0;
    double fat = 0;
    double fiber = 0;
    double sugar = 0;
    for (final e in entries) {
      kcal += e.calculatedKcal.isNaN ? 0 : e.calculatedKcal;
      protein += e.protein.isNaN ? 0 : e.protein;
      carb += e.carb.isNaN ? 0 : e.carb;
      fat += e.fat.isNaN ? 0 : e.fat;
      fiber += e.fiber.isNaN ? 0 : e.fiber;
      sugar += e.sugar.isNaN ? 0 : e.sugar;
    }
    return DiaryTotals(
      totalKcal: kcal.isNaN || kcal.isInfinite ? 0 : kcal,
      totalProtein: protein.isNaN || protein.isInfinite ? 0 : protein,
      totalCarb: carb.isNaN || carb.isInfinite ? 0 : carb,
      totalFat: fat.isNaN || fat.isInfinite ? 0 : fat,
      totalFiber: fiber.isNaN || fiber.isInfinite ? 0 : fiber,
      totalSugar: sugar.isNaN || sugar.isInfinite ? 0 : sugar,
    );
  }

  Future<void> _upsertLocal(FoodEntry entry) async {
    final list = await _storage.getAllEntries();
    final idx = list.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      list[idx] = entry;
    } else {
      list.add(entry);
    }
    await _storage.saveAllEntries(list);
  }

  Future<void> _replaceLocalDay(
    String day,
    List<FoodEntry> remoteDayEntries,
  ) async {
    final all = await _storage.getAllEntries();
    all.removeWhere((e) => e.date == day && _parseRemoteId(e.id) != null);
    all.addAll(remoteDayEntries);
    await _storage.saveAllEntries(all);
  }

  Future<void> _syncUnsyncedLocalEntriesForDate(String date) async {
    final all = await _storage.getAllEntries();
    final unsynced = all
        .where((e) => e.date == date && _parseRemoteId(e.id) == null)
        .toList();
    if (unsynced.isEmpty) return;

    var changed = false;
    for (final local in unsynced) {
      try {
        final created = await _remote.createMeal(
          _userId,
          _toMealRequest(local),
        );
        final synced = _fromMeal(created);
        final idx = all.indexWhere((e) => e.id == local.id);
        if (idx >= 0) {
          all[idx] = synced;
          changed = true;
        }
      } catch (e) {
        // Bir kayıt upload edilemezse diğerlerini denemeye devam et.
        debugPrint('LocalDiaryRepository.sync unsynced entry failed: $e');
      }
    }
    if (changed) {
      await _storage.saveAllEntries(all);
    }
  }

  List<FoodEntry>? _freshCachedEntries(String date) {
    final cached = _entriesCache[date];
    if (cached == null) return null;
    if (DateTime.now().difference(cached.savedAt) > _entriesCacheTtl) {
      _entriesCache.remove(date);
      return null;
    }
    return List<FoodEntry>.of(cached.entries);
  }

  void _rememberEntries(String date, List<FoodEntry> entries) {
    _entriesCache[date] = _DayEntriesCache(
      savedAt: DateTime.now(),
      entries: List<FoodEntry>.of(entries),
    );
  }

  void _invalidateDate(String date) {
    _entriesCache.remove(date);
    _entriesInFlight.remove(date);
  }
}

class _DayEntriesCache {
  final DateTime savedAt;
  final List<FoodEntry> entries;

  const _DayEntriesCache({required this.savedAt, required this.entries});
}

class _EntryMeta {
  final String foodId;
  final double grams;

  const _EntryMeta({required this.foodId, required this.grams});
}
