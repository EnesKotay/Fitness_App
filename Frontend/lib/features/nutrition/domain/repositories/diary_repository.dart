import '../entities/food_entry.dart';
import '../entities/user_profile.dart';
import '../entities/meal_type.dart';

/// Günlük kayıt ve profil kalıcılığı.
abstract class DiaryRepository {
  Future<UserProfile?> getProfile();
  Future<void> saveProfile(UserProfile profile);

  Future<void> addEntry(FoodEntry entry);
  Future<List<FoodEntry>> getEntriesByDate(String date);
  Future<DiaryTotals> getTotalsByDate(String date);
  Future<Map<MealType, double>> getTotalsByMeal(String date);
  Future<void> deleteEntry(String entryId);

  /// Debug: tüm günlük kayıtlarını siler (sadece kReleaseMode false iken kullanılmalı).
  Future<void> clearAllEntries();

  /// Son eklenen yemeklerin ID'lerini getirir (tekilleştirilmiş).
  Future<List<String>> getRecentFoodIds(int limit);

  /// En sık yenen yemeklerin ID'lerini getirir.
  Future<List<String>> getFrequentFoodIds(int limit);
}

/// Tarih bazlı toplam: kcal + makrolar.
class DiaryTotals {
  final double totalKcal;
  final double totalProtein;
  final double totalCarb;
  final double totalFat;

  const DiaryTotals({
    this.totalKcal = 0,
    this.totalProtein = 0,
    this.totalCarb = 0,
    this.totalFat = 0,
  });
}
