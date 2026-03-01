package com.fitness.dto;

import java.time.LocalDateTime;

public class MealRequest {
    public String name;
    public String mealType; // BREAKFAST, LUNCH, DINNER, SNACK
    public Integer calories;
    public Double protein;
    public Double carbs;
    public Double fat;
    public LocalDateTime mealDate;
    public String notes;
}