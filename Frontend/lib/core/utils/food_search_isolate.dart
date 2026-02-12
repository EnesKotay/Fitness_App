import '../models/food.dart';
import '../data/food_database.dart';

/// Top-level fonksiyon - compute() ile isolate'te çalışır (UI thread bloklamaz)
List<Food> searchFoodsInIsolate(String query) {
  return FoodDatabase.search(query);
}
