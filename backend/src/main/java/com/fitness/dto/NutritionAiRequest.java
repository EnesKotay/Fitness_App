package com.fitness.dto;

import java.util.List;

public class NutritionAiRequest {
    public String task;
    public String message;
    public NutritionContext context;

    public static class NutritionContext {
        public String goal;
        public List<String> dietaryRestrictions;
        public String mealType;
        public List<String> availableIngredients;
        public DailySummary dailySummary;
        public String summaryText;
    }

    public static class DailySummary {
        public Integer steps;
        public Integer calories;
        public Double water;
        public Double sleep;
    }
}
