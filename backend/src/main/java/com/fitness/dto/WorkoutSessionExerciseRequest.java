package com.fitness.dto;

import java.util.List;

public class WorkoutSessionExerciseRequest {
    public String name;
    public String workoutType;
    public String muscleGroup;
    public Integer plannedSets;
    public Integer completedSets;
    public Integer reps;
    public Double weight;
    public Integer restSeconds;
    public String notes;
    public List<WorkoutSetDto> setDetails;
}
