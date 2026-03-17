package com.fitness.entity;

import java.time.LocalDateTime;
import java.util.List;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

/**
 * Stores periodic AI-generated insights and summaries about a user's progress.
 * This provides the AI with long-term memory.
 */
@Entity
@Table(name = "ai_insights")
public class AiInsight extends PanacheEntity {

    @ManyToOne
    public User user;

    @Column(nullable = false)
    public LocalDateTime createdAt;

    @Column(columnDefinition = "TEXT")
    public String summary;

    @Column(length = 50)
    public String type; // e.g., "WEEKLY_PROGRESS", "NUTRITION_TREND", "WORKOUT_MILESTONE"

    @Column(columnDefinition = "TEXT")
    public String metadataJson; // Flexible storage for specific metrics

    public AiInsight() {
        this.createdAt = LocalDateTime.now();
    }

    public static List<AiInsight> findRecentByUser(Long userId, int limit) {
        return find("user.id = ?1 order by createdAt desc", userId)
                .range(0, limit - 1)
                .list();
    }
}
