package com.fitness.dto;

import java.time.LocalDateTime;

public class ProfileUpdateRequest {
    public String name;
    public Double height;
    public Double weight;
    public Double targetWeight;
    public LocalDateTime birthDate;
    public String gender;
    public String activityLevel;
    public String goal;
    public String workoutLocation;
    public String equipmentType;
    public String nutritionPreferencesJson;
    public String aiMemorySummary;
    public String motivationStatsJson;
}
