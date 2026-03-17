package com.fitness;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.fitness.entity.AiRateLimit;
import com.fitness.service.AiCoachRateLimiter;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@QuarkusTest
public class AiCoachRateLimiterTest {

    @Inject
    AiCoachRateLimiter rateLimiter;

    @BeforeEach
    @Transactional
    public void setup() {
        AiRateLimit.deleteAll();
    }

    @Test
    public void testFreeTierLimits() {
        Long testUserId = 9981L;

        for (int i = 0; i < 10; i++) {
            assertTrue(rateLimiter.tryAcquire(testUserId, false), "Request " + (i + 1) + " should be allowed");
        }

        assertFalse(rateLimiter.tryAcquire(testUserId, false), "11th request should be blocked");
        assertTrue(rateLimiter.retryAfterSeconds(testUserId, false) > 0, "Retry after should be positive integer");
    }

    @Test
    @Transactional
    public void testUsesCoachScope() {
        Long userId = 9982L;

        assertTrue(rateLimiter.tryAcquire(userId, false));

        AiRateLimit saved = AiRateLimit.find("userId = ?1 and scope = ?2", userId, "coach").firstResult();
        assertEquals("coach", saved.scope);
    }

    @Test
    @Transactional
    public void testCoachAndNutritionScopesAreIndependent() {
        Long userId = 9983L;

        AiRateLimit nutritionLimit = new AiRateLimit();
        nutritionLimit.userId = userId;
        nutritionLimit.scope = "nutrition";
        nutritionLimit.requestCount = 20;
        nutritionLimit.windowStart = java.time.LocalDateTime.now();
        nutritionLimit.persist();

        assertTrue(rateLimiter.tryAcquire(userId, false), "Coach bucket should remain independent from nutrition");
    }
}
