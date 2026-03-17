import 'meal_type.dart';

class PlannedMeal {
  final String name;
  final int kcal;
  final double portionGrams;
  final MealType mealType;
  final String? foodId;
  final String category;
  final List<String> ingredients;

  const PlannedMeal({
    required this.name,
    required this.kcal,
    required this.portionGrams,
    required this.mealType,
    this.foodId,
    this.category = '',
    this.ingredients = const [],
  });

  factory PlannedMeal.fromJson(Map<String, dynamic> json) {
    final mealTypeName = (json['mealType'] as String?)?.trim();
    final parsedMealType = MealType.values.where((type) {
      return type.name == mealTypeName;
    });
    return PlannedMeal(
      name: (json['name'] as String?)?.trim() ?? '',
      kcal: (json['kcal'] as num?)?.round() ?? 0,
      portionGrams: (json['portionGrams'] as num?)?.toDouble() ?? 0,
      mealType: parsedMealType.isNotEmpty
          ? parsedMealType.first
          : MealType.snack,
      foodId: (json['foodId'] as String?)?.trim(),
      category: (json['category'] as String?)?.trim() ?? '',
      ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'kcal': kcal,
      'portionGrams': portionGrams,
      'mealType': mealType.name,
      'foodId': foodId,
      'category': category,
      'ingredients': ingredients,
    };
  }

  PlannedMeal copyWith({
    String? name,
    int? kcal,
    double? portionGrams,
    MealType? mealType,
    String? foodId,
    String? category,
    List<String>? ingredients,
    bool clearFoodId = false,
  }) {
    return PlannedMeal(
      name: name ?? this.name,
      kcal: kcal ?? this.kcal,
      portionGrams: portionGrams ?? this.portionGrams,
      mealType: mealType ?? this.mealType,
      foodId: clearFoodId ? null : (foodId ?? this.foodId),
      category: category ?? this.category,
      ingredients: ingredients ?? this.ingredients,
    );
  }
}
