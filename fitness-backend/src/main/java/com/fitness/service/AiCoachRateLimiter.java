package com.fitness.service;

import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import org.eclipse.microprofile.config.inject.ConfigProperty;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class AiCoachRateLimiter {

    @Inject
    @ConfigProperty(name = "ai.coach.rate-limit.max-requests", defaultValue = "10")
    int maxRequests;

    @Inject
    @ConfigProperty(name = "ai.coach.rate-limit.window-seconds", defaultValue = "300")
    int windowSeconds;

    private final Map<Long, Deque<Long>> requestTimesByUser = new ConcurrentHashMap<>();

    public boolean tryAcquire(Long userId) {
        long now = Instant.now().getEpochSecond();
        long windowStart = now - windowSeconds;

        Deque<Long> queue = requestTimesByUser.computeIfAbsent(userId, ignored -> new ArrayDeque<>());
        synchronized (queue) {
            evictOld(queue, windowStart);
            if (queue.size() >= maxRequests) {
                return false;
            }
            queue.addLast(now);
            return true;
        }
    }

    public int retryAfterSeconds(Long userId) {
        long now = Instant.now().getEpochSecond();
        long windowStart = now - windowSeconds;

        Deque<Long> queue = requestTimesByUser.get(userId);
        if (queue == null) {
            return 0;
        }

        synchronized (queue) {
            evictOld(queue, windowStart);
            if (queue.size() < maxRequests || queue.isEmpty()) {
                return 0;
            }
            long oldest = queue.peekFirst();
            long retryAfter = (oldest + windowSeconds) - now;
            return (int) Math.max(1, retryAfter);
        }
    }

    private void evictOld(Deque<Long> queue, long windowStart) {
        while (!queue.isEmpty() && queue.peekFirst() <= windowStart) {
            queue.removeFirst();
        }
    }
}
