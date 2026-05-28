package com.fitness.dto;

import java.time.LocalDateTime;
import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

public class WorkoutSessionRequest {
    @NotBlank(message = "Seans adı boş olamaz")
    public String title;
    public LocalDateTime startedAt;
    public LocalDateTime finishedAt;
    public Integer durationMinutes;
    public Integer plannedSetCount;
    public Integer completedSetCount;
    public String difficulty;
    public String notes;

    @NotEmpty(message = "Seans en az bir egzersiz içermeli")
    public List<WorkoutSessionExerciseRequest> exercises;
}
