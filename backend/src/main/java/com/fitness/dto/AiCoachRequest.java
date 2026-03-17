package com.fitness.dto;

import java.util.List;

public class AiCoachRequest {
    public String goal;
    public DailySummaryDto dailySummary;
    public String question;
    /** Optional: motivator | scientist | supportive – affects coach tone in prompt */
    public String personality;
    /** Optional: instruction for the chosen personality (e.g. "Sen sert, disiplinli bir fitness antrenörüsün...") */
    public String personalityInstruction;

    public static class DailySummaryDto {
        public Integer steps;
        public Integer calories;
        public Double waterLiters;
        public Double sleepHours;
        public Integer workouts;
        public Integer workoutMinutes;
        public List<String> workoutHighlights;

        // Phase 8: Historical Context
        public Integer avgStepsLast7Days;
        public Integer avgCaloriesLast7Days;
        public Double avgWaterLast7Days;
        public Integer targetCalories;
        public Double currentWeightKg;
        public Double targetWeightKg;
        public Double bmi;

        // Phase 9: Richer context for smarter AI
        public Integer proteinGrams;
        public Integer carbsGrams;
        public Integer fatGrams;
        public List<String> mealNames;
        public Double weeklyWeightChangeKg;
        public Integer weightStreak;
        public Integer userAge;
        public Double userHeightCm;
        public String userGender;
        public String activityLevel;
        public Integer tdee;
    }
}
