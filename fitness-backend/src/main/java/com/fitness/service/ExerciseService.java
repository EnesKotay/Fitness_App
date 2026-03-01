package com.fitness.service;

import java.util.List;
import java.util.stream.Collectors;

import com.fitness.dto.ExerciseResponse;
import com.fitness.entity.Exercise;
import com.fitness.repository.ExerciseRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class ExerciseService {

    @Inject
    ExerciseRepository exerciseRepository;

    public List<String> getMuscleGroups() {
        return exerciseRepository.findDistinctMuscleGroups();
    }

    public List<ExerciseResponse> getExercisesByMuscleGroup(String muscleGroup) {
        return exerciseRepository.findByMuscleGroup(muscleGroup).stream()
                .map(this::toResponse)
                .collect(Collectors.toList());
    }

    private ExerciseResponse toResponse(Exercise e) {
        return new ExerciseResponse(
                e.id,
                e.muscleGroup,
                e.name,
                e.description,
                e.instructions);
    }
}
