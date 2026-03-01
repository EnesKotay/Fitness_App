import 'package:flutter/foundation.dart';
import '../../domain/entities/food_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/repositories/diary_repository.dart';
import '../datasources/hive_diet_storage.dart';

class LocalDiaryRepository implements DiaryRepository {
  final HiveDietStorage _storage = HiveDietStorage();

  @override
  Future<UserProfile?> getProfile() => _storage.getProfile();

  @override
  Future<void> saveProfile(UserProfile profile) => _storage.saveProfile(profile);

  @override
  Future<void> addEntry(FoodEntry entry) async {
    try {
      final list = await _storage.getAllEntries();
      list.add(entry);
      await _storage.saveAllEntries(list);
    } catch (e) {
      debugPrint('LocalDiaryRepository.addEntry hatası: $e');
      rethrow;
    }
  }

  @override
  Future<List<FoodEntry>> getEntriesByDate(String date) async {
    try {
      final list = await _storage.getAllEntries();
      return list.where((e) => e.date == date).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } catch (e) {
      debugPrint('LocalDiaryRepository.getEntriesByDate hatası: $e');
      return [];
    }
  }

  @override
  Future<DiaryTotals> getTotalsByDate(String date) async {
    try {
      final list = await _storage.getAllEntries();
      final dayEntries = list.where((e) => e.date == date).toList();
      double kcal = 0, protein = 0, carb = 0, fat = 0;
      for (final e in dayEntries) {
        kcal += e.calculatedKcal.isNaN ? 0 : e.calculatedKcal;
        protein += e.protein.isNaN ? 0 : e.protein;
        carb += e.carb.isNaN ? 0 : e.carb;
        fat += e.fat.isNaN ? 0 : e.fat;
      }
      return DiaryTotals(
        totalKcal: kcal.isNaN || kcal.isInfinite ? 0 : kcal,
        totalProtein: protein.isNaN || protein.isInfinite ? 0 : protein,
        totalCarb: carb.isNaN || carb.isInfinite ? 0 : carb,
        totalFat: fat.isNaN || fat.isInfinite ? 0 : fat,
      );
    } catch (e) {
      debugPrint('LocalDiaryRepository.getTotalsByDate hatası: $e');
      return const DiaryTotals();
    }
  }

  @override
  Future<Map<MealType, double>> getTotalsByMeal(String date) async {
    final list = await _storage.getAllEntries();
    final dayEntries = list.where((e) => e.date == date).toList();
    final map = <MealType, double>{};
    for (final t in MealType.values) {
      map[t] = dayEntries.where((e) => e.mealType == t).fold(0.0, (s, e) => s + e.calculatedKcal);
    }
    return map;
  }

  @override
  Future<void> deleteEntry(String entryId) async {
    try {
      final list = await _storage.getAllEntries();
      list.removeWhere((e) => e.id == entryId);
      await _storage.saveAllEntries(list);
    } catch (e) {
      debugPrint('LocalDiaryRepository.deleteEntry hatası: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearAllEntries() async {
    await _storage.saveAllEntries([]);
  }

  @override
  Future<List<String>> getRecentFoodIds(int limit) => _storage.getRecentFoodIds(limit);

  @override
  Future<List<String>> getFrequentFoodIds(int limit) => _storage.getFrequentFoodIds(limit);
}
