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
@Table(name = "workout_sessions")
public class WorkoutSession extends PanacheEntity {

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    public User user;

    @Column(nullable = false)
    public String title;

    @Column(name = "started_at")
    public LocalDateTime startedAt;

    @Column(name = "finished_at", nullable = false)
    public LocalDateTime finishedAt;

    @Column(name = "duration_minutes")
    public Integer durationMinutes;

    @Column(name = "planned_set_count")
    public Integer plannedSetCount;

    @Column(name = "completed_set_count")
    public Integer completedSetCount;

    @Column(name = "difficulty", length = 20)
    public String difficulty;

    @Column(name = "notes", length = 1000)
    public String notes;

    @Column(name = "created_at")
    public LocalDateTime createdAt;

    @Column(name = "updated_at")
    public LocalDateTime updatedAt;

    @PrePersist
    public void prePersist() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (finishedAt == null) {
            finishedAt = LocalDateTime.now();
        }
    }

    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}
