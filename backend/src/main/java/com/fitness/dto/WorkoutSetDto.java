package com.fitness.dto;

/**
 * Tek bir setin detayı (request ve response için ortak)
 *
 * setType değerleri: WARMUP | NORMAL | DROP | FAILURE
 */
public class WorkoutSetDto {
    public Integer setNumber;
    public String  setType;   // "NORMAL" varsayılan
    public Integer reps;
    public Double  weight;

    public WorkoutSetDto() {}

    public WorkoutSetDto(Integer setNumber, String setType, Integer reps, Double weight) {
        this.setNumber = setNumber;
        this.setType   = setType != null ? setType : "NORMAL";
        this.reps      = reps;
        this.weight    = weight;
    }
}
