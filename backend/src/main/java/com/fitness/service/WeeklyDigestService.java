package com.fitness.service;

import com.fitness.entity.User;
import com.fitness.entity.WeightRecord;
import com.fitness.entity.Meal;
import com.fitness.entity.Workout;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.time.DayOfWeek;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.OptionalDouble;

/**
 * Kullanıcının haftalık performansını analiz eder ve AI Coach ile
 * kişiselleştirilmiş rapor üretir.
 *
 * Rapor içeriği:
 * - Kilo değişimi ve trend
 * - Ortalama kalori vs hedef
 * - Antrenman sayısı ve dakikası
 * - En iyi ve en zayıf günler
 * - Önümüzdeki hafta için öneriler
 */
@ApplicationScoped
public class WeeklyDigestService {

    @Inject
    GeminiCoachService geminiCoachService;

    @Inject
    AiProviderRouter aiProviderRouter;

    @Inject
    CoachPromptBuilder promptBuilder;

    /**
     * Geçen haftanın (Pazartesi-Pazar) verilerini toplar ve AI ile rapor üretir.
     */
    public Map<String, Object> generateWeeklyDigest(Long userId) {
        User user = User.findById(userId);
        if (user == null) {
            throw new IllegalArgumentException("User not found");
        }

        // Geçen haftanın Pazartesi - Pazar aralığını hesapla
        LocalDate today = LocalDate.now();
        LocalDate lastMonday = today.with(DayOfWeek.MONDAY).minusWeeks(1);
        LocalDate lastSunday = lastMonday.plusDays(6);

        LocalDateTime startOfWeek = lastMonday.atStartOfDay();
        LocalDateTime endOfWeek = lastSunday.atTime(23, 59, 59);

        // Veri toplama
        WeeklyData data = collectWeeklyData(userId, startOfWeek, endOfWeek);

        // AI'ya gönderilecek prompt oluştur
        String aiPrompt = buildWeeklyDigestPrompt(user, data, lastMonday, lastSunday);

        // AI'dan rapor al
        GeminiClientResult result = aiProviderRouter.generateText(
            "weekly-digest",
            userId,
            "gemini-2.5-flash",
            "gemini-2.0-flash",
            aiPrompt,
            null,
            false,
            null
        );

        Map<String, Object> response = new HashMap<>();
        response.put("weekStart", lastMonday.toString());
        response.put("weekEnd", lastSunday.toString());
        response.put("weekLabel", formatWeekLabel(lastMonday, lastSunday));
        response.put("data", data.toMap());

        if (result.isSuccess()) {
            response.put("aiSummary", result.getOutputText().trim());
        } else {
            response.put("aiSummary", "Rapor şu anda oluşturulamadı. Verilerinize aşağıdan göz atabilirsiniz.");
        }

        return response;
    }

    private WeeklyData collectWeeklyData(Long userId, LocalDateTime start, LocalDateTime end) {
        WeeklyData data = new WeeklyData();

        // Kilo değişimi
        List<WeightRecord> weights = WeightRecord.find(
            "user.id = ?1 AND recordedAt >= ?2 AND recordedAt <= ?3 ORDER BY recordedAt ASC",
            userId, start, end
        ).list();

        if (!weights.isEmpty()) {
            data.startWeight = weights.get(0).weight;
            data.endWeight = weights.get(weights.size() - 1).weight;
            data.weightChange = data.endWeight - data.startWeight;
        }

        // Kalori ortalaması
        List<Meal> meals = Meal.find(
            "user.id = ?1 AND mealDate >= ?2 AND mealDate <= ?3",
            userId, start, end
        ).list();

        if (!meals.isEmpty()) {
            OptionalDouble avgCal = meals.stream()
                .mapToDouble(m -> m.calories != null ? m.calories : 0)
                .average();
            data.avgDailyCalories = avgCal.isPresent() ? (int) avgCal.getAsDouble() : 0;
            data.totalMeals = meals.size();
        }

        // Antrenmanlar
        List<Workout> workouts = Workout.find(
            "user.id = ?1 AND workoutDate >= ?2 AND workoutDate <= ?3",
            userId, start, end
        ).list();

        data.totalWorkouts = workouts.size();
        data.totalWorkoutMinutes = workouts.stream()
            .mapToInt(w -> w.durationMinutes != null ? w.durationMinutes : 0)
            .sum();

        // En iyi gün tespiti (en fazla kalori yakılan/en fazla egzersiz yapılan)
        Map<DayOfWeek, Integer> workoutsByDay = new HashMap<>();
        for (Workout w : workouts) {
            DayOfWeek day = w.workoutDate.getDayOfWeek();
            workoutsByDay.put(day, workoutsByDay.getOrDefault(day, 0) + 1);
        }
        data.bestDay = workoutsByDay.entrySet().stream()
            .max(Map.Entry.comparingByValue())
            .map(e -> e.getKey().toString())
            .orElse("YOK");

        // En zayıf gün (hiç antrenman yapılmayan gün sayısı)
        data.restDays = 7 - (int) workoutsByDay.keySet().stream().distinct().count();

        return data;
    }

