package com.fitness.dto;

/**
 * Result of scanning a nutrition label via Gemini Vision.
 * All numeric values are per 100g unless servingSize specifies otherwise.
 */
public class NutritionLabelResult {
    public String productName;
    public Double kcal;
    public Double protein;
    public Double carb;
    public Double fat;
    public Double fiber;
    public Double sugar;
    public Double servingSize;
    public String servingUnit;
    public Double confidence;
}
