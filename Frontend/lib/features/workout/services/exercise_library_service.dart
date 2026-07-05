import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../models/exercise_library_model.dart';

class ExerciseLibraryService {
  final ApiClient _apiClient;

  ExerciseLibraryService(this._apiClient);

  /// Get all exercises with optional filters
  Future<List<ExerciseLibrary>> getExercises({
    String language = 'tr',
    ExerciseFilter? filter,
  }) async {
    try {
      final queryParams = {'language': language, ...?filter?.toQueryParams()};

      final response = await _apiClient.dio.get(
        ApiConstants.exerciseLibrary,
        queryParameters: queryParams,
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) => ExerciseLibrary.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Egzersizler yüklenemedi: $e');
    }
  }

  /// Get exercise by ID
  Future<ExerciseLibrary?> getExerciseById(
    String id, {
    String language = 'tr',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.exerciseLibraryItem(id),
        queryParameters: {'language': language},
      );

      return ExerciseLibrary.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw Exception('Egzersiz yüklenemedi: ${e.message}');
    }
  }

  /// Search exercises by name
  Future<List<ExerciseLibrary>> searchExercises(
    String query, {
    String language = 'tr',
  }) async {
    return getExercises(
      language: language,
      filter: ExerciseFilter(search: query),
    );
  }

  /// Get exercises by category (body part)
  Future<List<ExerciseLibrary>> getExercisesByCategory(
    String category, {
    String language = 'tr',
  }) async {
    return getExercises(
      language: language,
      filter: ExerciseFilter(category: category),
    );
  }

  /// Get exercises by equipment
  Future<List<ExerciseLibrary>> getExercisesByEquipment(
    String equipment, {
    String language = 'tr',
  }) async {
    return getExercises(
      language: language,
      filter: ExerciseFilter(equipment: equipment),
    );
  }

  /// Get bodyweight exercises (no equipment)
  Future<List<ExerciseLibrary>> getBodyweightExercises({
    String language = 'tr',
  }) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.exerciseLibraryBodyweight,
        queryParameters: {'language': language},
      );

      if (response.data is List) {
        return (response.data as List)
            .map((e) => ExerciseLibrary.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Ekipmansız egzersizler yüklenemedi: $e');
    }
  }

  /// Get available categories
  Future<List<String>> getCategories() async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.exerciseLibraryCategories,
      );
      return (response.data as List).cast<String>();
    } catch (e) {
      return ExerciseCategory.all;
    }
  }

  /// Get available equipment types
  Future<List<String>> getEquipmentTypes() async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.exerciseLibraryEquipment,
      );
      return (response.data as List).cast<String>();
    } catch (e) {
      return ExerciseEquipment.all;
    }
  }
}
