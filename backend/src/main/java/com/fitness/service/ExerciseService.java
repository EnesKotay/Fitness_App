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

    @jakarta.transaction.Transactional
    public ExerciseResponse createExercise(Exercise e) {
        exerciseRepository.persist(e);
        return toResponse(e);
    }

    @jakarta.transaction.Transactional
    public ExerciseResponse updateExercise(Long id, Exercise updated) {
        Exercise e = exerciseRepository.findById(id);
        if (e != null) {
            e.muscleGroup = updated.muscleGroup;
            e.name = updated.name;
            e.description = updated.description;
            e.instructions = updated.instructions;
            e.tips = updated.tips;
            return toResponse(e);
        }
        return null;
    }

    private ExerciseResponse toResponse(Exercise e) {
        return new ExerciseResponse(
                e.id,
                e.muscleGroup,
                e.name,
                e.description,
                e.instructions,
                e.tips);
    }
}
