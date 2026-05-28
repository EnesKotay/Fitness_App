package com.fitness.entity;

import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;

@Entity
@Table(
        name = "notification_devices",
        uniqueConstraints = @UniqueConstraint(columnNames = {"token"}))
public class NotificationDevice extends PanacheEntity {

    @ManyToOne
    public User user;

    @Column(nullable = false, columnDefinition = "TEXT")
    public String token;

    @Column(nullable = false)
    public String platform;

    @Column(name = "app_version")
    public String appVersion;

    @Column(nullable = false)
    public boolean active = true;

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
