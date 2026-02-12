package com.fitness.dto;

import java.time.LocalDateTime;

public class MealResponse {
    public Long id;
    public String name;
    public String mealType;
    public Integer calories;
    public Double protein;
    public Double carbs;
    public Double fat;
    public LocalDateTime mealDate;
    public String notes;
    public LocalDateTime createdAt;
    public LocalDateTime updatedAt;
}