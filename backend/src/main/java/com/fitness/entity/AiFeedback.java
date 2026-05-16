package com.fitness.entity;

import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "ai_feedback")
public class AiFeedback extends PanacheEntity {

    @Column(name = "user_id", nullable = false)
    public Long userId;

    @Column(name = "ai_response", columnDefinition = "TEXT", nullable = false)
    public String aiResponse;

    /** POSITIVE or NEGATIVE */
    @Column(name = "reaction", nullable = false, length = 16)
    public String reaction;

    @Column(name = "task_mode", length = 32)
    public String taskMode;

    @Column(name = "personality", length = 32)
    public String personality;

    @Column(name = "created_at", nullable = false)
    public LocalDateTime createdAt;
}
