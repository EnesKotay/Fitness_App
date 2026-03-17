package com.fitness.entity;

import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;

@Entity
@Table(name = "workout_sets")
public class WorkoutSet extends PanacheEntity {

    @ManyToOne
    @JoinColumn(name = "workout_id", nullable = false)
    public Workout workout;

    @Column(name = "set_number", nullable = false)
    public Integer setNumber;

    /** WARMUP | NORMAL | DROP | FAILURE */
    @Column(name = "set_type", nullable = false)
    public String setType = "NORMAL";

    @Column(name = "reps")
    public Integer reps;

    @Column(name = "weight")
    public Double weight;

    @Column(name = "created_at")
    public LocalDateTime createdAt;

    @PrePersist
    public void prePersist() {
        createdAt = LocalDateTime.now();
    }
}
