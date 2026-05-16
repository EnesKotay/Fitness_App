package com.fitness.dto;

import java.util.List;

public class NutritionAiRequest {
    public String task;
    public String message;
    public NutritionContext context;
    /** Son N konuşma turu — AI'ya bağlam sağlar. */
    public List<ConversationTurn> conversationHistory;

    public static class ConversationTurn {
        public String userMessage;
        public String assistantMessage;
    }

    public static class NutritionContext {
        public String goal;
        public List<String> dietaryRestrictions;
        public String mealType;
        public List<String> availableIngredients;
        public List<CurrentPlanMeal> currentPlan;
        public DailySummary dailySummary;
        public String summaryText;

        // User profile for richer personalisation
        public Integer userAge;
        public Double userWeightKg;
        public Double userHeightCm;
        public String userGender;
        public String activityLevel;
        public Integer targetCalories;
        public Integer proteinTargetG;
    }

    public static class CurrentPlanMeal {
        public String time;
        public String label;
        public String mealType;
        public String food;
        public String macros;
    }

    public static class DailySummary {
        public Integer steps;
        public Integer calories;
        public Double water;
        public Double sleep;
    }
}
