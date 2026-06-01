package com.fitness.service;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Objects;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fitness.entity.AiRateLimit;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.persistence.EntityManager;
import jakarta.persistence.LockModeType;
import jakarta.transaction.Transactional;

/**
 * Tier-aware rate limiter for AI Coach endpoints backed by PostgreSQL.
 * Free users: 10 requests / 5 minutes
 * Premium users: 75 requests / day
 */
@ApplicationScoped
public class AiCoachRateLimiter {

    private static final Logger LOG = Logger.getLogger(AiCoachRateLimiter.class);
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

    @Inject
    EntityManager entityManager;

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
        lockScope(userId);
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = now.minusSeconds(windowSeconds);

        // Pessimistic write lock: concurrent requests block here instead of racing.
        AiRateLimit limit = AiRateLimit.find("userId = ?1 and scope = ?2", userId, SCOPE)
                .withLock(LockModeType.PESSIMISTIC_WRITE)
                .firstResult();

        if (limit == null) {
            try {
                limit = new AiRateLimit();
                limit.userId = userId;
                limit.scope = SCOPE;
                limit.requestCount = 1;
                limit.windowStart = now;
                limit.persist();
                return true;
            } catch (Exception e) {
                // Unique constraint violation: another transaction inserted first — re-read.
                LOG.debugf("AiRateLimit insert conflict for userId=%d scope=%s, re-reading.", userId, SCOPE);
                limit = AiRateLimit.find("userId = ?1 and scope = ?2", userId, SCOPE)
                        .withLock(LockModeType.PESSIMISTIC_WRITE)
                        .firstResult();
                if (limit == null) throw e;
            }
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

    private void lockScope(Long userId) {
        long lockKey = Objects.hash(userId, SCOPE);
        entityManager.createNativeQuery("SELECT pg_advisory_xact_lock(?1)")
                .setParameter(1, lockKey)
                .getSingleResult();
    }
}
