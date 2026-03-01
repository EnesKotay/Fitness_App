package com.fitness.dto;

import java.util.List;

/**
 * Request DTO for nutrition feedback endpoint
 * Used to record user meal preferences
 */
public class NutritionFeedbackRequest {
    public String mealName;
    public List<String> tags;
    public String mealType;
}
