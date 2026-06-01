package com.fitness.entity;

import java.time.LocalDate;
import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

/**
 * Kullanıcının haftalık antrenman yükünü takip eder.
 * Volume, intensity (RPE), kas grubu bazında analiz için kullanılır.
 */
@Entity
@Table(name = "weekly_training_load")
public class WeeklyTrainingLoad extends PanacheEntity {

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    public User user;

    /** Haftanın başlangıç tarihi (Pazartesi) */
    @Column(name = "week_start", nullable = false)
    public LocalDate weekStart;

    /** Haftanın bitiş tarihi (Pazar) */
    @Column(name = "week_end", nullable = false)
    public LocalDate weekEnd;

    /** Toplam set sayısı */
    @Column(name = "total_sets")
    public Integer totalSets;

    /** Toplam volume (sets × reps × weight) */
    @Column(name = "total_volume_kg")
    public Double totalVolumeKg;

    /** Ortalama RPE (Rate of Perceived Exertion) */
    @Column(name = "avg_rpe")
    public Double avgRPE;

    /** Kas grubu (CHEST, BACK, LEGS, SHOULDERS, BICEPS, TRICEPS, CORE, GLUTES, FULL_BODY) */
    @Column(name = "muscle_group", length = 30)
    public String muscleGroup;

    /** Antrenman sayısı (o kas grubu için o hafta) */
    @Column(name = "workout_count")
    public Integer workoutCount;

    @Column(name = "created_at")
    public LocalDateTime createdAt;

    @Column(name = "updated_at")
    public LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
