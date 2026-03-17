package com.fitness.service;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import com.fitness.entity.AiRateLimit;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

/**
 * Tier-aware rate limiter for AI Coach endpoints backed by PostgreSQL.
 * Free users: 10 requests / 5 minutes
 * Premium users: 75 requests / day
 */
@ApplicationScoped
public class AiCoachRateLimiter {

    private static final String SCOPE = "coach";

    @Inject
    @ConfigProperty(name = "ai.coach.rate-limit.max-requests", defaultValue = "10")
    int freeMaxRequests;

    @Inject
    @ConfigProperty(name = "ai.coach.rate-limit.window-seconds", defaultValue = "300")
    int freeWindowSeconds;

    @Inject
    @ConfigProperty(name = "ai.premium.rate-limit.max-requests", defaultValue = "75")
    int premiumMaxRequests;

    @Inject
    @ConfigProperty(name = "ai.premium.rate-limit.window-seconds", defaultValue = "86400")
    int premiumWindowSeconds;

    @Transactional
    public boolean tryAcquire(Long userId, boolean isPremium) {
        if (isPremium) {
            return tryAcquireFromDb(userId, premiumMaxRequests, premiumWindowSeconds);
        }
        return tryAcquireFromDb(userId, freeMaxRequests, freeWindowSeconds);
    }

    public boolean tryAcquire(Long userId) {
        return tryAcquire(userId, false);
    }

    @Transactional
    public int retryAfterSeconds(Long userId, boolean isPremium) {
        if (isPremium) {
            return retryAfterFromDb(userId, premiumMaxRequests, premiumWindowSeconds);
        }
        return retryAfterFromDb(userId, freeMaxRequests, freeWindowSeconds);
    }

    public int retryAfterSeconds(Long userId) {
        return retryAfterSeconds(userId, false);
    }

    private boolean tryAcquireFromDb(Long userId, int maxRequests, int windowSeconds) {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = now.minusSeconds(windowSeconds);

        AiRateLimit limit = AiRateLimit.find("userId = ?1 and scope = ?2", userId, SCOPE).firstResult();

        if (limit == null) {
            limit = new AiRateLimit();
            limit.userId = userId;
            limit.scope = SCOPE;
            limit.requestCount = 1;
            limit.windowStart = now;
            limit.persist();
            return true;
        }

        if (limit.windowStart.isBefore(windowStart)) {
            limit.windowStart = now;
            limit.requestCount = 1;
            limit.persist();
            return true;
        }

        if (limit.requestCount >= maxRequests) {
            return false;
        }

        limit.requestCount++;
        limit.persist();
        return true;
    }

    private int retryAfterFromDb(Long userId, int maxRequests, int windowSeconds) {
        AiRateLimit limit = AiRateLimit.find("userId = ?1 and scope = ?2", userId, SCOPE).firstResult();
        if (limit == null) {
            return 0;
        }

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = now.minusSeconds(windowSeconds);

        if (limit.windowStart.isBefore(windowStart) || limit.requestCount < maxRequests) {
            return 0;
        }

        LocalDateTime windowEnd = limit.windowStart.plusSeconds(windowSeconds);
        long retryAfter = ChronoUnit.SECONDS.between(now, windowEnd);
        return (int) Math.max(1, retryAfter);
    }
}
