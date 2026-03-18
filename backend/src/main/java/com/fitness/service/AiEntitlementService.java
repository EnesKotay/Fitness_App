package com.fitness.service;

import java.time.LocalDateTime;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import com.fitness.entity.AiRateLimit;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.ForbiddenException;

@ApplicationScoped
public class AiEntitlementService {

    private static final String COACH_FREE_DAILY_SCOPE = "coach_free_daily";

    @Inject
    AiProviderRouter aiProviderRouter;

    @Inject
    @ConfigProperty(name = "ai.coach.free-daily-limit.max-requests", defaultValue = "2")
    int freeCoachDailyMaxRequests;

    @Inject
    @ConfigProperty(name = "ai.coach.free-daily-limit.window-seconds", defaultValue = "86400")
    int freeCoachDailyWindowSeconds;

    public boolean isPremium(Long userId) {
        return aiProviderRouter.isPremium(userId);
    }

    public void ensurePremium(Long userId, String featureName) {
        if (isPremium(userId)) {
            return;
        }
        throw new ForbiddenException(featureName + " ozelligi sadece Premium kullanicilara ozel.");
    }

    @Transactional
    public boolean tryConsumeFreeCoachRequest(Long userId) {
        return tryAcquireScope(userId, COACH_FREE_DAILY_SCOPE, freeCoachDailyMaxRequests, freeCoachDailyWindowSeconds);
    }

    @Transactional
    public void refundFreeCoachRequest(Long userId) {
        AiRateLimit limit = AiRateLimit.find("userId = ?1 and scope = ?2", userId, COACH_FREE_DAILY_SCOPE).firstResult();
        if (limit == null || limit.requestCount == null || limit.requestCount <= 0) {
            return;
        }
        limit.requestCount = limit.requestCount - 1;
        if (limit.requestCount <= 0) {
            limit.delete();
            return;
        }
        limit.persist();
    }

    @Transactional
    public int remainingFreeCoachRequests(Long userId) {
        AiRateLimit limit = AiRateLimit.find("userId = ?1 and scope = ?2", userId, COACH_FREE_DAILY_SCOPE).firstResult();
        if (limit == null || hasWindowExpired(limit, freeCoachDailyWindowSeconds)) {
            return freeCoachDailyMaxRequests;
        }
        int remaining = freeCoachDailyMaxRequests - limit.requestCount;
        return Math.max(0, remaining);
    }

    private boolean tryAcquireScope(Long userId, String scope, int maxRequests, int windowSeconds) {
        LocalDateTime now = LocalDateTime.now();
        AiRateLimit limit = AiRateLimit.find("userId = ?1 and scope = ?2", userId, scope).firstResult();

        if (limit == null) {
            limit = new AiRateLimit();
            limit.userId = userId;
            limit.scope = scope;
            limit.requestCount = 1;
            limit.windowStart = now;
            limit.persist();
            return true;
        }

        if (hasWindowExpired(limit, windowSeconds)) {
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

    private boolean hasWindowExpired(AiRateLimit limit, int windowSeconds) {
        LocalDateTime windowStart = LocalDateTime.now().minusSeconds(windowSeconds);
        return limit.windowStart == null || limit.windowStart.isBefore(windowStart);
    }
}
