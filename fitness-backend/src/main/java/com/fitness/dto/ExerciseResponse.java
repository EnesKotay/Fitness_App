package com.fitness.dto;

public class ExerciseResponse {
    public Long id;
    public String muscleGroup;
    public String name;
    public String description;
    public String instructions;

    public ExerciseResponse() {
    }

    public ExerciseResponse(Long id, String muscleGroup, String name, String description, String instructions) {
        this.id = id;
        this.muscleGroup = muscleGroup;
        this.name = name;
        this.description = description;
        this.instructions = instructions;
    }
}
