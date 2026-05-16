package com.fitness.service;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import org.jboss.logging.Logger;

import com.fitness.entity.Meal;
import com.fitness.entity.Notification;
import com.fitness.entity.User;
import com.fitness.entity.WeightRecord;
import com.fitness.entity.Workout;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.quarkus.scheduler.Scheduled;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;

/**
 * Scheduled service that analyzes user data and generates proactive AI feedback.
 * Runs daily at 21:00 with 10+ personalized triggers.
 */
@ApplicationScoped
public class AiProactiveService {

    private static final Logger LOG = Logger.getLogger(AiProactiveService.class);

    @Inject
    GeminiClient geminiClient;

    @Inject
    ObjectMapper objectMapper;

    @Inject
    SemanticMemoryService semanticMemoryService;

    @Scheduled(cron = "0 0 21 * * ?")
    @Transactional
    public void runDailyAnalysis() {
        LOG.info("Starting proactive daily AI analysis...");
        List<User> users = User.listAll();
        for (User user : users) {
            try {
                analyzeAndNotify(user);
            } catch (Exception e) {
                LOG.warnf("Proactive analysis failed for user %d: %s", user.id, e.getMessage());
            }
        }
    }

    @Transactional
    public void analyzeAndNotify(User user) {
        LocalDate today = LocalDate.now();
        LocalDateTime startOfDay = today.atStartOfDay();
        LocalDateTime endOfDay = today.plusDays(1).atStartOfDay();

        List<Meal> todayMeals = Meal.find(
                "user.id = ?1 and mealDate >= ?2 and mealDate < ?3",
                user.id, startOfDay, endOfDay).list();
        List<Workout> todayWorkouts = Workout.find(
                "user.id = ?1 and workoutDate >= ?2 and workoutDate < ?3",
                user.id, startOfDay, endOfDay).list();

        // — Trigger 1: Protein hedefi (dinamik — ağırlık bazlı) —
        double proteinGoal = calculateProteinGoal(user);
        double totalProtein = todayMeals.stream().mapToDouble(m -> m.protein).sum();
        if (!todayMeals.isEmpty() && totalProtein < proteinGoal * 0.65) {
            double remaining = proteinGoal - totalProtein;
            generateNotification(user, "PROTEIN_DEFICIENCY",
                    String.format("Kullanıcı bugün %.0fg protein aldı, hedefi %.0fg. %.0fg açık var. " +
                                  "Kısa ve pratik bir akşam atıştırmalığı öner (yoğurt, yumurta, lor gibi).",
                                  totalProtein, proteinGoal, remaining));
        }

        // — Trigger 2: 3 günlük antrenman yokluğu —
        long workoutlessStreak = countDaysWithoutWorkout(user.id, today);
        if (workoutlessStreak >= 3 && todayWorkouts.isEmpty()) {
            generateNotification(user, "STREAK_RISK",
                    String.format("Kullanıcı %d gündür antrenman yapmadı. " +
                                  "Yumuşak ama motive edici bir şekilde harekete geç — sadece 20 dakikalık ev egzersizi bile yeterli.", workoutlessStreak));
        }

        // — Trigger 3: Kalori hedefini 5 gün tutturma kutlaması —
        if (hasMetCalorieGoalFor(user.id, 5)) {
            generateNotification(user, "CALORIE_STREAK",
                    "Kullanıcı 5 gün üst üste kalori hedefini tutturdu. " +
                    "Bunu gerçekten kutla — kısa, samimi, özgün bir mesaj yaz.");
        }

        // — Trigger 4: Hedef kiloya yaklaşma (≤2 kg) —
        if (user.weight != null && user.targetWeight != null) {
            double diff = Math.abs(user.targetWeight - user.weight);
            if (diff <= 2.0 && diff > 0.0) {
                generateNotification(user, "GOAL_PROXIMITY",
                        String.format("Kullanıcı hedef kilosuna %.1f kg kaldı. " +
                                      "Bunu özel hissettir — final aşaması için somut 1-2 ipucu ver.", diff));
            }
        }

        // — Trigger 5: Hedef kiloya ulaşma —
        if (user.weight != null && user.targetWeight != null
                && Math.abs(user.targetWeight - user.weight) < 0.3) {
            generateNotification(user, "GOAL_REACHED",
                    "Kullanıcı hedef kilosuna ulaştı! Bunu büyük bir başarı olarak kutla, " +
                    "ve yeni bir hedef belirlemesini öner.");
        }

        // — Trigger 6: Aşırı antrenman uyarısı (7 günde 6+ antrenman) —
        long weeklyWorkouts = countWorkoutsLastDays(user.id, 7);
        if (weeklyWorkouts >= 6) {
            generateNotification(user, "OVERTRAINING_WARNING",
                    String.format("Kullanıcı son 7 günde %d antrenman yaptı — aşırı antrenman riski var. " +
                                  "Bilimsel açıdan, dinlenme günlerinin önemini kısaca açıkla.", weeklyWorkouts));
        }

        // — Trigger 7: Kilo takibi 5 gündür yapılmamış —
        long daysSinceWeighIn = daysSinceLastWeightRecord(user.id);
        if (daysSinceWeighIn >= 5) {
            generateNotification(user, "WEIGH_IN_REMINDER",
                    "Kullanıcı 5 gündür kilo kaydı yapmadı. " +
                    "Kısa, baskı yapmayan bir hatırlatıcı yaz — düzenli takibin motivasyona katkısını vurgula.");
        }

        // — Trigger 8: Su tüketimi düşük —
        // Not: backend'deki Meal entity'si henüz su tüketimi alanı taşımıyor.
        // Bu trigger, hydration verisi kalıcı modele eklendiğinde yeniden açılmalı.

        // — Trigger 9: Hafta sonu hareketsizlik —
        boolean isWeekend = today.getDayOfWeek().getValue() >= 6;
        if (isWeekend && todayWorkouts.isEmpty()) {
            generateNotification(user, "WEEKEND_ACTIVITY",
                    "Bugün haftasonu ve kullanıcı henüz aktif değil. " +
                    "Hafif, keyifli bir aktivite öner — yürüyüş, yoga veya kısa ev antrenmanı gibi.");
        }

        // — Trigger 10: Sabah motivasyonu (sadece Pazartesi) —
        if (today.getDayOfWeek().getValue() == 1 && todayWorkouts.isEmpty()) {
            generateNotification(user, "MONDAY_MOTIVATION",
                    "Kullanıcı için Pazartesi motivasyonu. " +
                    "Haftaya güçlü başlamak için 1 somut ve enerji veren eylem planı öner.");
        }

        // — Trigger 11: Kilo kaybı hız trendi (hafta bazlı) —
        checkWeightLossTrend(user);

        // — Trigger 12: Uzun süre giriş yapılmamış (3+ gün) —
        checkInactiveUser(user);
    }

