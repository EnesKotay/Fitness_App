package com.fitness;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.fitness.dto.NutritionAiResponse;
import com.fitness.service.NutritionPlanCustomizationNormalizer;

public class NutritionPlanCustomizationNormalizerTest {

    private final NutritionPlanCustomizationNormalizer normalizer = new NutritionPlanCustomizationNormalizer();

    @Test
    void normalizesOrderDefaultsAndDuplicateSnacks() {
        NutritionAiResponse.DailyPlanMeal snackOne = meal("", "Ara Öğün", "SNACK", "Yulaf bar", 150);
        NutritionAiResponse.DailyPlanMeal breakfast = meal("08:30", "", "BREAKFAST", "Yulaf + yumurta", 430);
        NutritionAiResponse.DailyPlanMeal dinner = meal("19:30", "Akşam", "DINNER", "Somon + pilav", 620);
        NutritionAiResponse.DailyPlanMeal lunch = meal("13:15", "Öğle", "LUNCH", "Tavuk + makarna", 580);
        NutritionAiResponse.DailyPlanMeal snackTwo = meal("17:00", "", "SNACK", "Yoğurt", 120);

        List<NutritionAiResponse.DailyPlanMeal> normalized = normalizer.normalize(
                List.of(snackOne, dinner, breakfast, snackTwo, lunch));

        assertEquals(4, normalized.size());
        assertEquals("BREAKFAST", normalized.get(0).mealType);
        assertEquals("Kahvaltı", normalized.get(0).label);
        assertEquals("08:30", normalized.get(0).time);

        assertEquals("LUNCH", normalized.get(1).mealType);
        assertEquals("DINNER", normalized.get(2).mealType);

        assertEquals("SNACK", normalized.get(3).mealType);
        assertEquals("16:30", normalized.get(3).time);
        assertEquals("Yulaf bar • Yoğurt", normalized.get(3).food);
        assertEquals(270, normalized.get(3).macros.kcal);
    }

    @Test
    void infersMealTypeFromLabelAndFallsBackToSnack() {
        NutritionAiResponse.DailyPlanMeal inferredLunch = meal("12:45", "Öğle Menüsü", "", "Mercimek çorbası", 280);
        NutritionAiResponse.DailyPlanMeal fallbackSnack = meal("", "", "", "Muz", 90);

        List<NutritionAiResponse.DailyPlanMeal> normalized = normalizer.normalize(
                List.of(fallbackSnack, inferredLunch));

        assertEquals(2, normalized.size());
        assertEquals("LUNCH", normalized.get(0).mealType);
        assertEquals("SNACK", normalized.get(1).mealType);
        assertEquals("16:30", normalized.get(1).time);
        assertEquals("Ara Öğün", normalized.get(1).label);
    }

    private NutritionAiResponse.DailyPlanMeal meal(
            String time,
            String label,
            String mealType,
            String food,
            int kcal) {
        NutritionAiResponse.DailyPlanMeal meal = new NutritionAiResponse.DailyPlanMeal();
        meal.time = time;
        meal.label = label;
        meal.mealType = mealType;
        meal.food = food;
        meal.macros = new NutritionAiResponse.MealMacros();
        meal.macros.kcal = kcal;
        return meal;
    }
}
