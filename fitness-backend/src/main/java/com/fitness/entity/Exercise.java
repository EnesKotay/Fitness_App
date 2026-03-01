package com.fitness.entity;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "exercises")
public class Exercise extends PanacheEntity {

    /** Kas grubu: CHEST, BACK, LEGS, SHOULDERS, BICEPS, TRICEPS, CORE, GLUTES */
    @Column(name = "muscle_group", nullable = false)
    public String muscleGroup;

    @Column(nullable = false)
    public String name;

    @Column(columnDefinition = "TEXT")
    public String description;

    /** Örn: set x tekrar notu */
    @Column(name = "instructions", columnDefinition = "TEXT")
    public String instructions;
}
