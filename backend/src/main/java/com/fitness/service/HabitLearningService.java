package com.fitness.service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.fitness.entity.Meal;
import com.fitness.entity.User;
import com.fitness.entity.Workout;
import com.fitness.entity.WorkoutSession;
import com.fitness.repository.MealRepository;
import com.fitness.repository.WorkoutRepository;
import com.fitness.repository.WorkoutSessionRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Kullanıcının alışkanlıklarını öğrenir ve tahmin eder.
 * "Her Pazartesi sabah 7'de antrenman yapıyor" gibi kalıpları tespit eder.
 */
@ApplicationScoped
public class HabitLearningService {

    @Inject
    WorkoutRepository workoutRepository;

    @Inject
    WorkoutSessionRepository workoutSessionRepository;

    @Inject
    MealRepository mealRepository;

    /**
     * Kullanıcının antrenman alışkanlıklarını analiz eder.
     * Son 8 haftanın verisine göre pattern bulur.
     */
    public HabitAnalysis analyzeWorkoutHabits(Long userId) {
        User user = User.findById(userId);
        if (user == null) {
            return new HabitAnalysis(false, "Kullanıcı bulunamadı", null);
        }

        LocalDateTime cutoff = LocalDateTime.now().minusWeeks(8);
        List<WorkoutSession> sessions = workoutSessionRepository.find(
            "user.id = ?1 AND finishedAt >= ?2 ORDER BY finishedAt ASC",
            userId, cutoff
        ).list();

        if (sessions.size() < 4) {
            return new HabitAnalysis(false, "Yeterli veri yok (en az 4 antrenman gerekli)", null);
        }

        // Gün bazlı dağılım
        Map<DayOfWeek, Integer> dayCount = new HashMap<>();
        Map<DayOfWeek, List<LocalTime>> dayTimes = new HashMap<>();

        for (WorkoutSession session : sessions) {
            DayOfWeek day = session.finishedAt.getDayOfWeek();
            LocalTime time = session.finishedAt.toLocalTime();

            dayCount.merge(day, 1, Integer::sum);
            dayTimes.computeIfAbsent(day, k -> new ArrayList<>()).add(time);
        }

        // En sık antrenman yapılan günler
        List<DayOfWeek> topDays = dayCount.entrySet().stream()
            .filter(e -> e.getValue() >= 2) // En az 2 kez
            .sorted((a, b) -> b.getValue().compareTo(a.getValue()))
            .limit(3)
            .map(Map.Entry::getKey)
            .collect(Collectors.toList());

        if (topDays.isEmpty()) {
            return new HabitAnalysis(false, "Düzenli pattern bulunamadı", null);
        }

        // Her gün için ortalama saat
        Map<DayOfWeek, String> avgTimes = new HashMap<>();
        for (DayOfWeek day : topDays) {
            List<LocalTime> times = dayTimes.get(day);
            if (times != null && !times.isEmpty()) {
                double avgHour = times.stream()
                    .mapToInt(LocalTime::getHour)
                    .average()
                    .orElse(0);
                avgTimes.put(day, String.format("%02d:00", (int) avgHour));
            }
        }

        // Habit summary oluştur
        StringBuilder summary = new StringBuilder();
        summary.append("Düzenli antrenman günlerin:\n");
        for (DayOfWeek day : topDays) {
            int count = dayCount.get(day);
            String time = avgTimes.getOrDefault(day, "-");
            summary.append(String.format("- %s: %d antrenman (~%s)\n",
                getDayNameTurkish(day), count, time));
        }

        Map<String, Object> pattern = new HashMap<>();
        pattern.put("topDays", topDays.stream().map(this::getDayNameTurkish).collect(Collectors.toList()));
        pattern.put("avgTimes", avgTimes);
        pattern.put("totalSessions", sessions.size());
        pattern.put("weeksAnalyzed", 8);

        return new HabitAnalysis(true, summary.toString(), pattern);
    }

    /**
     * Bugün için alışkanlık bazlı öneri.
     */
    public String getTodayHabitSuggestion(Long userId) {
        HabitAnalysis analysis = analyzeWorkoutHabits(userId);
        if (!analysis.patternFound) {
            return "";
        }

        DayOfWeek today = LocalDate.now().getDayOfWeek();
        String todayName = getDayNameTurkish(today);

        @SuppressWarnings("unchecked")
        List<String> topDays = (List<String>) analysis.pattern.get("topDays");

        if (topDays.contains(todayName)) {
            @SuppressWarnings("unchecked")
            Map<String, String> avgTimes = (Map<String, String>) analysis.pattern.get("avgTimes");
            String time = avgTimes.get(today);

            return String.format(
                "💡 **Alışkanlık Hatırlatması:** Genellikle %s günleri saat %s civarında antrenman yapıyorsun. " +
                "Bugün de yapmayı planlıyor musun?",
                todayName, time != null ? time : "bu saatlerde"
            );
        }

        return "";
    }

