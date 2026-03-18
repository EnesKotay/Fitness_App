package com.fitness.service;

import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

import jakarta.enterprise.context.ApplicationScoped;

/**
 * IP tabanlı auth rate limiter (in-memory, restart sonrası sıfırlanır).
 *
 * Limitler:
 *   login          → 5 istek / 15 dakika
 *   register       → 3 istek / saat
 *   forgot-password→ 3 istek / saat
 */
@ApplicationScoped
public class AuthRateLimiter {

    private static final int LOGIN_MAX       = 5;
    private static final int LOGIN_WINDOW_S  = 15 * 60;   // 15 dakika

    private static final int REG_MAX         = 3;
    private static final int REG_WINDOW_S    = 60 * 60;   // 1 saat

    private static final int FORGOT_MAX      = 3;
    private static final int FORGOT_WINDOW_S = 60 * 60;   // 1 saat

    // scope → ip → [count, windowStartEpochSec]
    private final ConcurrentHashMap<String, long[]> store = new ConcurrentHashMap<>();

    public boolean allowLogin(String ip)        { return allow(ip, "login",  LOGIN_MAX,  LOGIN_WINDOW_S); }
    public boolean allowRegister(String ip)     { return allow(ip, "reg",    REG_MAX,    REG_WINDOW_S); }
    public boolean allowForgotPassword(String ip) { return allow(ip, "fp",  FORGOT_MAX, FORGOT_WINDOW_S); }

    public int loginRetryAfter(String ip)        { return retryAfter(ip, "login",  LOGIN_WINDOW_S); }
    public int registerRetryAfter(String ip)     { return retryAfter(ip, "reg",    REG_WINDOW_S); }
    public int forgotPasswordRetryAfter(String ip) { return retryAfter(ip, "fp",  FORGOT_WINDOW_S); }

    private boolean allow(String ip, String scope, int maxRequests, int windowSeconds) {
        String key = scope + ":" + ip;
        long now = Instant.now().getEpochSecond();

        store.compute(key, (k, v) -> {
            if (v == null || now - v[1] >= windowSeconds) {
                return new long[]{1, now};
            }
            v[0]++;
            return v;
        });

        long[] entry = store.get(key);
        return entry[0] <= maxRequests;
    }

    private int retryAfter(String ip, String scope, int windowSeconds) {
        String key = scope + ":" + ip;
        long[] entry = store.get(key);
        if (entry == null) return 0;
        long now = Instant.now().getEpochSecond();
        long windowEnd = entry[1] + windowSeconds;
        return (int) Math.max(0, windowEnd - now);
    }
}
