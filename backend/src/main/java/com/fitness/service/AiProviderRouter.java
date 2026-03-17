package com.fitness.service;

import java.time.LocalDateTime;

import org.jboss.logging.Logger;

import com.fitness.entity.User;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Routes AI requests to the appropriate provider based on user's premium tier.
 * <ul>
 *   <li>Premium users → ClaudeClient (Anthropic). If Claude is not configured (no API key), falls back to Gemini.</li>
 *   <li>Free users → GeminiClient only, with stricter rate limits (see AiCoachRateLimiter).</li>
 * </ul>
 * Both paths return the same response shape (e.g. todayFocus, actionItems, nutritionNote) so the app works seamlessly.
 */
@ApplicationScoped
public class AiProviderRouter {

    private static final Logger LOG = Logger.getLogger(AiProviderRouter.class);

    @Inject
    GeminiClient geminiClient;

    @Inject
    ClaudeClient claudeClient;

    /**
     * Check if a user has active premium subscription.
     */
    public boolean isPremium(Long userId) {
        if (userId == null)
            return false;
        User user = User.findById(userId);
        if (user == null)
            return false;
        if (!"premium".equalsIgnoreCase(user.premiumTier))
            return false;
        // Check expiry
        if (user.premiumExpiresAt != null && user.premiumExpiresAt.isBefore(LocalDateTime.now())) {
            return false;
        }
        return true;
    }

    /**
     * Get the user's premium tier string.
     */
    public String getTier(Long userId) {
        return isPremium(userId) ? "premium" : "free";
    }

    // ─── Text generation routing ─────────────────────────────────

    /**
     * Route text generation to the appropriate provider.
     * Premium → Claude, Free → Gemini (with model fallback).
     */
    public GeminiClientResult generateText(
            String endpointName,
            Long userId,
            String primaryModel,
            String fallbackModel,
            String prompt,
            boolean expectJson) {

        if (isPremium(userId) && claudeClient.isAvailable()) {
            LOG.infof("Routing to Claude (premium) endpoint=%s userId=%d", endpointName, userId);
            return claudeClient.generateText(endpointName, userId, prompt, expectJson);
        }

        // Free tier → Gemini, or premium when Claude is not configured
        geminiClient.validateApiKey();
        return geminiClient.generateText(endpointName, userId, primaryModel, fallbackModel, prompt, expectJson);
    }

    /**
     * Route vision/image generation to the appropriate provider.
     */
    public GeminiClientResult generateWithImage(
            String endpointName,
            Long userId,
            String primaryModel,
            String fallbackModel,
            String prompt,
            byte[] imageBytes,
            String mimeType,
            boolean expectJson) {

        if (isPremium(userId) && claudeClient.isAvailable()) {
            LOG.infof("Routing to Claude Vision (premium) endpoint=%s userId=%d", endpointName, userId);
            return claudeClient.generateWithImage(endpointName, userId, prompt, imageBytes, mimeType, expectJson);
        }

        // Free tier → Gemini, or premium when Claude is not configured
        geminiClient.validateApiKey();
        return geminiClient.generateWithImage(
                endpointName, userId, primaryModel, fallbackModel, prompt, imageBytes, mimeType, expectJson);
    }

    /**
     * Extract JSON from raw response (provider-agnostic).
     */
    public String extractJsonFromResponse(Long userId, String rawResponse) {
        if (isPremium(userId) && claudeClient.isAvailable()) {
            return claudeClient.extractJsonFromResponse(rawResponse);
        }
        return geminiClient.extractJsonFromResponse(rawResponse);
    }
}
