package com.fitness.service;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import com.fitness.entity.User;
import com.fitness.entity.Workout;
import com.fitness.entity.WorkoutSet;
import com.fitness.repository.WorkoutRepository;
import com.fitness.repository.WorkoutSetRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Antrenman performans analizi, plato tespiti, PR tahmini ve deload önerileri.
 */
@ApplicationScoped
public class WorkoutAnalysisService {

    @Inject
    WorkoutRepository workoutRepository;

    @Inject
    WorkoutSetRepository workoutSetRepository;

    // ── Plato Tespiti ────────────────────────────────────────────────────────────

    /**
     * Belirli bir egzersiz için plato durumu tespit eder.
     * Son 4 haftadaki max ağırlık trendine bakar.
     */
    public PlateauDetection detectPlateauForExercise(Long userId, String exerciseName) {
        LocalDateTime cutoff = LocalDateTime.now().minusWeeks(6);
        List<Workout> history = workoutRepository.find(
            "user.id = ?1 AND LOWER(name) = LOWER(?2) AND workoutDate >= ?3 ORDER BY workoutDate ASC",
            userId, exerciseName, cutoff
        ).list();

        if (history.size() < 3) {
            return new PlateauDetection(
                exerciseName,
                false,
                "Yeterli veri yok (en az 3 kayıt gerekli)",
                null,
                0
            );
        }

        // Her kayıt için max ağırlığı bul
        List<WeeklyMaxWeight> weeklyMaxes = new ArrayList<>();
        for (Workout w : history) {
            double maxWeight = getMaxWeightFromWorkout(w);
            if (maxWeight > 0) {
                weeklyMaxes.add(new WeeklyMaxWeight(w.workoutDate.toLocalDate(), maxWeight));
            }
        }

        if (weeklyMaxes.size() < 3) {
            return new PlateauDetection(exerciseName, false, "Yeterli ağırlık verisi yok", null, 0);
        }

        // Son 4 kaydın trendini kontrol et
        int checkWindow = Math.min(4, weeklyMaxes.size());
        List<WeeklyMaxWeight> recentData = weeklyMaxes.subList(weeklyMaxes.size() - checkWindow, weeklyMaxes.size());

        double firstWeight = recentData.get(0).maxWeight;
        double lastWeight = recentData.get(recentData.size() - 1).maxWeight;
        double progressPercent = ((lastWeight - firstWeight) / firstWeight) * 100;

        boolean isPlateaued = progressPercent < 2.5; // %2.5'ten az ilerleme = plato
        int weekCount = (int) java.time.temporal.ChronoUnit.WEEKS.between(
            recentData.get(0).date,
            recentData.get(recentData.size() - 1).date
        );

        String suggestion = isPlateaued
            ? buildPlateauSuggestion(exerciseName, lastWeight, weekCount)
            : null;

        return new PlateauDetection(
            exerciseName,
            isPlateaued,
            isPlateaued ? String.format("%d haftadır %.1f kg civarında sabit", weekCount, lastWeight) : "İyi ilerleme",
            suggestion,
            progressPercent
        );
    }

