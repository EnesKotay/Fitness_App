package com.fitness.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import com.fitness.entity.User;
import com.fitness.entity.WorkoutSession;
import com.fitness.repository.WorkoutSessionRepository;
import com.fitness.service.HabitLearningService.HabitAnalysis;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Akıllı hatırlatıcı servisi.
 * Kullanıcının alışkanlıklarına ve davranışlarına göre optimal zamanda hatırlatma yapar.
 */
@ApplicationScoped
public class SmartReminderService {

    @Inject
    HabitLearningService habitLearningService;

    @Inject
    WorkoutSessionRepository workoutSessionRepository;

    @Inject
    WorkoutAnalysisService workoutAnalysisService;

    /**
     * Kullanıcı için bugün hatırlatıcı gerekli mi?
     */
    public ReminderDecision shouldRemindToday(Long userId) {
        User user = User.findById(userId);
        if (user == null) {
            return new ReminderDecision(false, null, null);
        }

        // 1. Alışkanlık sapması kontrolü
        var deviation = habitLearningService.checkForDeviation(userId);
        if (deviation.isDeviating) {
            return new ReminderDecision(
                true,
                ReminderType.HABIT_DEVIATION,
                deviation.message
            );
        }

        // 2. Uzun süre hareketsizlik (3+ gün)
        LocalDate threeDaysAgo = LocalDate.now().minusDays(3);
        List<WorkoutSession> recentSessions = workoutSessionRepository.find(
            "user.id = ?1 AND DATE(finishedAt) >= ?2",
            userId, threeDaysAgo
        ).list();

        if (recentSessions.isEmpty()) {
            // Recovery check - toparlanmış mı?
            var deload = workoutAnalysisService.calculateDeloadNeed(userId);
            if (deload.needsDeload) {
                return new ReminderDecision(
                    true,
                    ReminderType.NEED_DELOAD,
                    "⚠️ 3 gündür antrenman yapmadın ama vücudun yorgun. Bugün hafif bir yürüyüş yap, ağır antrenman değil."
                );
            }

            return new ReminderDecision(
                true,
                ReminderType.INACTIVITY,
                "💪 3 gündür antrenman yapmadın ve toparlanmışsın! Bugün harika bir gün, hadi başla!"
            );
        }

        // 3. Streak desteği (günlük seri devam ediyor)
        if (recentSessions.size() >= 3) {
            return new ReminderDecision(
                true,
                ReminderType.STREAK_MOTIVATION,
                "🔥 3 gündür harika gidiyorsun! Momentum'u kaybetme, bugün de yap!"
            );
        }

        return new ReminderDecision(false, null, null);
    }

    /**
     * AI prompt için reminder bağlamı.
     */
    public String buildReminderContext(Long userId) {
        ReminderDecision decision = shouldRemindToday(userId);
        if (!decision.shouldRemind) {
            return "";
        }

        StringBuilder context = new StringBuilder();
        context.append("\n## AKILLI HATIRLATICI BAĞLAMI\n\n");
        context.append(String.format("**Hatırlatıcı Tipi:** %s\n", decision.type.displayName));
        context.append(String.format("**Mesaj:** %s\n\n", decision.message));

        context.append("**AI Talimatı:**\n");
        context.append(decision.type.aiGuidance).append("\n");

        return context.toString();
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────────

    public static class ReminderDecision {
        public boolean shouldRemind;
        public ReminderType type;
        public String message;

        public ReminderDecision(boolean shouldRemind, ReminderType type, String message) {
            this.shouldRemind = shouldRemind;
            this.type = type;
            this.message = message;
        }
    }

    public enum ReminderType {
        HABIT_DEVIATION(
            "Alışkanlık Sapması",
            "Kullanıcı normalde bu gün antrenman yapıyor ama bugün yapmadı. Nazikçe hatırlat."
        ),
        INACTIVITY(
            "Hareketsizlik",
            "3+ gün antrenman yapmamış. Motive et, bugün başlamasını sağla."
        ),
        NEED_DELOAD(
            "Deload Gerekli",
            "Uzun süre antrenman yapmamış ama yorgun. Hafif aktivite öner, ağır antrenman önerme."
        ),
        STREAK_MOTIVATION(
            "Seri Desteği",
            "Kullanıcı günlük seri yapıyor (3+ gün üst üste). Momentum kaybetmesin, motive et."
        );

        public final String displayName;
        public final String aiGuidance;

        ReminderType(String displayName, String aiGuidance) {
            this.displayName = displayName;
            this.aiGuidance = aiGuidance;
        }
    }
}
