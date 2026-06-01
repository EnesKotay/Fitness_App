package com.fitness.service;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

import com.fitness.entity.Meal;
import com.fitness.entity.User;
import com.fitness.entity.WorkoutSession;
import com.fitness.repository.MealRepository;
import com.fitness.repository.WorkoutSessionRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

/**
 * Beslenme zamanlama optimizasyonu.
 * Antrenman saatine göre öğün önerileri yapar.
 */
@ApplicationScoped
public class NutritionTimingService {

    @Inject
    WorkoutSessionRepository workoutSessionRepository;

    @Inject
    MealRepository mealRepository;

    /**
     * AI prompt için beslenme zamanlama bağlamı.
     */
    public String buildTimingContext(Long userId) {
        User user = User.findById(userId);
        if (user == null) {
            return "";
        }

        List<String> recommendations = new ArrayList<>();

        // Son antrenmanın üzerinden ne kadar zaman geçti?
        WorkoutSession lastWorkout = workoutSessionRepository.find(
            "user.id = ?1 ORDER BY finishedAt DESC",
            userId
        ).firstResult();

        if (lastWorkout != null) {
            long hoursSinceWorkout = ChronoUnit.HOURS.between(
                lastWorkout.finishedAt,
                LocalDateTime.now()
            );

            if (hoursSinceWorkout <= 2) {
                recommendations.add("🍗 **Post-Workout Pencere:** Antrenman üzerinden " + hoursSinceWorkout +
                    " saat geçti. Protein + karbonhidrat öner (tavuk-pilav, protein shake-muz).");
            }
        }

        // Bugünkü son öğün ne zaman?
        Meal lastMeal = mealRepository.find(
            "user.id = ?1 ORDER BY mealDate DESC",
            userId
        ).firstResult();

        if (lastMeal != null) {
            long hoursSinceMeal = ChronoUnit.HOURS.between(
                lastMeal.mealDate,
                LocalDateTime.now()
            );

            if (hoursSinceMeal >= 4) {
                recommendations.add("⏰ **Öğün Zamanı:** Son öğünden " + hoursSinceMeal +
                    " saat geçti. Protein-ağırlıklı öğün öner.");
            }
        }

        // Günün saati bazında genel öneri
        LocalTime now = LocalTime.now();
        int hour = now.getHour();

        if (hour >= 6 && hour < 10 && (lastMeal == null || lastMeal.mealType == null || !lastMeal.mealType.equals("BREAKFAST"))) {
            recommendations.add("🌅 **Kahvaltı Zamanı:** Kullanıcı henüz kahvaltı yapmamış. Protein + karbon hidrat öner.");
        } else if (hour >= 17 && hour < 20) {
            recommendations.add("🏋️ **Antrenman Penceresi:** Akşam ideal antrenman saati. Eğer antrenman planlıyorsa, 1-2 saat öncesinde hafif karbonhidrat öner.");
        }

        if (recommendations.isEmpty()) {
            return "";
        }

        StringBuilder context = new StringBuilder();
        context.append("\n## BESLENMe ZAMANLAMA\n\n");
        for (String rec : recommendations) {
            context.append("- ").append(rec).append("\n");
        }
        context.append("\n**AI Talimatı:** Yukarıdaki zamanlama önerilerini kullanıcıya sun.\n");

        return context.toString();
    }
}
