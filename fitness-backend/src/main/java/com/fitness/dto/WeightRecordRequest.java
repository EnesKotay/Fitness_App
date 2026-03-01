package com.fitness.dto;

import java.time.LocalDateTime;

public class WeightRecordRequest {
    public Double weight;
    public Double bodyFatPercentage;
    public Double muscleMass;
    public LocalDateTime recordedAt;
    public String notes;
}