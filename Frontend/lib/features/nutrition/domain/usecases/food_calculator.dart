import '../entities/food_item.dart';

/// Yemek kalorisi: kcal_per_100g varsa onu kullan; yoksa 4*P+4*C+9*F (100g için sonra gram oranı).
class FoodCalculator {
  /// Gram başına kalori hesapla. Gram 0 veya negatifse 0 dön (engelle).
  static double calculateCalories(FoodItem food, double grams) {
    if (grams <= 0) return 0;
    if (food.kcalPer100g > 0) {
      return food.kcalPer100g * grams / 100;
    }
    final kcalPer100 = 4 * food.proteinPer100g + 4 * food.carbPer100g + 9 * food.fatPer100g;
    return kcalPer100 * grams / 100;
  }
}