    /**
     * Beslenme alışkanlıkları analizi.
     */
    public Map<String, Object> analyzeMealHabits(Long userId) {
        LocalDateTime cutoff = LocalDateTime.now().minusWeeks(4);
        List<Meal> meals = mealRepository.find(
            "user.id = ?1 AND consumedAt >= ?2 ORDER BY consumedAt ASC",
            userId, cutoff
        ).list();

        Map<String, Object> habits = new HashMap<>();

        if (meals.size() < 10) {
            habits.put("patternFound", false);
            habits.put("reason", "Yeterli veri yok");
            return habits;
        }

        // Öğün zamanları analizi
        Map<String, List<LocalTime>> mealTypeTimes = new HashMap<>();
        for (Meal meal : meals) {
            String mealType = meal.mealType != null ? meal.mealType : "SNACK";
            LocalTime time = meal.mealDate.toLocalTime();
            mealTypeTimes.computeIfAbsent(mealType, k -> new ArrayList<>()).add(time);
        }

        // Her öğün tipi için ortalama saat
        Map<String, String> avgMealTimes = new HashMap<>();
        for (Map.Entry<String, List<LocalTime>> entry : mealTypeTimes.entrySet()) {
            String mealType = entry.getKey();
            List<LocalTime> times = entry.getValue();

            if (times.size() >= 3) { // En az 3 kayıt
                double avgHour = times.stream()
                    .mapToInt(LocalTime::getHour)
                    .average()
                    .orElse(0);
                avgMealTimes.put(mealType, String.format("%02d:00", (int) avgHour));
            }
        }

        // En çok tüketilen yiyecekler
        Map<String, Integer> foodCounts = new HashMap<>();
        for (Meal meal : meals) {
            if (meal.name != null) {
                foodCounts.merge(meal.name, 1, Integer::sum);
            }
        }

        List<String> topFoods = foodCounts.entrySet().stream()
            .filter(e -> e.getValue() >= 3)
            .sorted((a, b) -> b.getValue().compareTo(a.getValue()))
            .limit(5)
            .map(Map.Entry::getKey)
            .collect(Collectors.toList());

        habits.put("patternFound", true);
        habits.put("avgMealTimes", avgMealTimes);
        habits.put("topFoods", topFoods);
        habits.put("totalMeals", meals.size());

        return habits;
    }

    /**
     * Kullanıcı şu anda alışkanlığından sapıyor mu?
     * Örn: "Her Pazartesi antrenman yaparsın ama bugün Pazartesi ve henüz yapmadın"
     */
    public DeviationAlert checkForDeviation(Long userId) {
        HabitAnalysis analysis = analyzeWorkoutHabits(userId);
        if (!analysis.patternFound) {
            return new DeviationAlert(false, null);
        }

        DayOfWeek today = LocalDate.now().getDayOfWeek();
        String todayName = getDayNameTurkish(today);

        @SuppressWarnings("unchecked")
        List<String> topDays = (List<String>) analysis.pattern.get("topDays");

        if (!topDays.contains(todayName)) {
            return new DeviationAlert(false, null);
        }

        // Bugün antrenman yaptı mı kontrol et
        LocalDate todayDate = LocalDate.now();
        List<WorkoutSession> todaySessions = workoutSessionRepository.find(
            "user.id = ?1 AND DATE(finishedAt) = ?2",
            userId, todayDate
        ).list();

        if (!todaySessions.isEmpty()) {
            return new DeviationAlert(false, null); // Bugün zaten yaptı
        }

        // Sapma var!
        @SuppressWarnings("unchecked")
        Map<String, String> avgTimes = (Map<String, String>) analysis.pattern.get("avgTimes");
        String expectedTime = avgTimes.get(today);

        String message = String.format(
            "⚠️ Genellikle %s günleri saat %s'de antrenman yapıyorsun. " +
            "Bugün henüz yapmadın. Planladın mı?",
            todayName,
            expectedTime != null ? expectedTime : "bu saatlerde"
        );

        return new DeviationAlert(true, message);
    }

    private String getDayNameTurkish(DayOfWeek day) {
        return switch (day) {
            case MONDAY -> "Pazartesi";
            case TUESDAY -> "Salı";
            case WEDNESDAY -> "Çarşamba";
            case THURSDAY -> "Perşembe";
            case FRIDAY -> "Cuma";
            case SATURDAY -> "Cumartesi";
            case SUNDAY -> "Pazar";
        };
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────────

    public static class HabitAnalysis {
        public boolean patternFound;
        public String summary;
        public Map<String, Object> pattern;

        public HabitAnalysis(boolean patternFound, String summary, Map<String, Object> pattern) {
            this.patternFound = patternFound;
            this.summary = summary;
            this.pattern = pattern;
        }
    }

    public static class DeviationAlert {
        public boolean isDeviating;
        public String message;

        public DeviationAlert(boolean isDeviating, String message) {
            this.isDeviating = isDeviating;
            this.message = message;
        }
    }
}
