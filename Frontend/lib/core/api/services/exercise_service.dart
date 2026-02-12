import '../api_client.dart';
import '../api_exception.dart';
import '../../constants/api_constants.dart';
import '../../models/exercise.dart';

class ExerciseService {
  final ApiClient _apiClient = ApiClient();

  /// Tüm kas gruplarını getirir (CHEST, BACK, LEGS, ...).
  Future<List<String>> getMuscleGroups() async {
    try {
      final response = await _apiClient.get(ApiConstants.exerciseGroups);
      final List<dynamic> data = response.data as List<dynamic>;
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Bölgeler yüklenemedi');
    }
  }

  /// Belirli bir kas grubuna ait egzersizleri getirir.
  Future<List<Exercise>> getExercisesByMuscleGroup(String muscleGroup) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.exercisesByGroup(Uri.encodeComponent(muscleGroup)),
      );
      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(message: 'Egzersizler yüklenemedi');
    }
  }
}
