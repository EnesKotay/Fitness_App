package com.fitness.dto;

import jakarta.validation.constraints.NotNull;
import java.time.LocalDate;

public class BodyMeasurementRequest {
    @NotNull(message = "Tarih boş olamaz")
    public LocalDate date;
    public Double chest;
    public Double waist;
    public Double hips;
    public Double leftArm;
    public Double rightArm;
    public Double leftLeg;
    public Double rightLeg;
}
