package com.fitness.dto;

import java.time.LocalDate;

public class BodyMeasurementResponse {
    public Long id;
    public Long userId;
    public LocalDate date;
    public Double chest;
    public Double waist;
    public Double hips;
    public Double leftArm;
    public Double rightArm;
    public Double leftLeg;
    public Double rightLeg;
}
