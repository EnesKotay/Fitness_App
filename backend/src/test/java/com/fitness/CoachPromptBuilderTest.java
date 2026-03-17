package com.fitness;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;

import org.junit.jupiter.api.Test;

import com.fitness.dto.AiCoachRequest;
import com.fitness.service.CoachPromptBuilder;
import com.fitness.service.CoachPromptContext;

public class CoachPromptBuilderTest {

    @Test
    void buildPromptIncludesRecoveryAndProfileContext() {
        CoachPromptBuilder builder = new CoachPromptBuilder();
        AiCoachRequest request = new AiCoachRequest();
        request.goal = "cut";
        request.question = "Bugün neye odaklanayım?";
        request.personality = "scientist";

        AiCoachRequest.DailySummaryDto summary = new AiCoachRequest.DailySummaryDto();
        summary.steps = 4200;
        summary.calories = 2350;
        summary.waterLiters = 1.2;
        summary.sleepHours = 5.5;
        summary.workouts = 1;
        summary.workoutMinutes = 48;
        summary.workoutHighlights = List.of("Push day");
        summary.avgCaloriesLast7Days = 2100;
        summary.avgStepsLast7Days = 6500;
        summary.avgWaterLast7Days = 2.0;
        summary.targetCalories = 2000;
        summary.currentWeightKg = 82.0;
        summary.targetWeightKg = 76.0;
        summary.bmi = 25.3;
        request.dailySummary = summary;

        CoachPromptContext context = new CoachPromptContext(
                "Name: Test User | Gender: MALE | Age: 29 | Height: 180.0 cm | Current weight: 82.0 kg | Target weight: 76.0 kg",
                "Sleep: 5.5 h (poor) | Hydration: 1.2 L (low) | Training load today: 1 workouts / 48 min",
                "Latest weight: 82.0 kg | Weight delta vs previous check-in: -0.4 kg | Latest waist: 87.0 cm | Latest chest: 101.0 cm",
                "- Recovery risk: sleep is below 6h, avoid prescribing maximal intensity.");

        String prompt = builder.buildPrompt(request, List.of(), context);

        assertTrue(prompt.contains("USER PROFILE:"));
        assertTrue(prompt.contains("Sleep: 5.5 h"));
        assertTrue(prompt.contains("Workout Minutes: 48"));
        assertTrue(prompt.contains("Target Calories: 2000"));
        assertTrue(prompt.contains("Current Weight: 82.0 kg"));
        assertTrue(prompt.contains("BMI: 25.3"));
        assertTrue(prompt.contains("DETERMINISTIC COACHING SIGNALS:"));
        assertTrue(prompt.contains("prioritize recovery"));
    }
}
