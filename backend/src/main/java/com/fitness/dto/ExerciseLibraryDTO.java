package com.fitness.dto;

import java.util.List;

public class ExerciseLibraryDTO {

    public String id;
    public String name;
    public String category;
    public String bodyPart;
    public String equipment;
    public String instructions; // Language-specific
    public List<String> instructionSteps; // Language-specific steps
    public String muscleGroup;
    public List<String> secondaryMuscles;
    public String target;
    public String mediaId;

    public ExerciseLibraryDTO() {
    }

    public ExerciseLibraryDTO(String id, String name, String category, String bodyPart,
                              String equipment, String instructions, List<String> instructionSteps,
                              String muscleGroup, List<String> secondaryMuscles,
                              String target, String mediaId) {
        this.id = id;
        this.name = name;
        this.category = category;
        this.bodyPart = bodyPart;
        this.equipment = equipment;
        this.instructions = instructions;
        this.instructionSteps = instructionSteps;
        this.muscleGroup = muscleGroup;
        this.secondaryMuscles = secondaryMuscles;
        this.target = target;
        this.mediaId = mediaId;
    }
}
