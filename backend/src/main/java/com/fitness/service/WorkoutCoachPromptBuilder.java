package com.fitness.service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.fitness.entity.User;
import com.fitness.entity.Workout;
import com.fitness.repository.WorkoutRepository;
import com.fitness.service.WorkoutAnalysisService.DeloadRecommendation;
import com.fitness.service.WorkoutAnalysisService.PlateauDetection;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * AI Coach için antrenman bağlamı oluşturur.
 * Kullanıcının son antrenmanları, kas grubu dengesi, toparlanma durumu,
 * plato analizi ve önerilen aksiyonları AI'ya iletir.
 */
@ApplicationScoped
public class WorkoutCoachPromptBuilder {

    @Inject
    WorkoutRepository workoutRepository;

    @Inject
    WorkoutAnalysisService analysisService;

    /**
     * AI Coach'a eklenecek antrenman bağlamını oluşturur.
     *
     * @param userId Kullanıcı ID
     * @param userQuestion Kullanıcının sorusu (antrenman ile ilgili mi kontrol için)
     * @return Antrenman bağlamı prompt metni
     */
    public String buildWorkoutContext(Long userId, String userQuestion) {
        User user = User.findById(userId);
        if (user == null) return "";

        // Kullanıcının sorusu antrenman ile ilgili mi?
        boolean isWorkoutRelated = isWorkoutRelatedQuestion(userQuestion);
        if (!isWorkoutRelated) {
            return ""; // Beslenme veya genel sorularda antrenman bağlamını ekleme
        }

        StringBuilder context = new StringBuilder();
        context.append("\n\n## ANTRENMAN BAĞLAMI\n\n");

        // Son 7 günlük antrenman özeti
        String recentWorkoutsSummary = buildRecentWorkoutsSummary(userId);
        context.append("### Son 7 Günlük Antrenman Özeti\n");
        context.append(recentWorkoutsSummary).append("\n\n");

        // Kas grubu dengesi
        String muscleGroupBalance = buildMuscleGroupBalance(userId);
        context.append("### Kas Grubu Dengesi (Son 4 Hafta)\n");
        context.append(muscleGroupBalance).append("\n\n");

        // Toparlanma durumu
        String recoveryStatus = buildRecoveryStatus(userId);
        context.append("### Toparlanma Durumu\n");
        context.append(recoveryStatus).append("\n\n");

        // Plato kontrolü (eğer kullanıcı spesifik egzersiz sormuşsa)
        String plateauInfo = buildPlateauInfo(userId, userQuestion);
        if (!plateauInfo.isEmpty()) {
            context.append("### Plato Analizi\n");
            context.append(plateauInfo).append("\n\n");
        }

        // Deload ihtiyacı
        DeloadRecommendation deload = analysisService.calculateDeloadNeed(userId);
        if (deload.needsDeload) {
            context.append("### ⚠️ Deload Önerisi\n");
            context.append(deload.reason).append("\n");
            if (deload.deloadPlan != null) {
                context.append("**Plan:** ").append(deload.deloadPlan.get("recommendation")).append("\n\n");
            }
        }

        // AI'ya yönerge
        context.append("### AI Koç Yönergesi\n");
        context.append("Yukarıdaki antrenman bağlamını kullanarak kullanıcıya:\n");
        context.append("- Bugün hangi kas grubunu çalışması gerektiğini öner (toparlanma durumuna göre)\n");
        context.append("- Eğer plato varsa, nasıl aşabileceği konusunda somut öneriler sun\n");
        context.append("- Deload gerekiyorsa, kullanıcıyı nazikçe uyar ve plan ver\n");
        context.append("- Kullanıcının hedefine göre (kuvvet, hipertrofi, dayanıklılık) egzersiz ve set-rep öner\n");
        context.append("- Kullanıcının geçmiş performansına göre ağırlık önerisinde bulun\n\n");

        return context.toString();
    }

    /**
     * Sorunun antrenman ile ilgili olup olmadığını kontrol eder.
     */
    private boolean isWorkoutRelatedQuestion(String question) {
        if (question == null || question.isBlank()) return false;
        String lowerQ = question.toLowerCase();

        String[] workoutKeywords = {
            "antrenman", "egzersiz", "workout", "training", "spor", "kas", "kuvvet",
            "squat", "bench", "deadlift", "press", "biceps", "triceps", "bacak", "göğüs",
            "sırt", "omuz", "karın", "core", "set", "tekrar", "ağırlık", "deload",
            "plato", "1rm", "pr", "record", "volume", "hipertrofi", "kilo", "dambıl",
            "barbell", "gym", "salonda", "çalış", "koş", "kardiyo", "cardio"
        };

        for (String keyword : workoutKeywords) {
            if (lowerQ.contains(keyword)) return true;
        }
        return false;
    }

