package com.fitness.dto;

import java.util.List;

/**
 * Result of analyzing a food/meal image via Gemini Vision.
 */
public class FoodImageResult {
    public String mealName;
    public Double estimatedKcal;
    public Double protein;
    public Double carb;
    public Double fat;
    public Double confidence;
    public List<String> detectedIngredients;
    public String mealType; // BREAKFAST, LUNCH, DINNER, SNACK
}
