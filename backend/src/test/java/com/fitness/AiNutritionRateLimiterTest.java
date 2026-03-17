package com.fitness;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.fitness.entity.AiRateLimit;
import com.fitness.service.AiNutritionRateLimiter;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@QuarkusTest
public class AiNutritionRateLimiterTest {

    @Inject
    AiNutritionRateLimiter rateLimiter;

    @BeforeEach
    @Transactional
    public void setup() {
        AiRateLimit.deleteAll();
    }

    @Test
    public void testFreeTierLimits() {
        Long testUserId = 9991L;
        boolean isPremium = false;

        // Try to acquire 20 times (should succeed)
        for (int i = 0; i < 20; i++) {
            assertTrue(rateLimiter.tryAcquire(testUserId, isPremium), "Request " + (i + 1) + " should be allowed");
        }

        // 21st time should fail
        assertFalse(rateLimiter.tryAcquire(testUserId, isPremium), "21st request should be blocked");

        // Retry after should be > 0
        int retryAfter = rateLimiter.retryAfterSeconds(testUserId, isPremium);
        assertTrue(retryAfter > 0, "Retry after should be positive integer");
    }

    @Test
    public void testPremiumTierLimits() {
        Long testUserId = 9992L;
        boolean isPremium = true;

        // Try to acquire 75 times (should succeed)
        for (int i = 0; i < 75; i++) {
            assertTrue(rateLimiter.tryAcquire(testUserId, isPremium), "Request " + (i + 1) + " should be allowed");
        }

        // 76th time should fail
        assertFalse(rateLimiter.tryAcquire(testUserId, isPremium), "76th request should be blocked");
    }

    @Test
    public void testIndependentBuckets() {
        Long user1 = 9993L;
        Long user2 = 9994L;

        // Exhaust user1 free tier
        for (int i = 0; i < 20; i++) {
            rateLimiter.tryAcquire(user1, false);
        }
        assertFalse(rateLimiter.tryAcquire(user1, false));

        // User2 should still be able to acquire
        assertTrue(rateLimiter.tryAcquire(user2, false));
    }

    @Test
    @Transactional
    public void testUsesNutritionScope() {
        Long userId = 9995L;

        assertTrue(rateLimiter.tryAcquire(userId, false));

        AiRateLimit saved = AiRateLimit.find("userId = ?1 and scope = ?2", userId, "nutrition").firstResult();
        assertEquals("nutrition", saved.scope);
    }
}
