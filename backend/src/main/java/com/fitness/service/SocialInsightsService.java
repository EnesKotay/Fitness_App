package com.fitness.service;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.fitness.entity.User;
import com.fitness.entity.Workout;
import com.fitness.repository.UserRepository;
import com.fitness.repository.WorkoutRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Sosyal içgörüler - benzer kullanıcıların ne yaptığını gösterir.
 * "Senin gibi kullanıcılar şu an bunu yapıyor" tarzı community insights.
 */
@ApplicationScoped
public class SocialInsightsService {

    @Inject
    UserRepository userRepository;

    @Inject
    WorkoutRepository workoutRepository;

    /**
     * Benzer kullanıcıların trendlerini analiz eder.
     */
    public CommunityTrends analyzeTrends(Long userId) {
        User user = User.findById(userId);
        if (user == null) {
            return new CommunityTrends(false, "Kullanıcı bulunamadı", null);
        }

        // Benzer kullanıcıları bul (aynı hedef + yakın kilo)
        List<User> similarUsers = userRepository.find(
            "goal = ?1 AND weight BETWEEN ?2 AND ?3 AND id != ?4",
            user.goal,
            user.weight - 10,
            user.weight + 10,
            userId
        ).list();

        if (similarUsers.size() < 5) {
            return new CommunityTrends(false, "Yeterli benzer kullanıcı yok", null);
        }

        // Son 7 gündeki en popüler egzersizler
        LocalDateTime sevenDaysAgo = LocalDateTime.now().minusDays(7);
        List<Long> similarUserIds = similarUsers.stream().map(u -> u.id).collect(Collectors.toList());

        List<Workout> recentWorkouts = workoutRepository.find(
            "user.id IN ?1 AND workoutDate >= ?2",
            similarUserIds, sevenDaysAgo
        ).list();

        // Egzersiz popülerlik skoru
        Map<String, Integer> exerciseCounts = new HashMap<>();
        for (Workout w : recentWorkouts) {
            if (w.name != null) {
                exerciseCounts.merge(w.name, 1, Integer::sum);
            }
        }

        List<String> topExercises = exerciseCounts.entrySet().stream()
            .sorted((a, b) -> b.getValue().compareTo(a.getValue()))
            .limit(5)
            .map(Map.Entry::getKey)
            .collect(Collectors.toList());

        // Ortalama haftalık antrenman sayısı
        double avgWorkoutsPerWeek = (double) recentWorkouts.size() / similarUsers.size();

        Map<String, Object> insights = new HashMap<>();
        insights.put("similarUserCount", similarUsers.size());
        insights.put("topExercises", topExercises);
        insights.put("avgWorkoutsPerWeek", Math.round(avgWorkoutsPerWeek * 10) / 10.0);

        StringBuilder summary = new StringBuilder();
        summary.append(String.format("👥 Senin gibi %d kullanıcı var (%s hedefi, ~%.0f kg).\n\n",
            similarUsers.size(), user.goal, user.weight));
        summary.append("**Son 7 günde en popüler egzersizler:**\n");
        for (String exercise : topExercises) {
            summary.append(String.format("- %s\n", exercise));
        }
        summary.append(String.format("\n**Ortalama:** Haftada %.1f antrenman yapıyorlar.\n", avgWorkoutsPerWeek));

        return new CommunityTrends(true, summary.toString(), insights);
    }

    /**
     * AI prompt için sosyal bağlam.
     */
    public String buildSocialContext(Long userId) {
        CommunityTrends trends = analyzeTrends(userId);
        if (!trends.trendsFound) {
            return "";
        }

        StringBuilder context = new StringBuilder();
        context.append("\n## SOSYAL İÇGÖRÜLER (Community Insights)\n\n");
        context.append(trends.summary).append("\n");
        context.append("**AI Talimatı:** Kullanıcıya benzer kişilerin ne yaptığını göster, " +
            "ama zorla değil, ilham verici şekilde sun. 'Senin gibi insanlar şu an bunu yapıyor' şeklinde.\n");

        return context.toString();
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────────

    public static class CommunityTrends {
        public boolean trendsFound;
        public String summary;
        public Map<String, Object> insights;

        public CommunityTrends(boolean trendsFound, String summary, Map<String, Object> insights) {
            this.trendsFound = trendsFound;
            this.summary = summary;
            this.insights = insights;
        }
    }
}
