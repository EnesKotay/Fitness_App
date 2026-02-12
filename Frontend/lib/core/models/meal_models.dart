// Meal Request
class MealRequest {
  final String? name;
  final String? mealType;
  final int? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final DateTime? mealDate;
  final String? notes;

  MealRequest({
    this.name,
    this.mealType,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.mealDate,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mealType': mealType,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'mealDate': mealDate?.toIso8601String(),
      'notes': notes,
    };
  }
}
