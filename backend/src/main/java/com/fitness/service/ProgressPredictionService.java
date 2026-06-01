package com.fitness.service;

import com.fitness.entity.User;
import com.fitness.entity.WeightRecord;
import com.fitness.entity.Meal;
import jakarta.enterprise.context.ApplicationScoped;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.OptionalDouble;
import org.jboss.logging.Logger;

/**
 * Kullanıcının son 30 günlük verilerine göre ilerleme tahmini yapar.
 * - Hedef kiloya ne zaman ulaşacak?
 * - Ortalama kalori açığı/fazlası ne?
 * - Güncel tempo sürdürülebilir mi?
 */
@ApplicationScoped
public class ProgressPredictionService {

    private static final Logger LOG = Logger.getLogger(ProgressPredictionService.class);
    private static final int LOOKBACK_DAYS = 30;
    private static final double KCAL_PER_KG = 7700.0; // 1 kg yağ kaybı için yaklaşık kalori açığı

    /**
     * Kullanıcının hedef kilosuna kaç haftada ulaşacağını tahmin eder.
     * @return null eğer yeterli veri yoksa, yoksa tahmini hafta sayısı
     */
    public WeightProjection predictWeeksToTarget(Long userId) {
        User user = User.findById(userId);
        if (user == null || user.targetWeight == null || user.height == null) {
            return null;
        }

        // Son 30 günlük kilo verileri
        LocalDateTime cutoff = LocalDateTime.now().minusDays(LOOKBACK_DAYS);
        List<WeightRecord> weights = WeightRecord.find(
            "user.id = ?1 AND recordedAt >= ?2 ORDER BY recordedAt ASC",
            userId,
            cutoff
        ).list();

        if (weights.size() < 7) {
            LOG.debugf("Insufficient weight data for user %d (only %d entries)", userId, Integer.valueOf(weights.size()));
            return null;
        }

        // Linear regression ile haftalık ortalama değişim
        double weeklyChangeKg = calculateWeeklyTrend(weights);

        WeightRecord latest = weights.get(weights.size() - 1);
        double currentWeight = latest.weight;
        double targetWeight = user.targetWeight;
        double remainingKg = Math.abs(targetWeight - currentWeight);

        if (Math.abs(weeklyChangeKg) < 0.05) {
            // Haftada 50g'dan az değişim → durgun
            return new WeightProjection(
                currentWeight,
                targetWeight,
                weeklyChangeKg,
                null,
                "STAGNANT",
                "Son 30 günde kilo değişimi çok yavaş (haftalık ortalama: " +
                    String.format("%.2f", Math.abs(weeklyChangeKg)) + " kg). Plan revize edilmeli."
            );
        }

        // Hedef direction kontrolü
        boolean needsToLose = currentWeight > targetWeight;
        boolean isTrending = (needsToLose && weeklyChangeKg < 0) || (!needsToLose && weeklyChangeKg > 0);

        if (!isTrending) {
            return new WeightProjection(
                currentWeight,
                targetWeight,
                weeklyChangeKg,
                null,
                "WRONG_DIRECTION",
                "Mevcut tempo ters yönde: " + (needsToLose ? "kilo vermelisin ama alıyorsun" : "kilo almalısın ama veriyorsun")
            );
        }

        double weeksToTarget = remainingKg / Math.abs(weeklyChangeKg);

        // Sürdürülebilirlik kontrolü
        String sustainability = assessSustainability(weeklyChangeKg, user);

        return new WeightProjection(
            currentWeight,
            targetWeight,
            weeklyChangeKg,
            weeksToTarget,
            "ON_TRACK",
            "Mevcut tempo ile " + String.format("%.1f", weeksToTarget) +
                " haftada hedefe ulaşırsın. " + sustainability
        );
    }

    /**
     * Kullanıcının son 14 günlük ortalama kalori dengesini hesaplar.
     */
    public CalorieBalance calculateCalorieBalance(Long userId) {
        User user = User.findById(userId);
        if (user == null) return null;

        LocalDateTime cutoff = LocalDateTime.now().minusDays(14);
        List<Meal> meals = Meal.find(
            "user.id = ?1 AND mealDate >= ?2",
            userId,
            cutoff
        ).list();

        if (meals.isEmpty()) {
            return new CalorieBalance(0, 0, 0, "Henüz yeterli veri yok.");
        }

        OptionalDouble avgCalories = meals.stream()
            .mapToDouble(m -> m.calories != null ? m.calories : 0)
            .average();

        if (avgCalories.isEmpty()) {
            return new CalorieBalance(0, 0, 0, "Veri eksik.");
        }

        double avg = avgCalories.getAsDouble();
        double tdee = estimateTDEE(user);
        double dailyBalance = avg - tdee;
        double weeklyDeficitOrSurplus = dailyBalance * 7;

        String insight;
        if (Math.abs(dailyBalance) < 100) {
            insight = "Kalori dengen neredeyse maintenance seviyesinde.";
        } else if (dailyBalance < 0) {
            insight = "Günlük ortalama " + String.format("%.0f", Math.abs(dailyBalance)) +
                " kcal açık veriyorsun. Haftada yaklaşık " +
                String.format("%.2f", Math.abs(weeklyDeficitOrSurplus) / KCAL_PER_KG) + " kg kaybedebilirsin.";
        } else {
            insight = "Günlük ortalama " + String.format("%.0f", dailyBalance) +
                " kcal fazla alıyorsun. Haftada yaklaşık " +
                String.format("%.2f", weeklyDeficitOrSurplus / KCAL_PER_KG) + " kg alabilirsin.";
        }

        return new CalorieBalance((int) avg, tdee, dailyBalance, insight);
    }

