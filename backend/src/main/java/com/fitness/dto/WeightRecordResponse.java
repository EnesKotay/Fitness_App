package com.fitness.dto;

import java.time.LocalDateTime;

public class WeightRecordResponse {
    public Long id;
    public Double weight;
    public Double bodyFatPercentage;
    public Double muscleMass;
    public LocalDateTime recordedAt;
    public String notes;
    public LocalDateTime createdAt;
}