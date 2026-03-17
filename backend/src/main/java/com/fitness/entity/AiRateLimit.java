package com.fitness.entity;

import java.time.LocalDateTime;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;

@Entity
@Table(name = "ai_rate_limits")
public class AiRateLimit extends PanacheEntity {

    @Column(name = "user_id", nullable = false)
    public Long userId;

    @Column(name = "scope", nullable = false, length = 32)
    public String scope;

    @Column(name = "request_count", nullable = false)
    public Integer requestCount = 0;

    @Column(name = "window_start", nullable = false)
    public LocalDateTime windowStart;
}