    /**
     * Son 7 günlük antrenman özetini oluşturur.
     */
    private String buildRecentWorkoutsSummary(Long userId) {
        LocalDateTime sevenDaysAgo = LocalDateTime.now().minusDays(7);
        List<Workout> recentWorkouts = workoutRepository.find(
            "user.id = ?1 AND workoutDate >= ?2 ORDER BY workoutDate DESC",
            userId, sevenDaysAgo
        ).list();

        if (recentWorkouts.isEmpty()) {
            return "❌ Son 7 günde antrenman kaydı yok.";
        }

        StringBuilder summary = new StringBuilder();
        summary.append(String.format("✅ Toplam %d antrenman kaydı:\n", recentWorkouts.size()));

        for (Workout w : recentWorkouts.stream().limit(5).collect(Collectors.toList())) {
            String date = w.workoutDate.toLocalDate().toString();
            String muscleGroup = w.muscleGroup != null ? w.muscleGroup : "Genel";
            String name = w.name;
            String weight = w.weight != null ? String.format("%.1f kg", w.weight) : "-";
            summary.append(String.format("- %s: %s (%s) - %s\n", date, name, muscleGroup, weight));
        }

        return summary.toString();
    }

    /**
     * Kas grubu dengesini analiz eder (son 4 hafta).
     */
    private String buildMuscleGroupBalance(Long userId) {
        LocalDateTime fourWeeksAgo = LocalDateTime.now().minusWeeks(4);
        List<Workout> workouts = workoutRepository.find(
            "user.id = ?1 AND workoutDate >= ?2",
            userId, fourWeeksAgo
        ).list();

        if (workouts.isEmpty()) {
            return "❌ Son 4 haftada antrenman kaydı yok.";
        }

        Map<String, Integer> muscleGroupCount = new HashMap<>();
        for (Workout w : workouts) {
            String group = w.muscleGroup != null ? w.muscleGroup : "Belirsiz";
            muscleGroupCount.merge(group, 1, Integer::sum);
        }

        StringBuilder balance = new StringBuilder();
        muscleGroupCount.entrySet().stream()
            .sorted((a, b) -> b.getValue().compareTo(a.getValue()))
            .forEach(entry -> {
                String group = entry.getKey();
                int count = entry.getValue();
                balance.append(String.format("- %s: %d antrenman\n", group, count));
            });

        // İhmal edilen kas grupları
        String[] allGroups = {"CHEST", "BACK", "LEGS", "SHOULDERS", "BICEPS", "TRICEPS", "CORE"};
        StringBuilder neglected = new StringBuilder();
        for (String group : allGroups) {
            if (!muscleGroupCount.containsKey(group)) {
                neglected.append(group).append(", ");
            }
        }

        if (neglected.length() > 0) {
            neglected.setLength(neglected.length() - 2); // Son virgülü sil
            balance.append(String.format("\n⚠️ İhmal edilen kas grupları: %s\n", neglected.toString()));
        }

        return balance.toString();
    }

    /**
     * Toparlanma durumunu analiz eder (her kas grubu için son çalışma tarihi).
     */
    private String buildRecoveryStatus(Long userId) {
        LocalDateTime twoWeeksAgo = LocalDateTime.now().minusWeeks(2);
        List<Workout> workouts = workoutRepository.find(
            "user.id = ?1 AND workoutDate >= ?2 ORDER BY workoutDate DESC",
            userId, twoWeeksAgo
        ).list();

        if (workouts.isEmpty()) {
            return "❌ Son 2 haftada antrenman kaydı yok.";
        }

        Map<String, LocalDate> lastWorkoutByGroup = new HashMap<>();
        for (Workout w : workouts) {
            String group = w.muscleGroup != null ? w.muscleGroup : "Belirsiz";
            LocalDate workoutDate = w.workoutDate.toLocalDate();
            lastWorkoutByGroup.putIfAbsent(group, workoutDate);
        }

        StringBuilder recovery = new StringBuilder();
        LocalDate today = LocalDate.now();
        lastWorkoutByGroup.entrySet().stream()
            .sorted(Map.Entry.comparingByValue())
            .forEach(entry -> {
                String group = entry.getKey();
                LocalDate lastDate = entry.getValue();
                long daysSince = java.time.temporal.ChronoUnit.DAYS.between(lastDate, today);
                String status = daysSince >= 3 ? "✅ Toparlanmış" : "🔄 Aktif";
                recovery.append(String.format("- %s: Son çalışma %d gün önce (%s)\n", group, daysSince, status));
            });

        return recovery.toString();
    }

    /**
     * Eğer kullanıcı spesifik egzersiz sormuşsa, plato bilgisi ekler.
     */
    private String buildPlateauInfo(Long userId, String userQuestion) {
        // Soru içinde egzersiz adı var mı bul
        String[] commonExercises = {
            "squat", "bench press", "deadlift", "overhead press", "barbell row",
            "pull-up", "dip", "leg press", "romanian deadlift", "front squat"
        };

        String lowerQ = userQuestion != null ? userQuestion.toLowerCase() : "";
        for (String exercise : commonExercises) {
            if (lowerQ.contains(exercise)) {
                PlateauDetection plateau = analysisService.detectPlateauForExercise(userId, exercise);
                if (plateau.plateaued) {
                    return String.format(
                        "⚠️ **%s için plato tespit edildi!**\n%s\n\n**Öneriler:**\n%s",
                        plateau.exerciseName,
                        plateau.reason,
                        plateau.suggestion
                    );
                } else {
                    return String.format(
                        "✅ **%s için iyi ilerleme var** (son dönemde %%%.1f gelişme)",
                        plateau.exerciseName,
                        plateau.progressPercent
                    );
                }
            }
        }

        return "";
    }
}