    private void checkWeightLossTrend(User user) {
        List<WeightRecord> recentWeights = WeightRecord
                .find("user.id = ?1 ORDER BY recordedAt DESC", user.id)
                .page(0, 4).list();
        if (recentWeights.size() < 3) return;

        double first = recentWeights.get(recentWeights.size() - 1).weight;
        double latest = recentWeights.get(0).weight;
        double totalChange = latest - first;

        // Save weight trend as semantic memory so AI coach references it
        if (Math.abs(totalChange) >= 1.0) {
            String direction = totalChange < 0 ? "kaybetmiş" : "almış";
            String fact = String.format(
                "Son 4 kilo ölçümünde kullanıcı %.1f kg %s (%.1f kg -> %.1f kg).",
                Math.abs(totalChange), direction, first, latest);
            semanticMemoryService.saveMemory(user.id, fact, "WEEKLY_PROGRESS");
        }

        // Alert if losing too fast (> 1.5 kg/week is risky)
        long daySpan = java.time.temporal.ChronoUnit.DAYS.between(
                recentWeights.get(recentWeights.size() - 1).recordedAt.toLocalDate(),
                recentWeights.get(0).recordedAt.toLocalDate());
        if (daySpan > 0 && totalChange < -1.5 * (daySpan / 7.0)) {
            generateNotification(user, "FAST_WEIGHT_LOSS",
                    String.format("Kullanıcı son %d günde %.1f kg kaybetti — fazla hızlı olabilir. " +
                    "Kas kaybını önlemek için bilimsel bir öneri ver.", daySpan, Math.abs(totalChange)));
        }
    }