    /**
     * Kas grubu bazında plato tespiti.
     */
    public Map<String, Object> detectPlateauForMuscleGroup(Long userId, String muscleGroup) {
        LocalDateTime cutoff = LocalDateTime.now().minusWeeks(6);
        List<Workout> workouts = workoutRepository.find(
            "user.id = ?1 AND muscleGroup = ?2 AND workoutDate >= ?3 ORDER BY workoutDate ASC",
            userId, muscleGroup, cutoff
        ).list();

        if (workouts.isEmpty()) {
            Map<String, Object> result = new HashMap<>();
            result.put("muscleGroup", muscleGroup);
            result.put("plateaued", false);
            result.put("reason", "Bu kas grubu için veri yok");
            return result;
        }

        // Haftalık toplam volume hesapla
        Map<LocalDate, Double> weeklyVolume = new HashMap<>();
        for (Workout w : workouts) {
            LocalDate weekStart = w.workoutDate.toLocalDate().with(DayOfWeek.MONDAY);
            double volume = calculateWorkoutVolume(w);
            weeklyVolume.merge(weekStart, volume, Double::sum);
        }

        List<Map.Entry<LocalDate, Double>> volumeList = weeklyVolume.entrySet().stream()
            .sorted(Map.Entry.comparingByKey())
            .collect(Collectors.toList());

        if (volumeList.size() < 3) {
            Map<String, Object> result = new HashMap<>();
            result.put("muscleGroup", muscleGroup);
            result.put("plateaued", false);
            result.put("reason", "Yeterli haftalık veri yok");
            return result;
        }

        // Son 4 haftanın volume trendini kontrol et
        int checkWindow = Math.min(4, volumeList.size());
        List<Map.Entry<LocalDate, Double>> recentVolume = volumeList.subList(volumeList.size() - checkWindow, volumeList.size());

        double firstVolume = recentVolume.get(0).getValue();
        double lastVolume = recentVolume.get(recentVolume.size() - 1).getValue();
        double volumeProgress = firstVolume > 0
            ? ((lastVolume - firstVolume) / firstVolume) * 100
            : (lastVolume > 0 ? 100.0 : 0.0);

        boolean isPlateaued = volumeProgress < 5.0; // %5'ten az volume artışı = plato

        Map<String, Object> result = new HashMap<>();
        result.put("muscleGroup", muscleGroup);
        result.put("plateaued", isPlateaued);
        result.put("weeklyVolumes", volumeList.stream()
            .map(e -> Map.of("week", e.getKey().toString(), "volume", Math.round(e.getValue())))
            .collect(Collectors.toList()));
        result.put("progressPercent", Math.round(volumeProgress * 10) / 10.0);
        result.put("suggestion", isPlateaued ? buildMuscleGroupPlateauSuggestion(muscleGroup) : null);
        return result;
    }

    // ── PR Tahmini ───────────────────────────────────────────────────────────────

    /**
     * Belirli bir egzersiz için gelecek PR tahmini (linear regression).
     */
    public PredictedPR predictNextPR(Long userId, String exerciseName) {
        LocalDateTime cutoff = LocalDateTime.now().minusWeeks(12);
        List<Workout> history = workoutRepository.find(
            "user.id = ?1 AND LOWER(name) = LOWER(?2) AND workoutDate >= ?3 ORDER BY workoutDate ASC",
            userId, exerciseName, cutoff
        ).list();

        if (history.size() < 4) {
            return new PredictedPR(
                exerciseName,
                null,
                null,
                "Tahmin için en az 4 kayıt gerekli",
                0.0
            );
        }

        // Her kayıt için 1RM değerini al
        List<DataPoint> dataPoints = new ArrayList<>();
        LocalDate startDate = history.get(0).workoutDate.toLocalDate();

        for (Workout w : history) {
            double oneRM = w.oneRepMax != null ? w.oneRepMax : estimateOneRM(w);
            if (oneRM > 0) {
                long daysSinceStart = java.time.temporal.ChronoUnit.DAYS.between(startDate, w.workoutDate.toLocalDate());
                dataPoints.add(new DataPoint(daysSinceStart, oneRM));
            }
        }

        if (dataPoints.size() < 4) {
            return new PredictedPR(exerciseName, null, null, "Yeterli 1RM verisi yok", 0.0);
        }

        // Linear regression
        LinearRegressionResult lr = calculateLinearRegression(dataPoints);

        if (lr.slope <= 0) {
            return new PredictedPR(
                exerciseName,
                null,
                null,
                "Negatif trend: kuvvet kaybı var",
                lr.rSquared
            );
        }

        // 4 hafta sonrası tahmini
        long daysToPredict = 28;
        long futureDays = dataPoints.get(dataPoints.size() - 1).x + daysToPredict;
        double predictedOneRM = lr.intercept + (lr.slope * futureDays);
        double currentMax = dataPoints.stream().mapToDouble(d -> d.y).max().orElse(0);

        LocalDate predictionDate = LocalDate.now().plusWeeks(4);

        return new PredictedPR(
            exerciseName,
            predictedOneRM,
            predictionDate,
            String.format("Mevcut trend devam ederse 4 hafta içinde %.1f kg 1RM bekleniyor (şu anki max: %.1f kg)",
                predictedOneRM, currentMax),
            lr.rSquared
        );
    }

    // ── Deload Önerisi ───────────────────────────────────────────────────────────

