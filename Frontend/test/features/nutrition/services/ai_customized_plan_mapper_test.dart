import 'package:flutter_test/flutter_test.dart';
import 'package:pusulafit/features/nutrition/domain/entities/meal_type.dart';
import 'package:pusulafit/features/nutrition/models/nutrition_ai_response.dart';
import 'package:pusulafit/features/nutrition/services/ai_customized_plan_mapper.dart';

void main() {
  group('AiCustomizedPlanMapper', () {
    test('keeps duplicate snacks as separate planned meals', () {
      final meals = [
        CustomizedDailyPlanMealModel(
          time: '08:00',
          label: 'Kahvaltı',
          mealType: 'BREAKFAST',
          food: 'Yulaf ve yumurta',
          reason: '',
          ingredients: const ['Yulaf', 'Yumurta'],
          macros: MealMacrosModel(
            kcal: 420,
            proteinG: 28,
            carbsG: 38,
            fatG: 12,
          ),
        ),
        CustomizedDailyPlanMealModel(
          time: '16:00',
          label: 'Ara Öğün',
          mealType: 'SNACK',
          food: 'Yoğurt',
          reason: '',
          ingredients: const ['Yoğurt'],
          macros: MealMacrosModel(kcal: 120, proteinG: 10, carbsG: 8, fatG: 4),
        ),
        CustomizedDailyPlanMealModel(
          time: '17:30',
          label: 'Ara Öğün',
          mealType: 'SNACK',
          food: 'Muz',
          reason: '',
          ingredients: const ['Muz'],
          macros: MealMacrosModel(kcal: 90, proteinG: 1, carbsG: 22, fatG: 0),
        ),
      ];

      final plannedMeals = AiCustomizedPlanMapper.toPlannedMeals(meals);

      expect(plannedMeals, hasLength(3));
      expect(plannedMeals.first.mealType, MealType.breakfast);
      expect(plannedMeals[1].mealType, MealType.snack);
      expect(plannedMeals[1].name, 'Yoğurt');
      expect(plannedMeals[2].mealType, MealType.snack);
      expect(plannedMeals[2].name, 'Muz');
    });

    test('infers meal type from label when token is missing', () {
      final meals = [
        CustomizedDailyPlanMealModel(
          time: '12:30',
          label: 'Öğle',
          mealType: '',
          food: 'Tavuklu salata',
          reason: '',
          ingredients: const ['Tavuk', 'Salata'],
          macros: MealMacrosModel(
            kcal: 360,
            proteinG: 32,
            carbsG: 14,
            fatG: 12,
          ),
        ),
      ];

      final plannedMeals = AiCustomizedPlanMapper.toPlannedMeals(meals);

      expect(plannedMeals, hasLength(1));
      expect(plannedMeals.single.mealType, MealType.lunch);
      expect(plannedMeals.single.portionGrams, 180);
    });
  });
}
