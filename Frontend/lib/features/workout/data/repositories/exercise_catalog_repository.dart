import '../models/body_region.dart';
import '../models/exercise_catalog.dart';
import '../datasources/local_exercise_data.dart';

/// Antrenman kataloğu veri kaynağı. Şimdilik local; sonradan API ile değiştirilebilir.
abstract class ExerciseCatalogRepository {
  Future<List<BodyRegion>> getRegions();
  Future<List<ExerciseCatalog>> getExercisesByRegion(String regionId);
  Future<ExerciseCatalog?> getExerciseById(String id);
}

class LocalExerciseCatalogRepository implements ExerciseCatalogRepository {
  @override
  Future<List<BodyRegion>> getRegions() async {
    await Future.delayed(const Duration(milliseconds: 150));
    return List.from(LocalExerciseData.regions);
  }

  @override
  Future<List<ExerciseCatalog>> getExercisesByRegion(String regionId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return LocalExerciseData.exercises
        .where((e) => e.regionId == regionId)
        .toList();
  }

  @override
  Future<ExerciseCatalog?> getExerciseById(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      return LocalExerciseData.exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
