import '../entities/food_item.dart';

/// Yiyecek veri kaynağı. Şimdilik local; ileride OpenFoodFacts/USDA API eklenebilir.
abstract class FoodRepository {
  Future<List<FoodItem>> searchFoods(String query, {String? category});
  Future<FoodItem?> getFoodById(String id);
}
