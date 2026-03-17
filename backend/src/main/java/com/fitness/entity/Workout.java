package com.fitness.entity;

import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

@Entity
@Table(name = "workouts")
public class Workout extends PanacheEntity {
    
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    public User user;
    
    @Column(nullable = false)
    public String name; // Antrenman adı

    @Column(name = "workout_type")
    public String workoutType; // STRENGTH, CARDIO, FLEXIBILITY, etc.
    
    @Column(name = "duration_minutes")
    public Integer durationMinutes; // Süre (dakika)
    
    @Column(name = "calories_burned")
    public Integer caloriesBurned; // Yakılan kalori
    
    @Column(name = "sets")
    public Integer sets; // Set sayısı (özet)
    
    @Column(name = "reps")
    public Integer reps; // Ortalama tekrar sayısı (özet)
    
    @Column(name = "weight")
    public Double weight; // Maksimum ağırlık (kg, özet)
    
    @Column(name = "workout_date", nullable = false)
    public LocalDateTime workoutDate;
    
    @Column(name = "notes")
    public String notes;

    // ─── Yeni alanlar (V6 migration ile eklendi) ─────────────────────────────

    @Column(name = "muscle_group")
    public String muscleGroup; // Hedef kas grubu: CHEST, BACK, LEGS...

    @Column(name = "is_superset")
    public Boolean isSuperset = false;

    @Column(name = "superset_partner")
    public String supersetPartner; // Superset partner egzersiz adı

    @Column(name = "one_rep_max")
    public Double oneRepMax; // Epley formülüyle hesaplanan tahminî 1RM (kg)

    @Column(name = "difficulty")
    public String difficulty; // EASY | MEDIUM | HARD | MAX

    // ─── Timestamp'ler ────────────────────────────────────────────────────────
    
    @Column(name = "created_at")
    public LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    public LocalDateTime updatedAt;
    
    @PrePersist
    public void prePersist() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (workoutDate == null) {
            workoutDate = LocalDateTime.now();
        }
    }
    
    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}