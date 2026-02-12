package com.fitness.entity;

import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;

@Entity
@Table(name = "users")
public class User extends PanacheEntity {
    
    @Column(nullable = false, unique = true)
    public String email;
    
    @Column(nullable = false)
    public String password;
    
    @Column(nullable = false)
    public String name;
    
    @Column(name = "created_at")
    public LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    public LocalDateTime updatedAt;
    
    // Kullanıcı bilgileri için ek alanlar
    @Column(name = "height")
    public Double height; // cm cinsinden

    @Column(name = "weight")
    public Double weight; // kg cinsinden
    
    @Column(name = "birth_date")
    public LocalDateTime birthDate;
    
    @Column(name = "gender")
    public String gender; // MALE, FEMALE, OTHER
    
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