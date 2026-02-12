import '../api_client.dart';
import '../api_exception.dart';
import '../../constants/api_constants.dart';
import '../../models/meal.dart';
import '../../models/meal_models.dart';

class NutritionService {
  final ApiClient _apiClient = ApiClient();

  /// Yeni yemek kaydı oluştur
  Future<Meal> createMeal(int userId, MealRequest request) async {
    try {
      final response = await _apiClient.post(
        ApiConstants.meals(userId),
        data: request.toJson(),
      );

      return Meal.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Yemek kaydı oluşturulamadı');
    }
  }

  /// Kullanıcının tüm yemek kayıtlarını getir
  Future<List<Meal>> getUserMeals(int userId) async {
    try {
      final response = await _apiClient.get(ApiConstants.meals(userId));

      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => Meal.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Yemek kayıtları alınamadı');
    }
  }

  /// Belirli bir tarihteki yemekleri getir
  Future<List<Meal>> getMealsByDate(int userId, DateTime date) async {
    try {
      final dateString = date.toIso8601String().split(
        'T',
      )[0]; // YYYY-MM-DD formatı
      final response = await _apiClient.get(
        ApiConstants.mealsByDate(userId),
        queryParameters: {'date': dateString},
      );

      final List<dynamic> data = response.data as List<dynamic>;
      return data
          .map((json) => Meal.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Yemek kayıtları alınamadı');
    }
  }

  /// Günlük kalori toplamını hesapla
  Future<int> getDailyCalories(int userId, DateTime date) async {
    try {
      final dateString = date.toIso8601String().split(
        'T',
      )[0]; // YYYY-MM-DD formatı
      final response = await _apiClient.get(
        ApiConstants.dailyCalories(userId),
        queryParameters: {'date': dateString},
      );

      final data = response.data as Map<String, dynamic>;
      return data['totalCalories'] as int;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Kalori bilgisi alınamadı');
    }
  }

  /// Yemek kaydını güncelle
  Future<Meal> updateMeal(int userId, int mealId, MealRequest request) async {
    try {
      final response = await _apiClient.put(
        ApiConstants.meal(userId, mealId),
        data: request.toJson(),
      );

      return Meal.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Yemek kaydı güncellenemedi');
    }
  }

  /// Yemek kaydını sil
  Future<void> deleteMeal(int userId, int mealId) async {
    try {
      await _apiClient.delete(ApiConstants.meal(userId, mealId));
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }
      throw ApiException(message: 'Yemek kaydı silinemedi');
    }
  }
}
