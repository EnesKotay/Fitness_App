import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../domain/entities/weight_entry.dart';
import '../../domain/repositories/weight_repository.dart';

/// Kilo kayıtları yerel Hive'da. Her kullanıcı (userId) kendi box'ında saklanır.
class HiveWeightRepository implements WeightRepository {
  static String get _boxName => 'weight_entries_${StorageHelper.getUserStorageSuffix()}';

  /// Hesap değişince eski kullanıcının kilo box'ını kapat.
  static Future<void> closeBoxesForSuffix(String suffix) async {
    final name = 'weight_entries_$suffix';
    try {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
        debugPrint('HiveWeightRepository: closed box $name');
      }
    } catch (e) {
      debugPrint('HiveWeightRepository.closeBoxesForSuffix: $e');
    }
  }

  Future<Box<dynamic>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) {
      return Hive.box(_boxName);
    }
    return await Hive.openBox(_boxName);
  }

  @override
  Future<List<WeightEntry>> getEntries() async {
    final box = await _getBox();
    final list = box.values
        .map((e) => WeightEntry.fromJson(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<void> addEntry(WeightEntry entry) async {
    final box = await _getBox();
    await box.put(entry.id, entry.toJson());
  }

  @override
  Future<void> deleteEntry(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  @override
  Future<void> updateEntry(WeightEntry entry) async {
    final box = await _getBox();
    await box.put(entry.id, entry.toJson());
  }
}
