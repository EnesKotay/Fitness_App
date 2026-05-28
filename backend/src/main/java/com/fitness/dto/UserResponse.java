package com.fitness.dto;

import java.time.LocalDateTime;

public class UserResponse {
    public Long id;
    public String email;
    public String name;
    public Double height;
    public Double weight;
    public Double targetWeight;
    public LocalDateTime birthDate;
    public String gender;
    public String activityLevel;
    public String goal;
    public String goalHistoryJson;
    public String workoutLocation;
    public String equipmentType;
    public String nutritionPreferencesJson;
    public String aiMemorySummary;
    public String motivationStatsJson;
    public String premiumTier;
    public LocalDateTime premiumExpiresAt;
    public String premiumPlan;
    public Boolean premiumCancelAtPeriodEnd;
    public LocalDateTime premiumCanceledAt;
    public LocalDateTime createdAt;
    public LocalDateTime updatedAt;
}