    private String buildWeeklyDigestPrompt(User user, WeeklyData data, LocalDate start, LocalDate end) {
        return String.format(Locale.US, """
            You are PusulaFit's AI Coach. Generate a personalized weekly performance report in Turkish.

            USER: %s
            WEEK: %s - %s (%s)

            WEEKLY PERFORMANCE DATA:
            - Weight: %.1f kg → %.1f kg (Change: %+.1f kg)
            - Avg Daily Calories: %d kcal
            - Total Meals Logged: %d
            - Total Workouts: %d sessions (%d minutes)
            - Best Day: %s
            - Rest Days: %d

            YOUR TASK:
            Write a motivating, data-driven weekly summary in Turkish (300-500 words). Structure:

            1. **Başlık Emoji + Özet** (🔥, 💪, 📊)
               - Haftanın genel değerlendirmesi (başarılı/orta/zor)

            2. **Dikkat Çeken Başarılar** ✅
               - En önemli kazanım (kilo kaybı, tutarlılık, vs.)

            3. **Gelişim Alanları** 🎯
               - Neyi daha iyi yapabilir? (beslenme tutarlılığı, antrenman sıklığı)

            4. **Önümüzdeki Hafta İçin 3 Öncelik** 📋
               - Somut, ölçülebilir hedefler

            5. **Motivasyon Notu** 💬
               - Kısa, güçlü bir kapanış mesajı

            TONE: Warm, direct, data-backed, motivating. Avoid generic praise — be specific.
            """,
            user.name != null ? user.name : "Kullanıcı",
            formatDate(start),
            formatDate(end),
            formatWeekLabel(start, end),
            data.startWeight,
            data.endWeight,
            data.weightChange,
            data.avgDailyCalories,
            data.totalMeals,
            data.totalWorkouts,
            data.totalWorkoutMinutes,
            data.bestDay,
            data.restDays
        );
    }

    private String formatDate(LocalDate date) {
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd MMM", new Locale("tr"));
        return date.format(formatter);
    }

    private String formatWeekLabel(LocalDate start, LocalDate end) {
        return formatDate(start) + " - " + formatDate(end);
    }

    // Inner class için veri yapısı
    private static class WeeklyData {
        double startWeight = 0;
        double endWeight = 0;
        double weightChange = 0;
        int avgDailyCalories = 0;
        int totalMeals = 0;
        int totalWorkouts = 0;
        int totalWorkoutMinutes = 0;
        String bestDay = "YOK";
        int restDays = 7;

        Map<String, Object> toMap() {
            Map<String, Object> map = new HashMap<>();
            map.put("startWeight", startWeight);
            map.put("endWeight", endWeight);
            map.put("weightChange", weightChange);
            map.put("avgDailyCalories", avgDailyCalories);
            map.put("totalMeals", totalMeals);
            map.put("totalWorkouts", totalWorkouts);
            map.put("totalWorkoutMinutes", totalWorkoutMinutes);
            map.put("bestDay", bestDay);
            map.put("restDays", restDays);
            return map;
        }
    }
}
