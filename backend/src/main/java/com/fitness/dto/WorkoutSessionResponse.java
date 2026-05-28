package com.fitness.dto;

import java.time.LocalDateTime;
import java.util.List;

public class WorkoutSessionResponse {
    public Long id;
    public String title;
    public LocalDateTime startedAt;
    public LocalDateTime finishedAt;
    public Integer durationMinutes;
    public Integer plannedSetCount;
    public Integer completedSetCount;
    public String difficulty;
    public String notes;
    public LocalDateTime createdAt;
    public LocalDateTime updatedAt;
    public List<WorkoutResponse> workouts;
}
