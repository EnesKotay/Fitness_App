package com.fitness.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;

public class MealRequest {
    @NotBlank(message = "Yemek adı boş olamaz")
    public String name;
    
    @NotBlank(message = "Yemek türü boş olamaz")
    public String mealType; // BREAKFAST, LUNCH, DINNER, SNACK
    
    @NotNull(message = "Kalori boş olamaz")
    public Integer calories;
    public Double protein;
    public Double carbs;
    public Double fat;
    public LocalDateTime mealDate;
    public String notes;
}