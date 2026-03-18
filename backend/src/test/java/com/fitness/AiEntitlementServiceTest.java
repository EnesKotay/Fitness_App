package com.fitness;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.fitness.entity.AiRateLimit;
import com.fitness.service.AiEntitlementService;

import io.quarkus.test.junit.QuarkusTest;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

@QuarkusTest
public class AiEntitlementServiceTest {

    @Inject
    AiEntitlementService entitlementService;

    @BeforeEach
    @Transactional
    public void setup() {
        AiRateLimit.deleteAll();
    }

    @Test
    public void testFreeCoachDailyLimitAllowsOnlyTwoRequests() {
        Long userId = 9921L;

        assertTrue(entitlementService.tryConsumeFreeCoachRequest(userId));
        assertTrue(entitlementService.tryConsumeFreeCoachRequest(userId));
        assertFalse(entitlementService.tryConsumeFreeCoachRequest(userId));
        assertEquals(0, entitlementService.remainingFreeCoachRequests(userId));
    }

    @Test
    public void testRefundRestoresQuota() {
        Long userId = 9922L;

        assertTrue(entitlementService.tryConsumeFreeCoachRequest(userId));
        assertEquals(1, entitlementService.remainingFreeCoachRequests(userId));

        entitlementService.refundFreeCoachRequest(userId);

        assertEquals(2, entitlementService.remainingFreeCoachRequests(userId));
        assertTrue(entitlementService.tryConsumeFreeCoachRequest(userId));
    }
}
