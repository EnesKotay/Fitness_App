package com.fitness.service;

import com.fitness.dto.ExerciseLibraryDTO;
import com.fitness.entity.ExerciseLibrary;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@ApplicationScoped
public class ExerciseLibraryService {

    @Inject
    ObjectMapper objectMapper;

    /**
     * Convert entity to DTO with specified language
     */
    public ExerciseLibraryDTO toDTO(ExerciseLibrary entity, String language) {
        if (entity == null) return null;

        String instructions = getInstructionsByLanguage(entity, language);
        List<String> steps = getInstructionStepsByLanguage(entity, language);
        List<String> secondaryMuscles = parseJsonArray(entity.secondaryMuscles);

        return new ExerciseLibraryDTO(
            entity.id,
            entity.name,
            entity.category,
            entity.bodyPart,
            entity.equipment,
            instructions,
            steps,
            entity.muscleGroup,
            secondaryMuscles,
            entity.target,
            entity.mediaId
        );
    }

    /**
     * Get all exercises with language preference
     */
    public List<ExerciseLibraryDTO> getAllExercises(String language) {
        return ExerciseLibrary.<ExerciseLibrary>listAll()
            .stream()
            .map(e -> toDTO(e, language))
            .collect(Collectors.toList());
    }

    /**
     * Search exercises by name
     */
    public List<ExerciseLibraryDTO> searchByName(String query, String language) {
        return ExerciseLibrary.searchByName(query)
            .stream()
            .map(e -> toDTO(e, language))
            .collect(Collectors.toList());
    }

    /**
     * Filter by category
     */
    public List<ExerciseLibraryDTO> getByCategory(String category, String language) {
        return ExerciseLibrary.findByCategory(category)
            .stream()
            .map(e -> toDTO(e, language))
            .collect(Collectors.toList());
    }

    /**
     * Filter by equipment
     */
    public List<ExerciseLibraryDTO> getByEquipment(String equipment, String language) {
        return ExerciseLibrary.findByEquipment(equipment)
            .stream()
            .map(e -> toDTO(e, language))
            .collect(Collectors.toList());
    }

    /**
     * Filter by target muscle
     */
    public List<ExerciseLibraryDTO> getByTarget(String target, String language) {
        return ExerciseLibrary.findByTarget(target)
            .stream()
            .map(e -> toDTO(e, language))
            .collect(Collectors.toList());
    }

    /**
     * Get exercise by ID
     */
    public ExerciseLibraryDTO getById(String id, String language) {
        ExerciseLibrary entity = ExerciseLibrary.findById(id);
        return toDTO(entity, language);
    }

    /**
     * Get bodyweight exercises (no equipment needed)
     */
    public List<ExerciseLibraryDTO> getBodyweightExercises(String language) {
        return getByEquipment("body weight", language);
    }

    // Helper methods
    private String getInstructionsByLanguage(ExerciseLibrary entity, String lang) {
        return switch (lang != null ? lang.toLowerCase() : "en") {
            case "tr" -> entity.instructionsTr != null ? entity.instructionsTr : entity.instructionsEn;
            case "es" -> entity.instructionsEs != null ? entity.instructionsEs : entity.instructionsEn;
            case "it" -> entity.instructionsIt != null ? entity.instructionsIt : entity.instructionsEn;
            case "ru" -> entity.instructionsRu != null ? entity.instructionsRu : entity.instructionsEn;
            case "zh" -> entity.instructionsZh != null ? entity.instructionsZh : entity.instructionsEn;
            default -> entity.instructionsEn;
        };
    }

    private List<String> getInstructionStepsByLanguage(ExerciseLibrary entity, String lang) {
        String stepsJson = switch (lang != null ? lang.toLowerCase() : "en") {
            case "tr" -> entity.instructionStepsTr != null ? entity.instructionStepsTr : entity.instructionStepsEn;
            default -> entity.instructionStepsEn;
        };
        return parseJsonArray(stepsJson);
    }

    private List<String> parseJsonArray(String json) {
        if (json == null || json.trim().isEmpty()) {
            return new ArrayList<>();
        }
        try {
            return objectMapper.readValue(json, new TypeReference<List<String>>() {});
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }
}
