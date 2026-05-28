import '../domain/entities/meal_type.dart';
import '../domain/entities/planned_meal.dart';
import '../models/nutrition_ai_response.dart';

class AiCustomizedPlanMapper {
  const AiCustomizedPlanMapper._();

  static List<PlannedMeal> toPlannedMeals(
    List<CustomizedDailyPlanMealModel> dailyPlan,
  ) {
    return dailyPlan
        .where((meal) => meal.food.trim().isNotEmpty)
        .map(_toPlannedMeal)
        .toList();
  }

  static MealType mealTypeFromAiPlanMeal(CustomizedDailyPlanMealModel meal) {
    switch (meal.mealType.trim().toUpperCase()) {
      case 'BREAKFAST':
        return MealType.breakfast;
      case 'LUNCH':
        return MealType.lunch;
      case 'DINNER':
        return MealType.dinner;
      case 'SNACK':
        return MealType.snack;
      default:
        final lowerLabel = meal.label.toLowerCase();
        if (lowerLabel.contains('kahvalt')) {
          return MealType.breakfast;
        }
        if (lowerLabel.contains('öğle') || lowerLabel.contains('ogle')) {
          return MealType.lunch;
        }
        if (lowerLabel.contains('akşam') || lowerLabel.contains('aksam')) {
          return MealType.dinner;
        }
        return MealType.snack;
    }
  }

  static PlannedMeal _toPlannedMeal(CustomizedDailyPlanMealModel meal) {
    final mealType = mealTypeFromAiPlanMeal(meal);
    return PlannedMeal(
      name: meal.food,
      kcal: meal.kcal,
      portionGrams: _defaultGuidePortion(mealType),
      mealType: mealType,
      ingredients: meal.ingredients.isNotEmpty
          ? meal.ingredients
          : meal.food
                .split(RegExp(r'\+|/| ve | veya |,'))
                .map((item) => item.trim())
                .where((item) => item.isNotEmpty)
                .toList(),
    );
  }

  static double _defaultGuidePortion(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 120;
      case MealType.lunch:
      case MealType.dinner:
        return 180;
      case MealType.snack:
        return 80;
    }
  }
}
