package com.fitness.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.List;

@Entity
@Table(name = "exercise_library")
public class ExerciseLibrary extends PanacheEntityBase {

    @Id
    public String id;

    @Column(nullable = false)
    public String name;

    @Column(nullable = false)
    public String category;

    @Column(name = "body_part", nullable = false)
    public String bodyPart;

    @Column(nullable = false)
    public String equipment;

    @Column(name = "instructions_en", columnDefinition = "TEXT")
    public String instructionsEn;

    @Column(name = "instructions_tr", columnDefinition = "TEXT")
    public String instructionsTr;

    @Column(name = "instructions_es", columnDefinition = "TEXT")
    public String instructionsEs;

    @Column(name = "instructions_it", columnDefinition = "TEXT")
    public String instructionsIt;

    @Column(name = "instructions_ru", columnDefinition = "TEXT")
    public String instructionsRu;

    @Column(name = "instructions_zh", columnDefinition = "TEXT")
    public String instructionsZh;

    @Column(name = "instruction_steps_en", columnDefinition = "TEXT")
    public String instructionStepsEn; // JSON array as string

    @Column(name = "instruction_steps_tr", columnDefinition = "TEXT")
    public String instructionStepsTr; // JSON array as string

    @Column(name = "muscle_group")
    public String muscleGroup;

    @Column(name = "secondary_muscles", columnDefinition = "TEXT")
    public String secondaryMuscles; // JSON array as string

    public String target;

    @Column(name = "media_id")
    public String mediaId;

    @Column(name = "created_at")
    public LocalDateTime createdAt;

    // Panache query helpers
    public static List<ExerciseLibrary> findByCategory(String category) {
        return list("category", category);
    }

    public static List<ExerciseLibrary> findByEquipment(String equipment) {
        return list("equipment", equipment);
    }

    public static List<ExerciseLibrary> findByTarget(String target) {
        return list("target", target);
    }

    public static List<ExerciseLibrary> findByBodyPart(String bodyPart) {
        return list("bodyPart", bodyPart);
    }

    public static List<ExerciseLibrary> searchByName(String query) {
        return list("LOWER(name) LIKE LOWER(?1)", "%" + query + "%");
    }
}
