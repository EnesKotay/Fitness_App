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
@Table(name = "meals")
public class Meal extends PanacheEntity {
    
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    public User user;
    
    @Column(nullable = false)
    public String name; // Yemek adı
    
    @Column(name = "meal_type", nullable = false)
    public String mealType; // BREAKFAST, LUNCH, DINNER, SNACK
    
    @Column(nullable = false)
    public Integer calories; // Kalori
    
    @Column(name = "protein")
    public Double protein; // Protein (gram)
    
    @Column(name = "carbs")
    public Double carbs; // Karbonhidrat (gram)
    
    @Column(name = "fat")
    public Double fat; // Yağ (gram)
    
    @Column(name = "meal_date", nullable = false)
    public LocalDateTime mealDate;
    
    @Column(name = "notes")
    public String notes; // Notlar
    
    @Column(name = "created_at")
    public LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    public LocalDateTime updatedAt;
    
    @PrePersist
    public void prePersist() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (mealDate == null) {
            mealDate = LocalDateTime.now();
        }
    }
    
    @PreUpdate
    public void preUpdate() {
        updatedAt = LocalDateTime.now();
    }
}