    private void checkInactiveUser(User user) {
        LocalDateTime sevenDaysAgo = LocalDate.now().minusDays(7).atStartOfDay();
        long recentActivity = Workout.count("user.id = ?1 AND workoutDate >= ?2", user.id, sevenDaysAgo)
                + Meal.count("user.id = ?1 AND mealDate >= ?2", user.id, sevenDaysAgo);
        if (recentActivity == 0) {
            generateNotification(user, "USER_INACTIVE",
                    "Kullanıcı 7 gündür hiçbir veri girmemiş (ne antrenman ne yemek). " +
                    "Nazikçe geri dön — uygulamaya geri dönmelerini teşvik et, yargılamadan.");
        }
    }

    // ─── Yardımcı hesaplamalar ─────────────────────────────────────────────

    /** Kullanıcının ağırlığına göre dinamik protein hedefi: 1.8g/kg (aktif bireyler için orta değer) */
    private double calculateProteinGoal(User user) {
        if (user.weight != null && user.weight > 30) {
            return user.weight * 1.8;
        }
        return 130.0; // Makul bir fallback
    }

    private long countDaysWithoutWorkout(Long userId, LocalDate until) {
        long streak = 0;
        LocalDate day = until.minusDays(1); // Dünden başla
        while (streak < 14) {
            LocalDateTime start = day.atStartOfDay();
            LocalDateTime end = day.plusDays(1).atStartOfDay();
            long count = Workout.count("user.id = ?1 AND workoutDate >= ?2 AND workoutDate < ?3", userId, start, end);
            if (count > 0) break;
            streak++;
            day = day.minusDays(1);
        }
        return streak;
    }

    private boolean hasMetCalorieGoalFor(Long userId, int days) {
        // Basit proxy: son N gün her gün meal girişi var mı
        for (int i = 1; i <= days; i++) {
            LocalDate day = LocalDate.now().minusDays(i);
            long count = Meal.count("user.id = ?1 AND mealDate >= ?2 AND mealDate < ?3",
                    userId, day.atStartOfDay(), day.plusDays(1).atStartOfDay());
            if (count == 0) return false;
        }
        return true;
    }

    private long countWorkoutsLastDays(Long userId, int days) {
        LocalDateTime from = LocalDate.now().minusDays(days).atStartOfDay();
        return Workout.count("user.id = ?1 AND workoutDate >= ?2", userId, from);
    }

    private long daysSinceLastWeightRecord(Long userId) {
        List<WeightRecord> records = WeightRecord
                .find("user.id = ?1 ORDER BY recordedAt DESC", userId)
                .page(0, 1).list();
        if (records.isEmpty()) return 999;
        return java.time.temporal.ChronoUnit.DAYS.between(
                records.get(0).recordedAt.toLocalDate(), LocalDate.now());
    }

    // ─── AI mesajı üretimi ────────────────────────────────────────────────