    /**
     * Kullanıcının deload ihtiyacını analiz eder.
     * Kriterler:
     * - Son 4 haftada yüksek volume (kişisel ortalamanın %120+ üstü)
     * - Yüksek ortalama RPE (8.5+)
     * - Plato var mı?
     */
    public DeloadRecommendation calculateDeloadNeed(Long userId) {
        User user = User.findById(userId);
        if (user == null) {
            return new DeloadRecommendation(false, "Kullanıcı bulunamadı", null);
        }

        LocalDateTime fourWeeksAgo = LocalDateTime.now().minusWeeks(4);
        LocalDateTime twelveWeeksAgo = LocalDateTime.now().minusWeeks(12);

        List<Workout> recentWorkouts = workoutRepository.find(
            "user.id = ?1 AND workoutDate >= ?2 ORDER BY workoutDate DESC",
            userId, fourWeeksAgo
        ).list();

        List<Workout> historicalWorkouts = workoutRepository.find(
            "user.id = ?1 AND workoutDate >= ?2 AND workoutDate < ?3",
            userId, twelveWeeksAgo, fourWeeksAgo
        ).list();

        if (recentWorkouts.isEmpty()) {
            return new DeloadRecommendation(false, "Son 4 haftada antrenman kaydı yok", null);
        }

        // Son 4 haftanın toplam volume'ü
        double recentTotalVolume = recentWorkouts.stream()
            .mapToDouble(this::calculateWorkoutVolume)
            .sum();

        // Önceki 8 haftanın haftalık ortalama volume'ü
        double historicalAvgWeeklyVolume = historicalWorkouts.isEmpty() ? 0 :
            historicalWorkouts.stream().mapToDouble(this::calculateWorkoutVolume).sum() / 8.0;

        // Son 4 haftanın haftalık ortalama volume'ü
        double recentAvgWeeklyVolume = recentTotalVolume / 4.0;

        // Yüksek volume kontrolü (%120+)
        boolean highVolume = historicalAvgWeeklyVolume > 0 &&
            (recentAvgWeeklyVolume / historicalAvgWeeklyVolume) >= 1.20;

        // Ortalama RPE kontrolü
        List<Double> rpeValues = new ArrayList<>();
        for (Workout w : recentWorkouts) {
            List<WorkoutSet> sets = workoutSetRepository.findByWorkoutId(w.id);
            for (WorkoutSet set : sets) {
                if (set.rpe != null) rpeValues.add(set.rpe);
            }
        }
        double avgRPE = rpeValues.isEmpty() ? 0 : rpeValues.stream().mapToDouble(Double::doubleValue).average().orElse(0);
        boolean highRPE = avgRPE >= 8.5;

        // En az 2 kriter varsa deload öner
        int criteriaCount = (highVolume ? 1 : 0) + (highRPE ? 1 : 0);
        boolean needsDeload = criteriaCount >= 1 && recentWorkouts.size() >= 8; // 4 haftada en az 8 antrenman

        if (!needsDeload) {
            return new DeloadRecommendation(
                false,
                "Deload gerekli değil - volume ve RPE dengeli",
                null
            );
        }

        List<String> reasons = new ArrayList<>();
        if (highVolume && historicalAvgWeeklyVolume > 0) {
            reasons.add(String.format(
                "Yüksek volume (%.0f kg/hafta, normalin %%%.0f'i)",
                recentAvgWeeklyVolume,
                (recentAvgWeeklyVolume / historicalAvgWeeklyVolume) * 100
            ));
        }
        if (highRPE) {
            reasons.add(String.format("Ortalama RPE yüksek (%.1f/10)", avgRPE));
        }
        String reason = "Deload öneriliyor: " + String.join(". ", reasons) + ".";

        Map<String, Object> plan = new HashMap<>();
        plan.put("duration", "1 hafta");
        plan.put("volumeReduction", "50%");
        plan.put("intensity", "RPE 6-7 arası hafif çalışmalar");
        plan.put("recommendation", "Set sayılarını yarıya indir, ağırlıkları %30 düşür, tekniğe odaklan");

        return new DeloadRecommendation(true, reason.trim(), plan);
    }

    // ── Volume Analizi ───────────────────────────────────────────────────────────

