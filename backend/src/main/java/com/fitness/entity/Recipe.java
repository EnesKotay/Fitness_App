package com.fitness.entity;

import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntityBase;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.SequenceGenerator;
import jakarta.persistence.Table;

@Entity
@Table(name = "recipes")
public class Recipe extends PanacheEntityBase {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "recipe_gen")
    @SequenceGenerator(name = "recipe_gen", sequenceName = "recipe_seq", allocationSize = 50)
    public Long id;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    public User user;

    @Column(name = "external_id", nullable = false)
    public String externalId;

    @Column(nullable = false)
    public String name;

    @Column(columnDefinition = "TEXT")
    public String description;

    public String category;

    public int servings = 1;

    @Column(name = "prep_time_minutes")
    public int prepTimeMinutes;

    @Column(name = "cook_time_minutes")
    public int cookTimeMinutes;

    @Column(name = "image_emoji")
    public String imageEmoji = "🍽️";

    @Column(name = "kcal_per_serving")
    public double kcalPerServing;

    @Column(name = "protein_per_serving")
    public double proteinPerServing;

    @Column(name = "carb_per_serving")
    public double carbPerServing;

    @Column(name = "fat_per_serving")
    public double fatPerServing;

    @Column(name = "fiber_per_serving")
    public double fiberPerServing;

    @Column(name = "sugar_per_serving")
    public double sugarPerServing;

    @Column(columnDefinition = "TEXT")
    public String tags;

    @Column(columnDefinition = "TEXT")
    public String ingredients;

    @Column(columnDefinition = "TEXT")
    public String steps;

    public String difficulty = "orta";

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
