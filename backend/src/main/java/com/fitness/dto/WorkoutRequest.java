package com.fitness.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import java.time.LocalDateTime;
import java.util.List;

public class WorkoutRequest {
    @NotBlank(message = "Antrenman adı boş olamaz")
    public String name;
    
    @NotBlank(message = "Antrenman tipi boş olamaz")
    public String workoutType;
    public Integer durationMinutes;
    public Integer caloriesBurned;
    public Integer sets;
    public Integer reps;
    public Double weight;
    public LocalDateTime workoutDate;
    public String notes;

    // ─── Yeni alanlar ────────────────────────────────────────────────────────
    /** Her setin detayı: { setNumber, setType, reps, weight } */
    public List<WorkoutSetDto> setDetails;

    /** Hedef kas grubu: CHEST, BACK, LEGS, SHOULDERS, BICEPS, TRICEPS, CORE, GLUTES */
    public String muscleGroup;

    /** Superset modu etkin mi? */
    public Boolean isSuperset;

    /** Superset partner egzersiz adı */
    public String supersetPartner;

    /** Kullanıcının zorluk değerlendirmesi: EASY | MEDIUM | HARD | MAX */
    public String difficulty;

    /** Epley formülüyle frontend'in hesapladığı 1RM (isteğe bağlı) */
    public Double oneRepMax;
}