package com.fitness.dto;

public class ExerciseResponse {
    public Long id;
    public String muscleGroup;
    public String name;
    public String description;
    public String instructions;
    public String tips;

    public ExerciseResponse() {
    }

    public ExerciseResponse(Long id, String muscleGroup, String name, String description, String instructions, String tips) {
        this.id = id;
        this.muscleGroup = muscleGroup;
        this.name = name;
        this.description = description;
        this.instructions = instructions;
        this.tips = tips;
    }
}