    private void generateNotification(User user, String type, String context) {
        // Aynı tip bildirim bugün zaten gönderildiyse tekrar göndermé
        LocalDateTime startOfDay = LocalDate.now().atStartOfDay();
        long existing = Notification.count(
                "user.id = ?1 AND type = ?2 AND createdAt >= ?3",
                user.id, type, startOfDay);
        if (existing > 0) return;

        String prompt = "Sen akıllı bir fitness koçusun. Senaryo: " + context +
                "\nKullanıcı adı: " + (user.name != null ? user.name : "Kullanıcı") +
                "\nYalnızca kısa (max 2 cümle), kişisel, aksiyon odaklı Türkçe bir push bildirim mesajı üret. " +
                "Emoji kullan. Jenerik veya robotik olma.";

        try {
            GeminiClientResult result = geminiClient.generateText(
                    "proactive_alert", user.id, "gemini-2.5-flash", "gemini-2.0-flash", prompt, false);

            if (result.isSuccess()) {
                String msg = extractPlainText(result.getOutputText());
                if (msg.isEmpty()) return;
                if (msg.length() > 250) msg = msg.substring(0, 250);

                Notification notification = new Notification();
                notification.user = user;
                notification.title = titleForType(type);
                notification.message = msg;
                notification.type = type;
                notification.persist();
                LOG.infof("Proactive notification created userId=%d type=%s", user.id, type);
            }
        } catch (Exception e) {
            LOG.warnf("Failed to generate notification userId=%d type=%s: %s", user.id, type, e.getMessage());
        }
    }

    /**
     * Strips JSON wrapping if the model accidentally returns structured output instead of plain text.
     * Tries to extract "todayFocus" first, falls back to raw text after removing markdown fences.
     */
    private String extractPlainText(String raw) {
        if (raw == null) return "";
        String trimmed = raw.trim();

        // Extract JSON block if it exists
        int firstBrace = trimmed.indexOf('{');
        int lastBrace = trimmed.lastIndexOf('}');
        
        if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
            String possibleJson = trimmed.substring(firstBrace, lastBrace + 1);
            try {
                JsonNode node = objectMapper.readTree(possibleJson);
                for (String field : new String[]{"todayFocus", "message", "content", "text"}) {
                    JsonNode n = node.get(field);
                    if (n != null && n.isTextual() && !n.asText().isBlank()) {
                        return n.asText().trim();
                    }
                }
            } catch (Exception ignored) {
                // Not valid JSON — fall through
            }
        }

        // If not JSON, try to strip markdown code fences
        if (trimmed.startsWith("```")) {
            int firstNewline = trimmed.indexOf('\n');
            int lastFence = trimmed.lastIndexOf("```");
            if (firstNewline > 0 && lastFence > firstNewline) {
                trimmed = trimmed.substring(firstNewline + 1, lastFence).trim();
            }
        }

        return trimmed;
    }

    private String titleForType(String type) {
        return switch (type) {
            case "PROTEIN_DEFICIENCY"  -> "💪 Protein Hatırlatıcısı";
            case "STREAK_RISK"         -> "🔥 Antrenman Serisi";
            case "CALORIE_STREAK"      -> "🎯 Harika Gidiyorsun!";
            case "GOAL_PROXIMITY"      -> "🏁 Hedefe Yaklaştın!";
            case "GOAL_REACHED"        -> "🏆 Tebrikler!";
            case "OVERTRAINING_WARNING"-> "⚠️ Dinlenme Zamanı";
            case "WEIGH_IN_REMINDER"   -> "⚖️ Kilo Takibi";
            case "LOW_HYDRATION"       -> "💧 Su İçmeyi Unutma";
            case "WEEKEND_ACTIVITY"    -> "🌟 Hadi Hareket Et!";
            case "MONDAY_MOTIVATION"   -> "🚀 Haftaya Güçlü Başla";
            case "FAST_WEIGHT_LOSS"    -> "⚡ Kilo Değişimi";
            case "USER_INACTIVE"       -> "👋 Seni Özledik!";
            default                    -> "🤖 AI Koç";
        };
    }
}
