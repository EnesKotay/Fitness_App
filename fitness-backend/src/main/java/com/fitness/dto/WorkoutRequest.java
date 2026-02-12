package com.fitness.dto;

import java.time.LocalDateTime;

public class WorkoutRequest {
    public String name;
    public String workoutType;
    public Integer durationMinutes;
    public Integer caloriesBurned;
    public LocalDateTime workoutDate;
    public String notes;
}