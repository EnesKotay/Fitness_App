package com.fitness.service;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import com.fitness.entity.AiRateLimit;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

/**
 * Tier-aware rate limiter for AI endpoints backed by PostgreSQL.
 * Free users: 20 requests / 5 minutes (tight)
 * Premium users: 75 requests / day (soft-limit for cost protection)
 */
@ApplicationScoped
public class AiNutritionRateLimiter {

    private static final Logger LOG = Logger.getLogger(AiNutritionRateLimiter.class);
    private static final String SCOPE = "nutrition";

    // Free tier config
    @Inject
    @ConfigProperty(name = "ai.nutrition.rate-limit.max-requests", defaultValue = "20")
    int freeMaxRequests;

    @Inject
    @ConfigProperty(name = "ai.nutrition.rate-limit.window-seconds", defaultValue = "300")
    int freeWindowSeconds;

    // Premium tier config
    @Inject
    @ConfigProperty(name = "ai.premium.rate-limit.max-requests", defaultValue = "75")
    int premiumMaxRequests;

    @Inject
    @ConfigProperty(name = "ai.premium.rate-limit.window-seconds", defaultValue = "86400")
    int premiumWindowSeconds;

    /**
     * Try to acquire a rate limit slot.
     * 
     * @param userId    User ID
     * @param isPremium Whether the user has premium tier
     * @return true if request is allowed
     */
    @Transactional
    public boolean tryAcquire(Long userId, boolean isPremium) {
        if (isPremium) {
            return tryAcquireFromDb(userId, premiumMaxRequests, premiumWindowSeconds);
        } else {
            return tryAcquireFromDb(userId, freeMaxRequests, freeWindowSeconds);
        }
    }

    /**
     * Backward-compatible: defaults to free tier.
     */
    public boolean tryAcquire(Long userId) {
        return tryAcquire(userId, false);
    }

    /**
     * Get retry-after seconds for a rate-limited user.
     */
    @Transactional
    public int retryAfterSeconds(Long userId, boolean isPremium) {
        if (isPremium) {
            return retryAfterFromDb(userId, premiumMaxRequests, premiumWindowSeconds);
        } else {
            return retryAfterFromDb(userId, freeMaxRequests, freeWindowSeconds);
        }
    }

    /**
     * Backward-compatible: defaults to free tier.
     */
    public int retryAfterSeconds(Long userId) {
        return retryAfterSeconds(userId, false);
    }

    // ─── Internal DB Methods ──────────────────────────────────────

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

        // Check if window has expired
        if (limit.windowStart.isBefore(windowStart)) {
            // Reset window
            limit.windowStart = now;
            limit.requestCount = 1;
            limit.persist();
            return true;
        }

        // Inside window, check count
        if (limit.requestCount >= maxRequests) {
            return false;
        }

        limit.requestCount++;
        limit.persist();
        return true;
    }

    private int retryAfterFromDb(Long userId, int maxRequests, int windowSeconds) {
        AiRateLimit limit = AiRateLimit.find("userId = ?1 and scope = ?2", userId, SCOPE).firstResult();
        if (limit == null)
            return 0;

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime windowStart = now.minusSeconds(windowSeconds);

        if (limit.windowStart.isBefore(windowStart) || limit.requestCount < maxRequests) {
            return 0;
        }

        // Window end = windowStart + windowSeconds
        LocalDateTime windowEnd = limit.windowStart.plusSeconds(windowSeconds);
        long retryAfter = ChronoUnit.SECONDS.between(now, windowEnd);
        return (int) Math.max(1, retryAfter);
    }
}
