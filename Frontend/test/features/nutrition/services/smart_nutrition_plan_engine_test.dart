import 'package:flutter_test/flutter_test.dart';
import 'package:pusulafit/features/nutrition/domain/entities/meal_type.dart';
import 'package:pusulafit/features/nutrition/domain/entities/nutrition_preferences.dart';
import 'package:pusulafit/features/nutrition/services/smart_nutrition_plan_engine.dart';

void main() {
  group('SmartNutritionPlanEngine', () {
    const engine = SmartNutritionPlanEngine();

    SmartPlanInput input({
      SmartPlanProgress consumed = const SmartPlanProgress(
        kcal: 0,
        protein: 0,
        carb: 0,
        fat: 0,
      ),
      NutritionPreferences preferences = const NutritionPreferences(),
      Set<MealType> loggedMealTypes = const {},
      int currentHour = 8,
      Map<String, int> slotVariantIndexes = const {},
    }) {
      return SmartPlanInput(
        goalKey: 'maintain',
        targets: const SmartPlanTargets(
          kcal: 2200,
          protein: 150,
          carb: 250,
          fat: 70,
        ),
        consumed: consumed,
        preferences: preferences,
        loggedMealTypes: loggedMealTypes,
        currentHour: currentHour,
        slotVariantIndexes: slotVariantIndexes,
      );
    }

    test('returns no meals when daily targets are already met', () {
      final plan = engine.build(
        input(
          consumed: const SmartPlanProgress(
            kcal: 2220,
            protein: 152,
            carb: 260,
            fat: 74,
          ),
        ),
      );

      expect(plan.meals, isEmpty);
      expect(plan.remainingTargets.kcal, 0);
      expect(plan.remainingTargets.protein, 0);
    });

    test('keeps generated meals compatible with dietary preferences', () {
      final plan = engine.build(
        input(
          preferences: const NutritionPreferences(
            vegan: true,
            lactoseFree: true,
            glutenFree: true,
          ),
        ),
      );

      expect(plan.meals, isNotEmpty);
      final planText = plan.meals
          .map((meal) => '${meal.food} ${meal.ingredients.join(' ')}')
          .join(' ')
          .toLowerCase();

      expect(planText, isNot(contains('tavuk')));
      expect(planText, isNot(contains('yoğurt')));
      expect(planText, isNot(contains('yulaf')));
      expect(planText, isNot(contains('yumurta')));
    });

    test('slot variant index changes only the requested meal slot', () {
      final basePlan = engine.build(
        input(loggedMealTypes: const {MealType.breakfast}, currentHour: 12),
      );
      final variantPlan = engine.build(
        input(
          loggedMealTypes: const {MealType.breakfast},
          currentHour: 12,
          slotVariantIndexes: const {'lunch': 1},
        ),
      );

      final baseLunch = basePlan.meals.firstWhere(
        (meal) => meal.slotKey == 'lunch',
      );
      final variantLunch = variantPlan.meals.firstWhere(
        (meal) => meal.slotKey == 'lunch',
      );

      expect(variantLunch.food, isNot(baseLunch.food));
      expect(variantLunch.slotKey, baseLunch.slotKey);
    });

    test('handles protein deficit after calorie target without full reset', () {
      final plan = engine.build(
        input(
          consumed: const SmartPlanProgress(
            kcal: 2240,
            protein: 120,
            carb: 250,
            fat: 70,
          ),
          loggedMealTypes: const {
            MealType.breakfast,
            MealType.lunch,
            MealType.snack,
          },
          currentHour: 20,
        ),
      );

      final totalKcal = plan.meals.fold<int>(0, (sum, meal) => sum + meal.kcal);

      expect(plan.meals, hasLength(1));
      expect(plan.meals.single.mealType, MealType.dinner);
      expect(totalKcal, lessThan(450));
      expect(plan.meals.single.protein, greaterThanOrEqualTo(15));
    });
  });
}
