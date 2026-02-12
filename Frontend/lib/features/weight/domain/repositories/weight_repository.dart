import '../entities/weight_entry.dart';

abstract class WeightRepository {
  Future<List<WeightEntry>> getEntries();
  Future<void> addEntry(WeightEntry entry);
  Future<void> deleteEntry(String id);
  Future<void> updateEntry(WeightEntry entry);
}
