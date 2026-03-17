package com.fitness.entity;

import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "ai_user_preferences")
public class AiUserPreference extends PanacheEntity {

    @Column(name = "user_id", nullable = false)
    public Long userId;

    @Column(name = "meal_name", nullable = false)
    public String mealName;

    @Column(name = "tags")
    public String tags; // Stored as comma separated string for simplicity

    @Column(name = "meal_type")
    public String mealType;

    @Column(name = "created_at", nullable = false)
    public LocalDateTime createdAt;
}
