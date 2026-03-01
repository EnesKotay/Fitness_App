package com.fitness.dto;

import java.util.List;

public class NutritionAiResponse {
    public String reply;
    public List<SuggestedMeal> meals;
    public List<String> shoppingList;
    public List<String> followUpQuestions;
    public Integer retryAfterSeconds;

    // Backwards compatibility - maps suggestedMeals to meals
    public List<SuggestedMeal> getSuggestedMeals() {
        return meals;
    }

    public void setSuggestedMeals(List<SuggestedMeal> meals) {
        this.meals = meals;
    }

    public static class SuggestedMeal {
        public String name;
        public String reason;
        public List<String> ingredients;
        public List<String> steps;
        public MealMacros macros;
        public Integer prepMinutes;
        public List<String> tags;
        public List<String> warnings;

        // Backwards compatibility
        public Integer getEstimatedCalories() {
            return macros != null ? macros.kcal : null;
        }
    }

    public static class MealMacros {
        public Integer kcal;
        public Integer proteinG;
        public Integer carbsG;
        public Integer fatG;
    }
}
