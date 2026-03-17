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
@Table(name = "weight_records")
public class WeightRecord extends PanacheEntity {
    
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    public User user;
    
    @Column(nullable = false)
    public Double weight; // kg cinsinden
    
    @Column(name = "body_fat_percentage")
    public Double bodyFatPercentage; // Vücut yağ yüzdesi
    
    @Column(name = "muscle_mass")
    public Double muscleMass; // Kas kütlesi (kg)
    
    @Column(name = "recorded_at", nullable = false)
    public LocalDateTime recordedAt;
    
    @Column(name = "notes")
    public String notes; // Kullanıcı notları
    
    @Column(name = "created_at")
    public LocalDateTime createdAt;
    
    @PrePersist
    public void prePersist() {
        createdAt = LocalDateTime.now();
        if (recordedAt == null) {
            recordedAt = LocalDateTime.now();
        }
    }
}