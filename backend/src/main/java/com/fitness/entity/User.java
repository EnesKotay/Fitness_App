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

    @Column(name = "target_weight")
    public Double targetWeight; // kg cinsinden

    @Column(name = "birth_date")
    public LocalDateTime birthDate;

    @Column(name = "gender")
    public String gender; // MALE, FEMALE, OTHER

    @Column(name = "activity_level")
    public String activityLevel; // sedentary, lightlyActive, ...

    @Column(name = "goal")
    public String goal; // bulk, cut, maintain, strength

    @Column(name = "goal_history_json", columnDefinition = "TEXT")
    public String goalHistoryJson;

    @Column(name = "workout_location")
    public String workoutLocation; // home, gym, outdoor

    @Column(name = "equipment_type")
    public String equipmentType; // bodyweight, dumbbell, fullGym

    @Column(name = "nutrition_preferences_json", columnDefinition = "TEXT")
    public String nutritionPreferencesJson;

    @Column(name = "ai_memory_summary", columnDefinition = "TEXT")
    public String aiMemorySummary;

    @Column(name = "motivation_stats_json", columnDefinition = "TEXT")
    public String motivationStatsJson;

    @Column(name = "coaching_personality")
    public String coachingPersonality = "SUPPORTIVE"; // SUPPORTIVE, TOUGH_LOVE, ANALYTICAL

    @Column(name = "premium_tier")
    public String premiumTier = "free"; // "free" or "premium"

    @Column(name = "premium_expires_at")
    public LocalDateTime premiumExpiresAt;

    @Column(name = "premium_plan")
    public String premiumPlan; // "monthly" or "yearly"

    @Column(name = "premium_cancel_at_period_end")
    public Boolean premiumCancelAtPeriodEnd = false;

    @Column(name = "premium_canceled_at")
    public LocalDateTime premiumCanceledAt;

    // Apple App Store Server Notifications ile yenileme bildirimi eşleştirmesi için
    @Column(name = "iap_original_transaction_id", unique = true)
    public String iapOriginalTransactionId;

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