    /**
     * Son 8 haftanın haftalık volume grafiğini döndürür.
     */
    public Map<String, Object> getVolumeAnalysis(Long userId) {
        LocalDateTime cutoff = LocalDateTime.now().minusWeeks(8);
        List<Workout> workouts = workoutRepository.find(
            "user.id = ?1 AND workoutDate >= ?2 ORDER BY workoutDate ASC",
            userId, cutoff
        ).list();

        Map<LocalDate, Double> weeklyVolume = new HashMap<>();
        Map<LocalDate, Double> weeklyAvgRPE = new HashMap<>();
        Map<LocalDate, Integer> weeklyWorkoutCount = new HashMap<>();

        for (Workout w : workouts) {
            LocalDate weekStart = w.workoutDate.toLocalDate().with(DayOfWeek.MONDAY);
            double volume = calculateWorkoutVolume(w);
            weeklyVolume.merge(weekStart, volume, Double::sum);
            weeklyWorkoutCount.merge(weekStart, 1, Integer::sum);

            // RPE
            List<WorkoutSet> sets = workoutSetRepository.findByWorkoutId(w.id);
            double avgRPE = sets.stream()
                .filter(s -> s.rpe != null)
                .mapToDouble(s -> s.rpe)
                .average()
                .orElse(0);
            if (avgRPE > 0) {
                weeklyAvgRPE.merge(weekStart, avgRPE, (a, b) -> (a + b) / 2);
            }
        }

        List<Map<String, Object>> weeklyData = weeklyVolume.entrySet().stream()
            .sorted(Map.Entry.comparingByKey())
            .map(e -> {
                Map<String, Object> week = new HashMap<>();
                week.put("weekStart", e.getKey().toString());
                week.put("volume", Math.round(e.getValue()));
                week.put("workoutCount", weeklyWorkoutCount.getOrDefault(e.getKey(), 0));
                week.put("avgRPE", weeklyAvgRPE.getOrDefault(e.getKey(), 0.0));
                return week;
            })
            .collect(Collectors.toList());

        Map<String, Object> result = new HashMap<>();
        result.put("weeklyData", weeklyData);
        result.put("totalVolume", Math.round(weeklyVolume.values().stream().mapToDouble(Double::doubleValue).sum()));
        result.put("avgWeeklyVolume", Math.round(weeklyVolume.values().stream().mapToDouble(Double::doubleValue).average().orElse(0)));
        return result;
    }

    // ── Helper Methods ───────────────────────────────────────────────────────────

    private double getMaxWeightFromWorkout(Workout workout) {
        List<WorkoutSet> sets = workoutSetRepository.findByWorkoutId(workout.id);
        if (!sets.isEmpty()) {
            return sets.stream()
                .filter(s -> s.weight != null)
                .mapToDouble(s -> s.weight)
                .max()
                .orElse(workout.weight != null ? workout.weight : 0);
        }
        return workout.weight != null ? workout.weight : 0;
    }

    private double estimateOneRM(Workout workout) {
        if (workout.oneRepMax != null) return workout.oneRepMax;

        // Set bazlı en yüksek tahmin
        List<WorkoutSet> sets = workoutSetRepository.findByWorkoutId(workout.id);
        if (!sets.isEmpty()) {
            return sets.stream()
                .filter(s -> s.weight != null && s.reps != null && s.reps > 0)
                .mapToDouble(s -> s.weight * (1 + s.reps / 30.0))
                .max()
                .orElse(0);
        }

        // Özet alanlardan tahmin
        if (workout.weight != null && workout.reps != null && workout.reps > 0) {
            return workout.weight * (1 + workout.reps / 30.0);
        }
        return 0;
    }

    private double calculateWorkoutVolume(Workout workout) {
        List<WorkoutSet> sets = workoutSetRepository.findByWorkoutId(workout.id);
        if (!sets.isEmpty()) {
            return sets.stream()
                .filter(s -> s.weight != null && s.reps != null)
                .mapToDouble(s -> s.weight * s.reps)
                .sum();
        }

        // Fallback: özet alanlar
        double weight = workout.weight != null ? workout.weight : 0;
        int reps = workout.reps != null ? workout.reps : 0;
        int setsCount = workout.sets != null ? workout.sets : 1;
        return weight * reps * setsCount;
    }

