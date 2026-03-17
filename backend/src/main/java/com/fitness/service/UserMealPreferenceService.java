package com.fitness.service;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.jboss.logging.Logger;

import com.fitness.entity.AiUserPreference;

import io.quarkus.hibernate.orm.panache.PanacheQuery;
import io.quarkus.panache.common.Sort;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;

/**
 * Database-backed storage for user meal preferences.
 * Stores last 20 preferences per user for taste profile learning.
 */
@ApplicationScoped
public class UserMealPreferenceService {

    private static final Logger LOG = Logger.getLogger(UserMealPreferenceService.class);
    private static final int MAX_PREFERENCES_PER_USER = 20;

    /**
     * Record a user meal preference when they add a meal to diary
     */
    @Transactional
    public void recordPreference(Long userId, String mealName, List<String> tags, String mealType) {
        if (userId == null)
            return;

        AiUserPreference pref = new AiUserPreference();
        pref.userId = userId;
        pref.mealName = mealName;
        pref.tags = (tags != null && !tags.isEmpty()) ? String.join(",", tags) : "";
        pref.mealType = mealType;
        pref.createdAt = LocalDateTime.now();
        pref.persist();

        // Cleanup old preferences if exceeding limit
        PanacheQuery<AiUserPreference> query = AiUserPreference.find("userId", Sort.descending("createdAt"), userId);
        if (query.count() > MAX_PREFERENCES_PER_USER) {
            List<AiUserPreference> toDelete = query.range(MAX_PREFERENCES_PER_USER, Integer.MAX_VALUE).list();
            toDelete.forEach(AiUserPreference::delete);
        }

        LOG.debugf("Recorded preference for user %d: %s", userId, mealName);
    }

    /**
     * Get summary of user preferences for prompt injection
     * Returns most frequent tags and meal types
     */
    public String getPreferenceSummary(Long userId) {
        if (userId == null)
            return "";

        List<AiUserPreference> preferences = AiUserPreference.find("userId", Sort.descending("createdAt"), userId)
                .range(0, MAX_PREFERENCES_PER_USER - 1)
                .list();

        if (preferences.isEmpty()) {
            return "";
        }

        // Count tags
        Map<String, Integer> tagCounts = new HashMap<>();
        Map<String, Integer> mealTypeCounts = new HashMap<>();

        for (AiUserPreference pref : preferences) {
            if (pref.tags != null && !pref.tags.isEmpty()) {
                String[] tags = pref.tags.split(",");
                for (String tag : tags) {
                    tagCounts.merge(tag.trim().toLowerCase(), 1, Integer::sum);
                }
            }
            if (pref.mealType != null) {
                mealTypeCounts.merge(pref.mealType, 1, Integer::sum);
            }
        }

        // Get top 5 tags
        List<String> topTags = tagCounts.entrySet().stream()
                .sorted(Map.Entry.<String, Integer>comparingByValue().reversed())
                .limit(5)
                .map(Map.Entry::getKey)
                .collect(Collectors.toList());

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
            if (sb.length() > 0)
                sb.append(". ");
            sb.append("En sık tercih edilen öğün: ").append(topMealType);
        }

        return sb.toString();
    }
}
