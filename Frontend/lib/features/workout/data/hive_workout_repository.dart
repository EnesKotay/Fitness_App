import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../../../core/models/workout.dart';
import '../../../core/utils/storage_helper.dart';

/// Antrenman kayıtlarını yerel Hive'da önbellekler.
/// API başarılı olunca tüm liste yeniden yazılır; offline'da bu cache okunur.
class HiveWorkoutRepository {
  static String get _boxName =>
      'workout_cache_${StorageHelper.getUserStorageSuffix()}';

  static Future<void> closeBoxesForSuffix(String suffix) async {
    final name = 'workout_cache_$suffix';
    try {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
    } catch (e) {
      debugPrint('HiveWorkoutRepository.closeBoxesForSuffix: $e');
    }
  }

  static Future<void> clearBoxesForSuffix(String suffix) async {
    final name = 'workout_cache_$suffix';
    try {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).clear();
      } else {
        final box = await Hive.openBox(name);
        await box.clear();
      }
    } catch (e) {
      debugPrint('HiveWorkoutRepository.clearBoxesForSuffix: $e');
    }
  }

  Future<Box<dynamic>> _getBox() async {
    if (Hive.isBoxOpen(_boxName)) return Hive.box(_boxName);
    return Hive.openBox(_boxName);
  }

  Future<List<Workout>> getAll() async {
    try {
      final box = await _getBox();
      return box.values
          .map((e) => Workout.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('HiveWorkoutRepository.getAll: $e');
      return [];
    }
  }

  /// API'den dönen tüm listeyi yazar (tam override).
  Future<void> saveAll(List<Workout> workouts) async {
    try {
      final box = await _getBox();
      await box.clear();
      final entries = {
        for (final w in workouts) w.id.toString(): w.toJson(),
      };
      await box.putAll(entries);
    } catch (e) {
      debugPrint('HiveWorkoutRepository.saveAll: $e');
    }
  }

  Future<void> put(Workout workout) async {
    try {
      final box = await _getBox();
      await box.put(workout.id.toString(), workout.toJson());
    } catch (e) {
      debugPrint('HiveWorkoutRepository.put: $e');
    }
  }

  Future<void> delete(int workoutId) async {
    try {
      final box = await _getBox();
      await box.delete(workoutId.toString());
    } catch (e) {
      debugPrint('HiveWorkoutRepository.delete: $e');
    }
  }
}