    /**
     * Linear regression: her hafta ortalama kaç kg değişim var?
     */
    private double calculateWeeklyTrend(List<WeightRecord> weights) {
        if (weights.size() < 2) return 0.0;

        int n = weights.size();
        double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;

        LocalDate startDate = weights.get(0).recordedAt.toLocalDate();
        for (int i = 0; i < n; i++) {
            WeightRecord w = weights.get(i);
            long daysSinceStart = java.time.temporal.ChronoUnit.DAYS.between(startDate, w.recordedAt.toLocalDate());
            double x = (double) daysSinceStart;
            double y = w.weight;
            sumX += x;
            sumY += y;
            sumXY += x * y;
            sumX2 += x * x;
        }

        double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
        return slope * 7.0;
    }

    private String assessSustainability(double weeklyChangeKg, User user) {
        double absChange = Math.abs(weeklyChangeKg);
        if (absChange > 1.0) {
            return "⚠️ Dikkat: Haftalık " + String.format("%.2f", absChange) +
                " kg değişim çok hızlı — kas kaybı veya sağlık riski olabilir. Yavaşlatmayı düşün.";
        } else if (absChange < 0.2) {
            return "Değişim çok yavaş. Kalori hedefini gözden geçir.";
        } else {
            return "Tempo sağlıklı ve sürdürülebilir.";
        }
    }

    private double estimateTDEE(User user) {
        if (user.height == null || user.gender == null) return 2000;

        // En son kilo verisini al
        WeightRecord latest = WeightRecord.find(
            "user.id = ?1 ORDER BY recordedAt DESC",
            user.id
        ).firstResult();

        double weight = latest != null ? latest.weight : (user.weight != null ? user.weight : 70.0);
        double height = user.height;
        
        int age = 30;
        if (user.birthDate != null) {
            age = java.time.Period.between(user.birthDate.toLocalDate(), LocalDate.now()).getYears();
        }

        double bmr;
        if ("MALE".equalsIgnoreCase(user.gender)) {
            bmr = 10 * weight + 6.25 * height - 5 * age + 5;
        } else {
            bmr = 10 * weight + 6.25 * height - 5 * age - 161;
        }

        // Activity factor
        double activityFactor = 1.375; // lightly active fallback
        if (user.activityLevel != null) {
            switch (user.activityLevel.toLowerCase()) {
                case "sedentary": activityFactor = 1.2; break;
                case "lightlyactive": activityFactor = 1.375; break;
                case "moderatelyactive": activityFactor = 1.55; break;
                case "veryactive": activityFactor = 1.725; break;
                case "extraactive": activityFactor = 1.9; break;
            }
        }
        return bmr * activityFactor;
    }

    // DTO Classes
    public static class WeightProjection {
        public double currentWeight;
        public double targetWeight;
        public double weeklyChangeKg;
        public Double weeksToTarget; // null ise hesaplanamadı
        public String status; // ON_TRACK | STAGNANT | WRONG_DIRECTION
        public String message;

        public WeightProjection(double currentWeight, double targetWeight,
                                 double weeklyChangeKg, Double weeksToTarget,
                                 String status, String message) {
            this.currentWeight = currentWeight;
            this.targetWeight = targetWeight;
            this.weeklyChangeKg = weeklyChangeKg;
            this.weeksToTarget = weeksToTarget;
            this.status = status;
            this.message = message;
        }
    }

    public static class CalorieBalance {
        public int avgDailyCalories;
        public double tdee;
        public double dailyBalance; // pozitif: surplus, negatif: deficit
        public String insight;

        public CalorieBalance(int avgDailyCalories, double tdee, double dailyBalance, String insight) {
            this.avgDailyCalories = avgDailyCalories;
            this.tdee = tdee;
            this.dailyBalance = dailyBalance;
            this.insight = insight;
        }
    }
}
