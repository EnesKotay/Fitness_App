package com.fitness.service;

import com.fitness.entity.User;
import com.fitness.entity.AiFeedback;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.transaction.Transactional;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Kullanıcının fitness bilgi seviyesini öğrenir ve AI Coach'un cevaplarını
 * buna göre ayarlar (Adaptive Learning).
 *
 * Bilgi seviyeleri:
 * - BEGINNER: Temel terimleri bilmiyor (örn: "BMR nedir?")
 * - INTERMEDIATE: Bazı kavramları biliyor ama detay istiyor
 * - ADVANCED: İleri seviye, bilimsel açıklama bekliyor
 */
@ApplicationScoped
public class AdaptiveLearningService {

    // Kullanıcının sorduğu soruların analizi ile bilgi seviyesini tespit eder
    public String assessKnowledgeLevel(Long userId) {
        User user = User.findById(userId);
        if (user == null) return "INTERMEDIATE";

        // Son 30 günlük feedback ve soru geçmişine bak
        LocalDateTime cutoff = LocalDateTime.now().minusDays(30);
        List<AiFeedback> recentFeedback = AiFeedback.find(
            "userId = ?1 AND createdAt >= ?2 ORDER BY createdAt DESC",
            userId,
            cutoff
        ).list();

        if (recentFeedback.isEmpty()) {
            return "INTERMEDIATE"; // Varsayılan
        }

        int beginnerSignals = 0;
        int advancedSignals = 0;

        for (AiFeedback fb : recentFeedback) {
            String question = fb.userQuestion != null ? fb.userQuestion.toLowerCase() : "";

            // Beginner sinyalleri: Temel sorular
            if (question.contains("nedir") || question.contains("ne demek") ||
                question.contains("nasıl yapılır") || question.contains("ne işe yarar")) {
                beginnerSignals++;
            }

            // Advanced sinyalleri: Detaylı/bilimsel sorular
            if (question.contains("ne kadar etkili") || question.contains("araştırma") ||
                question.contains("bilimsel") || question.contains("metabolizma") ||
                question.contains("hipertrofi") || question.contains("periodizasyon")) {
                advancedSignals++;
            }
        }

        // Karar mantığı
        if (beginnerSignals > advancedSignals * 2) {
            return "BEGINNER";
        } else if (advancedSignals > beginnerSignals * 1.5) {
            return "ADVANCED";
        } else {
            return "INTERMEDIATE";
        }
    }

    /**
     * Bilgi seviyesine göre prompt'a ekstra talimat ekler.
     */
    public String buildLearningModeInstruction(String knowledgeLevel) {
        if (knowledgeLevel == null) knowledgeLevel = "INTERMEDIATE";

        return switch (knowledgeLevel.toUpperCase()) {
            case "BEGINNER" -> """
                --- ADAPTIVE LEARNING: BEGINNER MODE ---
                The user is new to fitness. Your communication rules:
                - Explain technical terms when you use them (e.g., "BMR (Basal Metabolic Rate) - vücudun dinlenirken yaktığı kalori")
                - Use simple analogies and avoid jargon
                - Break down complex concepts into bite-sized steps
                - Encourage questions: "Bu konuda başka merak ettiğin var mı?"
                - Be extra patient and supportive
                """;
            case "ADVANCED" -> """
                --- ADAPTIVE LEARNING: ADVANCED MODE ---
                The user has deep fitness knowledge. Your communication rules:
                - Use technical terminology freely (progressive overload, glycogen depletion, EPOC)
                - Reference scientific studies when relevant (no need to cite, just say "araştırmalar gösteriyor ki...")
                - Skip basic explanations — assume they know fundamentals
                - Provide nuanced, evidence-based answers
                - Challenge them with advanced tactics (periodization, deloads, nutrient timing)
                """;
            default -> """
                --- ADAPTIVE LEARNING: INTERMEDIATE MODE ---
                The user has moderate fitness knowledge. Your communication rules:
                - Balance between simple and technical language
                - Explain technical terms briefly when first used
                - Assume they know basics (e.g., protein builds muscle) but give context for advanced concepts
                - Provide actionable steps with light scientific backing
                """;
        };
    }

    /**
     * Kullanıcının öğrenme ilerlemesini kaydet.
     * Örneğin: "BMR nedir?" sorusunu 3 ay önce sordu, şimdi "TDEE hesabım doğru mu?" soruyor
     * → İlerleme var, tebrik et!
     */
    @Transactional
    public String detectLearningProgress(Long userId, String currentQuestion) {
        List<AiFeedback> history = AiFeedback.find(
            "userId = ?1 ORDER BY createdAt ASC",
            userId
        ).list();

        if (history.size() < 5) return "";

        // İlk 5 soru ile son 5 soruyu karşılaştır
        List<AiFeedback> early = history.subList(0, Math.min(5, history.size()));
        List<AiFeedback> recent = history.subList(Math.max(0, history.size() - 5), history.size());

        int earlyBeginnerCount = countBeginnerQuestions(early);
        int recentBeginnerCount = countBeginnerQuestions(recent);

        if (earlyBeginnerCount >= 3 && recentBeginnerCount <= 1) {
            return """
                🎓 İlerleme Tespiti: Kullanıcı başlangıçta temel sorular soruyordu, şimdi daha ileri seviye sorular soruyor.
                → Cevabının başında kısa bir tebrik ekle: "Bu arada, sorularının kalitesi gerçekten gelişmiş! 🎯"
                """;
        }

        return "";
    }

    private int countBeginnerQuestions(List<AiFeedback> feedbacks) {
        int count = 0;
        for (AiFeedback fb : feedbacks) {
            String q = fb.userQuestion != null ? fb.userQuestion.toLowerCase() : "";
            if (q.contains("nedir") || q.contains("ne demek") || q.contains("nasıl yapılır")) {
                count++;
            }
        }
        return count;
    }

    /**
     * Frontend'e göstermek için kullanıcının öğrenme istatistiklerini döner.
     */
    public Map<String, Object> getLearningStats(Long userId) {
        Map<String, Object> stats = new HashMap<>();

        String level = assessKnowledgeLevel(userId);
        stats.put("knowledgeLevel", level);
        stats.put("levelLabel", getLevelLabel(level));
        stats.put("levelEmoji", getLevelEmoji(level));

        // Son 30 gün içinde kaç soru sordu?
        LocalDateTime cutoff = LocalDateTime.now().minusDays(30);
        long questionCount = AiFeedback.count(
            "userId = ?1 AND createdAt >= ?2",
            userId,
            cutoff
        );
        stats.put("questionsAsked30d", questionCount);

        // Pozitif feedback oranı
        long positiveCount = AiFeedback.count(
            "userId = ?1 AND createdAt >= ?2 AND reaction = 'POSITIVE'",
            userId,
            cutoff
        );
        double satisfactionRate = questionCount > 0
            ? (positiveCount * 100.0 / questionCount)
            : 0.0;
        stats.put("satisfactionRate", String.format("%.0f%%", satisfactionRate));

        return stats;
    }

    private String getLevelLabel(String level) {
        return switch (level.toUpperCase()) {
            case "BEGINNER" -> "Başlangıç";
            case "ADVANCED" -> "İleri Seviye";
            default -> "Orta Seviye";
        };
    }

    private String getLevelEmoji(String level) {
        return switch (level.toUpperCase()) {
            case "BEGINNER" -> "🌱";
            case "ADVANCED" -> "🏆";
            default -> "💪";
        };
    }
}