    private String buildPlateauSuggestion(String exerciseName, double currentWeight, int weekCount) {
        return String.format(
            "Öneriler: (1) Deload yap (1 hafta, %%50 volume). " +
            "(2) Tempo çalışması ekle (3-1-3). " +
            "(3) Rep aralığını değiştir (şu anki ağırlıkta 12-15 tekrar). " +
            "(4) Yardımcı egzersiz ekle (%s için destek hareketler).",
            exerciseName
        );
    }

    private String buildMuscleGroupPlateauSuggestion(String muscleGroup) {
        return String.format(
            "%s için plato tespit edildi. Öneriler: (1) Egzersiz çeşitliliği artır. " +
            "(2) Haftalık frekansı değiştir (örn: 2x yerine 3x). " +
            "(3) Volume'ü kademeli artır (%%10-15 haftalık). " +
            "(4) Tempo ve pause çalışmaları ekle.",
            muscleGroup
        );
    }

    private LinearRegressionResult calculateLinearRegression(List<DataPoint> points) {
        int n = points.size();
        double sumX = points.stream().mapToDouble(p -> p.x).sum();
        double sumY = points.stream().mapToDouble(p -> p.y).sum();
        double sumXY = points.stream().mapToDouble(p -> p.x * p.y).sum();
        double sumX2 = points.stream().mapToDouble(p -> p.x * p.x).sum();
        double sumY2 = points.stream().mapToDouble(p -> p.y * p.y).sum();

        double denominator = n * sumX2 - sumX * sumX;
        if (denominator == 0) {
            return new LinearRegressionResult(0, mean(points), 0);
        }

        double slope = (n * sumXY - sumX * sumY) / denominator;
        double intercept = (sumY - slope * sumX) / n;

        // R-squared
        double meanY = sumY / n;
        double ssTotal = points.stream().mapToDouble(p -> Math.pow(p.y - meanY, 2)).sum();
        if (ssTotal == 0) {
            return new LinearRegressionResult(slope, intercept, 0);
        }
        double ssResidual = points.stream().mapToDouble(p -> {
            double predicted = intercept + slope * p.x;
            return Math.pow(p.y - predicted, 2);
        }).sum();
        double rSquared = 1 - (ssResidual / ssTotal);

        return new LinearRegressionResult(slope, intercept, rSquared);
    }

    private double mean(List<DataPoint> points) {
        return points.stream().mapToDouble(p -> p.y).average().orElse(0);
    }

    // ── DTOs ─────────────────────────────────────────────────────────────────────

    public static class PlateauDetection {
        public String exerciseName;
        public boolean plateaued;
        public String reason;
        public String suggestion;
        public double progressPercent;

        public PlateauDetection(String exerciseName, boolean plateaued, String reason, String suggestion, double progressPercent) {
            this.exerciseName = exerciseName;
            this.plateaued = plateaued;
            this.reason = reason;
            this.suggestion = suggestion;
            this.progressPercent = progressPercent;
        }
    }

    public static class PredictedPR {
        public String exerciseName;
        public Double predictedOneRM;
        public LocalDate predictionDate;
        public String description;
        public double confidence; // R-squared

        public PredictedPR(String exerciseName, Double predictedOneRM, LocalDate predictionDate, String description, double confidence) {
            this.exerciseName = exerciseName;
            this.predictedOneRM = predictedOneRM;
            this.predictionDate = predictionDate;
            this.description = description;
            this.confidence = confidence;
        }
    }

    public static class DeloadRecommendation {
        public boolean needsDeload;
        public String reason;
        public Map<String, Object> deloadPlan;

        public DeloadRecommendation(boolean needsDeload, String reason, Map<String, Object> deloadPlan) {
            this.needsDeload = needsDeload;
            this.reason = reason;
            this.deloadPlan = deloadPlan;
        }
    }

    private static class WeeklyMaxWeight {
        LocalDate date;
        double maxWeight;

        WeeklyMaxWeight(LocalDate date, double maxWeight) {
            this.date = date;
            this.maxWeight = maxWeight;
        }
    }

    private static class DataPoint {
        long x;
        double y;

        DataPoint(long x, double y) {
            this.x = x;
            this.y = y;
        }
    }

    private static class LinearRegressionResult {
        double slope;
        double intercept;
        double rSquared;

        LinearRegressionResult(double slope, double intercept, double rSquared) {
            this.slope = slope;
            this.intercept = intercept;
            this.rSquared = rSquared;
        }
    }
}
