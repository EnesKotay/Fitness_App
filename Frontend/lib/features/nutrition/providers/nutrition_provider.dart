import 'package:flutter/foundation.dart';
import '../../../core/api/services/nutrition_service.dart';
import '../../../core/models/meal.dart';
import '../../../core/models/meal_models.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/api_cache.dart';

class NutritionProvider with ChangeNotifier {
  final NutritionService _nutritionService = NutritionService();
  final ApiCache _cache = ApiCache();

  // State
  List<Meal> _meals = [];
  int _dailyCalories = 0;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Meal> get meals => _meals;
  int get dailyCalories => _dailyCalories;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Yemek kayıtlarını yükle
  Future<void> loadMeals(int userId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _meals = await _nutritionService.getUserMeals(userId);
      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Yemek kayıtları yüklenemedi';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Belirli bir tarihteki yemekleri yükle (cache + retry - performans için)
  Future<void> loadMealsByDate(int userId, DateTime date, {int retryCount = 0}) async {
    final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final cacheKey = ApiCache.mealsByDateKey(userId, dateKey);

    // Stale-while-revalidate: Önce cache varsa göster
    final cached = _cache.get<List<Meal>>(cacheKey);
    if (cached != null && cached.isNotEmpty) {
      _meals = cached;
      _dailyCalories = cached.fold<int>(0, (sum, m) => sum + m.calories);
      _isLoading = true;
      notifyListeners();
    } else {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      _meals = await _nutritionService.getMealsByDate(userId, date);
      _dailyCalories = await _nutritionService.getDailyCalories(userId, date);
      _cache.set(cacheKey, _meals);
      _isLoading = false;
      _errorMessage = null;
      notifyListeners();
    } on ApiException catch (e) {
      if (retryCount == 0) {
        await Future.delayed(const Duration(milliseconds: 800));
        return loadMealsByDate(userId, date, retryCount: 1);
      }
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      if (retryCount == 0) {
        await Future.delayed(const Duration(milliseconds: 800));
        return loadMealsByDate(userId, date, retryCount: 1);
      }
      _errorMessage = 'Yemek kayıtları yüklenemedi';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Günlük kalori toplamını hesapla
  Future<void> loadDailyCalories(int userId, DateTime date) async {
    try {
      _dailyCalories = await _nutritionService.getDailyCalories(userId, date);
      notifyListeners();
    } catch (e) {
      // Hata durumunda sessizce devam et
    }
  }

  /// Yeni yemek kaydı oluştur
  Future<bool> createMeal(int userId, MealRequest request) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final meal = await _nutritionService.createMeal(userId, request);
      _meals.insert(0, meal);
      _dailyCalories += meal.calories;
      final d = meal.mealDate ?? DateTime.now();
      final dateKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      _cache.set(ApiCache.mealsByDateKey(userId, dateKey), _meals);
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Yemek kaydı oluşturulamadı';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Yemek kaydını güncelle
  Future<bool> updateMeal(
    int userId,
    int mealId,
    MealRequest request,
  ) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedMeal = await _nutritionService.updateMeal(
        userId,
        mealId,
        request,
      );
      
      final index = _meals.indexWhere((m) => m.id == mealId);
      if (index != -1) {
        final oldCalories = _meals[index].calories;
        _meals[index] = updatedMeal;
        _dailyCalories = _dailyCalories - oldCalories + updatedMeal.calories;
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Yemek kaydı güncellenemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Yemek kaydını sil
  Future<bool> deleteMeal(int userId, int mealId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final meal = _meals.firstWhere((m) => m.id == mealId);
      await _nutritionService.deleteMeal(userId, mealId);
      _meals.removeWhere((m) => m.id == mealId);
      _dailyCalories -= meal.calories; // Kalori toplamından çıkar
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Yemek kaydı silinemedi';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Hata mesajını temizle
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
