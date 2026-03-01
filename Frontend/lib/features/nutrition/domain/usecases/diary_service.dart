import '../entities/food_entry.dart';
import '../entities/meal_type.dart';
import '../repositories/diary_repository.dart';

/// Günlük ekleme, tarih bazlı listeleme ve toplamlar. Tarih yyyy-MM-dd normalize.
class DiaryService {
  final DiaryRepository _repo;

  DiaryService(this._repo);

  static String normalizeDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> addEntry(FoodEntry entry) => _repo.addEntry(entry);

  Future<List<FoodEntry>> getEntriesByDate(DateTime date) {
    return _repo.getEntriesByDate(normalizeDate(date));
  }

  Future<DiaryTotals> getTotalsByDate(DateTime date) {
    return _repo.getTotalsByDate(normalizeDate(date));
  }

  Future<Map<MealType, double>> getTotalsByMeal(DateTime date) {
    return _repo.getTotalsByMeal(normalizeDate(date));
  }

  Future<void> deleteEntry(String entryId) => _repo.deleteEntry(entryId);

  Future<void> clearAllEntries() => _repo.clearAllEntries();
}
