import '../api_client.dart';
import '../api_exception.dart';
import '../../constants/api_constants.dart';
import '../../models/workout.dart';
import '../../models/workout_models.dart';

class WorkoutService {
  final ApiClient _apiClient = ApiClient();

  /// Yeni antrenman kaydı oluştur
  Future<Workout> createWorkout(int userId, WorkoutRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.workouts(userId),
        data: request.toJson(),
      );

      return Workout.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Antrenman kaydı oluşturulamadı');
    }
  }

  /// Kullanıcının tüm antrenmanlarını getir
  Future<List<Workout>> getUserWorkouts(int userId) async {
    try {
      final response = await _apiClient.get(ApiConstants.workouts(userId));

      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => Workout.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Antrenmanlar alınamadı');
    }
  }

  /// Belirli bir antrenmanı getir
  Future<Workout> getWorkoutById(int userId, int workoutId) async {
    try {
      final response = await _apiClient.get(
        ApiConstants.workout(userId, workoutId),
      );

      return Workout.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Antrenman bilgisi alınamadı');
    }
  }

  /// Antrenman kaydını güncelle
  Future<Workout> updateWorkout(
    int userId,
    int workoutId,
    WorkoutRequest request,
  ) async {
    try {
      final response = await _apiClient.put(
        ApiConstants.workout(userId, workoutId),
        data: request.toJson(),
      );

      return Workout.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Antrenman kaydı güncellenemedi');
    }
  }

  /// Antrenman kaydını sil
  Future<void> deleteWorkout(int userId, int workoutId) async {
    try {
      await _apiClient.delete(ApiConstants.workout(userId, workoutId));
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Antrenman kaydı silinemedi');
    }
  }
}
