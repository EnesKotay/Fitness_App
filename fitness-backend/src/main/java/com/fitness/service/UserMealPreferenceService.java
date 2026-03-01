package com.fitness.service;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedDeque;

import org.jboss.logging.Logger;

import jakarta.enterprise.context.ApplicationScoped;

/**
 * In-memory storage for user meal preferences.
 * Stores last 20 preferences per user for taste profile learning.
 */
@ApplicationScoped
public class UserMealPreferenceService {

    private static final Logger LOG = Logger.getLogger(UserMealPreferenceService.class);
    private static final int MAX_PREFERENCES_PER_USER = 20;

    // userId -> deque of preferences
    private final Map<Long, Deque<UserMealPreference>> userPreferences = new ConcurrentHashMap<>();

    /**
     * Record a user meal preference when they add a meal to diary
     */
    public void recordPreference(Long userId, String mealName, List<String> tags, String mealType) {
        if (userId == null) return;
        
        UserMealPreference pref = new UserMealPreference();
        pref.mealName = mealName;
        pref.tags = (tags != null) ? new ArrayList<>(tags) : new ArrayList<>();
        pref.mealType = mealType;
        pref.timestamp = Instant.now();

        userPreferences.computeIfAbsent(userId, k -> new ConcurrentLinkedDeque<>());
        
        Deque<UserMealPreference> deque = userPreferences.get(userId);
        synchronized (deque) {
            deque.addFirst(pref);
            // Keep only last MAX_PREFERENCES_PER_USER
            while (deque.size() > MAX_PREFERENCES_PER_USER) {
                deque.removeLast();
            }
        }
        
        LOG.debugf("Recorded preference for user %d: %s", userId, mealName);
    }

    /**
     * Get summary of user preferences for prompt injection
     * Returns most frequent tags and meal types
     */
    public String getPreferenceSummary(Long userId) {
        Deque<UserMealPreference> deque = userPreferences.get(userId);
        if (deque == null || deque.isEmpty()) {
            return "";
        }

        // Count tags
        Map<String, Integer> tagCounts = new HashMap<>();
        Map<String, Integer> mealTypeCounts = new HashMap<>();
        
        synchronized (deque) {
            for (UserMealPreference pref : deque) {
                for (String tag : pref.tags) {
                    tagCounts.merge(tag.toLowerCase(), 1, Integer::sum);
                }
                if (pref.mealType != null) {
                    mealTypeCounts.merge(pref.mealType, 1, Integer::sum);
                }
            }
        }

        // Get top 5 tags
        List<String> topTags = tagCounts.entrySet().stream()
            .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
            .limit(5)
            .map(Map.Entry::getKey)
            .toList();

        // Get most common meal type
        String topMealType = mealTypeCounts.entrySet().stream()
            .max(Map.Entry.comparingByValue())
            .map(Map.Entry::getKey)
            .orElse("");

        // Build summary string
        StringBuilder sb = new StringBuilder();
        if (!topTags.isEmpty()) {
            sb.append("Kullanıcı geçmişte şunları tercih etti: ");
            sb.append(String.join(", ", topTags));
        }
        if (!topMealType.isEmpty()) {
            if (sb.length() > 0) sb.append(". ");
            sb.append("En sık tercih edilen öğün: ").append(topMealType);
        }
        
        return sb.toString();
    }

    /**
     * Inner class for meal preference
     */
    public static class UserMealPreference {
        public String mealName;
        public List<String> tags;
        public String mealType;
        public Instant timestamp;
    }
}
