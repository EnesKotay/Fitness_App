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
    public String premiumTier;
    public LocalDateTime premiumExpiresAt;
    public String premiumPlan;
    public Boolean premiumCancelAtPeriodEnd;
    public LocalDateTime premiumCanceledAt;
    public LocalDateTime createdAt;
    public LocalDateTime updatedAt;
}
