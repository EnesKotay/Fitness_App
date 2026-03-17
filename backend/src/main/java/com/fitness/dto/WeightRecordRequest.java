package com.fitness.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;

public class WeightRecordRequest {
    @NotNull(message = "Kilo boş olamaz")
    public Double weight;
    public Double bodyFatPercentage;
    public Double muscleMass;
    public LocalDateTime recordedAt;
    public String notes;
}