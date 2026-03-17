package com.fitness.dto;

import java.time.LocalDateTime;
import java.util.List;

public class WorkoutResponse {
    public Long id;
    public String name;
    public String workoutType;
    public Integer durationMinutes;
    public Integer caloriesBurned;
    public Integer sets;
    public Integer reps;
    public Double weight;
    public LocalDateTime workoutDate;
    public String notes;
    public LocalDateTime createdAt;
    public LocalDateTime updatedAt;

    // ─── Yeni alanlar ────────────────────────────────────────────────────────
    /** Set bazlı detaylar (workout_sets tablosundan) */
    public List<WorkoutSetDto> setDetails;

    /** Hedef kas grubu */
    public String muscleGroup;

    /** Superset mi? */
    public Boolean isSuperset;

    /** Superset partner egzersiz adı */
    public String supersetPartner;

    /** Epley formülüyle hesaplanan 1RM (kg) */
    public Double oneRepMax;

    /** Kullanıcının zorluk değerlendirmesi: EASY / MEDIUM / HARD / MAX */
    public String difficulty;
}