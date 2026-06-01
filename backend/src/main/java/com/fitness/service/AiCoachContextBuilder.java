package com.fitness.service;

import java.time.LocalDateTime;
import java.time.Period;
import java.util.List;
import java.util.Locale;

import com.fitness.dto.AiCoachRequest;
import com.fitness.entity.BodyMeasurement;
import com.fitness.entity.User;
import com.fitness.entity.WeightRecord;
import com.fitness.entity.Workout;
import com.fitness.repository.BodyMeasurementRepository;
import com.fitness.repository.UserRepository;
import com.fitness.repository.WeightRecordRepository;
import com.fitness.repository.WorkoutRepository;

import jakarta.enterprise.context.ApplicationScoped;
import jakarta.inject.Inject;

@ApplicationScoped
public class AiCoachContextBuilder {

    @Inject
    UserRepository userRepository;

    @Inject
    WeightRecordRepository weightRecordRepository;

    @Inject
    BodyMeasurementRepository bodyMeasurementRepository;

    @Inject
    WorkoutRepository workoutRepository;

    @Inject
    AiFeedbackService feedbackService;

    @Inject
    ProgressPredictionService progressPredictionService;

    public CoachPromptContext build(Long userId, AiCoachRequest.DailySummaryDto summary) {
        return build(userId, summary, null);
    }

    public CoachPromptContext build(Long userId, AiCoachRequest.DailySummaryDto summary, String question) {
        User user = userId == null ? null : userRepository.findById(userId);
        String profileSnapshot = buildProfileSnapshot(user);
        String recoverySnapshot = buildRecoverySnapshot(summary);
        String progressSnapshot = buildProgressSnapshot(userId);

        // Performans tahminlerini ekle
        String predictionInsights = buildPredictionInsights(userId);

        String coachingSignals = buildCoachingSignals(user, summary, progressSnapshot);
        String feedbackMemory = feedbackService.buildFeedbackMemory(userId);
        String workoutHistory = buildWorkoutHistorySnapshot(userId, question);

        return new CoachPromptContext(
            profileSnapshot,
            recoverySnapshot,
            progressSnapshot + predictionInsights,
            coachingSignals,
            feedbackMemory,
            workoutHistory,
            userId
        );
    }

    private String buildProfileSnapshot(User user) {
        if (user == null) {
            return "Profile data unavailable.";
        }

        String age = "unknown";
        if (user.birthDate != null) {
            age = Integer.toString(Period.between(user.birthDate.toLocalDate(), LocalDateTime.now().toLocalDate()).getYears());
        }

        return String.format(
                Locale.US,
                "Name: %s | Gender: %s | Age: %s | Height: %s cm | Current weight: %s kg | Target weight: %s kg",
                safeText(user.name, "unknown"),
                safeText(user.gender, "unknown"),
                age,
                formatNumber(user.height, 1),
                formatNumber(user.weight, 1),
                formatNumber(user.targetWeight, 1));
    }

    private String buildRecoverySnapshot(AiCoachRequest.DailySummaryDto summary) {
        if (summary == null) {
            return "Recovery signals unavailable.";
        }

        String sleepBand = "unknown";
        if (summary.sleepHours != null) {
            if (summary.sleepHours < 6.0) {
                sleepBand = "poor";
            } else if (summary.sleepHours < 7.0) {
                sleepBand = "moderate";
            } else {
                sleepBand = "good";
            }
        }

        String hydrationBand = "unknown";
        if (summary.waterLiters != null) {
            if (summary.waterLiters < 1.5) {
                hydrationBand = "low";
            } else if (summary.waterLiters < 2.5) {
                hydrationBand = "fair";
            } else {
                hydrationBand = "good";
            }
        }

        return String.format(
                Locale.US,
                "Sleep: %s h (%s) | Hydration: %s L (%s) | Training load today: %s workouts / %s min | Steps: %s",
                formatNumber(summary.sleepHours, 1),
                sleepBand,
                formatNumber(summary.waterLiters, 1),
                hydrationBand,
                formatWhole(summary.workouts),
                formatWhole(summary.workoutMinutes),
                formatWhole(summary.steps));
    }

    private String buildProgressSnapshot(Long userId) {
        if (userId == null) {
            return "Progress signals unavailable.";
        }

        List<WeightRecord> weights = weightRecordRepository.findByUserIdOrderByRecordedAtDesc(userId);
        Double latestWeight = weights.isEmpty() ? null : weights.get(0).weight;
        Double previousWeight = weights.size() > 1 ? weights.get(1).weight : null;
        Double delta = latestWeight != null && previousWeight != null ? latestWeight - previousWeight : null;

        List<BodyMeasurement> measurements = bodyMeasurementRepository.findByUserIdOrderByDateDesc(userId);
        BodyMeasurement latestMeasurement = measurements.isEmpty() ? null : measurements.get(0);

        return String.format(
                Locale.US,
                "Latest weight: %s kg | Weight delta vs previous check-in: %s kg | Latest waist: %s cm | Latest chest: %s cm",
                formatNumber(latestWeight, 1),
                formatSignedNumber(delta, 1),
                latestMeasurement == null ? "n/a" : formatNumber(latestMeasurement.getWaist(), 1),
                latestMeasurement == null ? "n/a" : formatNumber(latestMeasurement.getChest(), 1));
    }

    private String buildCoachingSignals(User user, AiCoachRequest.DailySummaryDto summary, String progressSnapshot) {
        StringBuilder signals = new StringBuilder();

        if (summary != null && summary.sleepHours != null && summary.sleepHours < 6.0) {
            signals.append("- Recovery risk: sleep is below 6h, avoid prescribing maximal intensity.\n");
        }
        if (summary != null && summary.waterLiters != null && summary.waterLiters < 1.5) {
            signals.append("- Hydration is low, include a concrete water target.\n");
        }
        if (summary != null && summary.avgCaloriesLast7Days != null && summary.calories != null) {
            int deltaCalories = summary.calories - summary.avgCaloriesLast7Days;
            if (Math.abs(deltaCalories) >= 250) {
                signals.append("- Today's calories differ from 7-day average by ")
                        .append(deltaCalories)
                        .append(" kcal.\n");
            }
        }
        if (summary != null && summary.targetCalories != null && summary.calories != null) {
            int calorieGap = summary.targetCalories - summary.calories;
            if (Math.abs(calorieGap) >= 150) {
                signals.append("- Daily calorie gap vs target: ")
                        .append(calorieGap > 0 ? "+" : "")
                        .append(calorieGap)
                        .append(" kcal remaining.\n");
            }
        }
        if (summary != null && summary.avgStepsLast7Days != null && summary.steps != null && summary.avgStepsLast7Days > 0) {
            int stepDelta = summary.steps - summary.avgStepsLast7Days;
            if (Math.abs(stepDelta) >= 1500) {
                signals.append("- Activity is ")
                        .append(stepDelta > 0 ? "above" : "below")
                        .append(" the 7-day step baseline by ")
                        .append(Math.abs(stepDelta))
                        .append(" steps.\n");
            }
        }
        if (user != null && user.weight != null && user.targetWeight != null) {
            double remaining = user.targetWeight - user.weight;
            if (Math.abs(remaining) >= 0.5) {
                signals.append("- Distance to target weight: ")
                        .append(String.format(Locale.US, "%.1f", remaining))
                        .append(" kg.\n");
            }
        }
        if (summary != null && summary.currentWeightKg != null && summary.targetWeightKg != null) {
            double remaining = summary.targetWeightKg - summary.currentWeightKg;
            if (Math.abs(remaining) >= 0.5) {
                signals.append("- Current recorded distance to target weight from daily summary: ")
                        .append(String.format(Locale.US, "%.1f", remaining))
                        .append(" kg.\n");
            }
        }
        if (summary != null && summary.bmi != null) {
            if (summary.bmi >= 30.0) {
                signals.append("- BMI is in a high range; prioritize sustainability, satiety, and low-impact consistency.\n");
            } else if (summary.bmi < 18.5) {
                signals.append("- BMI is in a low range; avoid aggressive deficits and prioritize recovery and nutrient density.\n");
            }
        }
        if (progressSnapshot.contains("Latest waist:") || progressSnapshot.contains("Latest weight:")) {
            signals.append("- Use progress signals to explain whether the user is trending toward the goal.\n");
        }

        if (signals.length() == 0) {
            return "No extra coaching signals.";
        }
        return signals.toString().trim();
    }

    private String buildWorkoutHistorySnapshot(Long userId, String question) {
        if (userId == null) return "";
        
        boolean deepQuery = false;
        if (question != null) {
            String qLower = question.toLowerCase(new Locale("tr", "TR"));
            if (qLower.contains("geçen") || qLower.contains("geçmiş") || qLower.contains("eski") || 
                qLower.contains("rekor") || qLower.contains("pr") || qLower.contains("ay") || 
                qLower.contains("önce") || qLower.contains("tarih") || qLower.contains("history") ||
                qLower.contains("bastım") || qLower.contains("bastim") || qLower.contains("yaptım") || 
                qLower.contains("yaptim") || qLower.contains("kaldırdım") || qLower.contains("kaldirdim") || 
                qLower.contains("max") || qLower.contains("en çok") || qLower.contains("en cok") || 
                qLower.contains("maksimum")) {
                deepQuery = true;
            }
        }
        
        LocalDateTime timeLimit = deepQuery ? LocalDateTime.now().minusDays(30) : LocalDateTime.now().minusDays(7);
        List<Workout> recent = workoutRepository
                .find("user.id = ?1 AND workoutDate >= ?2 ORDER BY workoutDate DESC", userId, timeLimit)
                .list();
        
        StringBuilder sb = new StringBuilder();
        if (!recent.isEmpty()) {
            sb.append(deepQuery ? "Last 30-day workout log:\n" : "Last 7-day workout log:\n");
            for (Workout w : recent) {
                sb.append(String.format(Locale.US, "- %s: %s%s (%s min%s) - Weight: %s kg, Sets: %s, Reps: %s, 1RM: %s\n",
                        w.workoutDate.toLocalDate(),
                        w.name != null ? w.name : "Workout",
                        w.muscleGroup != null ? " [" + w.muscleGroup + "]" : "",
                        w.durationMinutes != null ? w.durationMinutes : "?",
                        w.difficulty != null ? ", " + w.difficulty : "",
                        w.weight != null ? w.weight : "0",
                        w.sets != null ? w.sets : "0",
                        w.reps != null ? w.reps : "0",
                        w.oneRepMax != null ? w.oneRepMax : "n/a"));
            }
        }

        // If "rekor" or "pr" is requested, let's also fetch user's top workouts (Personal Records) by weight for each exercise
        if (question != null) {
            String qLower = question.toLowerCase(new Locale("tr", "TR"));
            if (qLower.contains("rekor") || qLower.contains("pr") || qLower.contains("en yüksek") || 
                qLower.contains("en yuksek") || qLower.contains("maksimum") || qLower.contains("en çok") || 
                qLower.contains("en cok") || qLower.contains("max") || qLower.contains("bastım") || 
                qLower.contains("bastim") || qLower.contains("kaldırdım") || qLower.contains("kaldirdim")) {
                List<Workout> prWorkouts = workoutRepository
                    .find("user.id = ?1 AND weight > 0.0 ORDER BY weight DESC", userId)
                    .list();
                if (!prWorkouts.isEmpty()) {
                    sb.append("\nUser Personal Records (PRs) by Exercise:\n");
                    java.util.Set<String> seenExercises = new java.util.HashSet<>();
                    for (Workout w : prWorkouts) {
                        String exerciseName = w.name.trim().toLowerCase();
                        if (!seenExercises.contains(exerciseName)) {
                            seenExercises.add(exerciseName);
                            sb.append(String.format(Locale.US, "- %s: %s kg (on %s, Sets: %s, Reps: %s, 1RM: %s)\n",
                                w.name,
                                w.weight,
                                w.workoutDate.toLocalDate(),
                                w.sets != null ? w.sets : "0",
                                w.reps != null ? w.reps : "0",
                                w.oneRepMax != null ? w.oneRepMax : "n/a"));
                        }
                    }
                }
            }
        }

        return sb.toString().trim();
    }

    private String safeText(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value.trim();
    }

    private String formatNumber(Double value, int scale) {
        if (value == null) {
            return "n/a";
        }
        return String.format(Locale.US, "%." + scale + "f", value);
    }

    private String formatSignedNumber(Double value, int scale) {
        if (value == null) {
            return "n/a";
        }
        return String.format(Locale.US, "%+." + scale + "f", value);
    }

    private String formatWhole(Integer value) {
        return value == null ? "0" : Integer.toString(value);
    }

    /**
     * Kullanıcının kilo/kalori tahminlerini ekler.
     */
    private String buildPredictionInsights(Long userId) {
        if (userId == null) return "";

        StringBuilder sb = new StringBuilder("\n--- PERFORMANCE PREDICTIONS ---\n");

        // Hedef kiloya ne zaman ulaşır?
        ProgressPredictionService.WeightProjection projection = progressPredictionService.predictWeeksToTarget(userId);
        if (projection != null) {
            sb.append("Weight Projection: ").append(projection.message).append("\n");
            if (projection.weeksToTarget != null) {
                sb.append("  Status: ").append(projection.status)
                  .append(" | Weekly change: ").append(String.format(Locale.US, "%.2f", projection.weeklyChangeKg))
                  .append(" kg | ETA: ").append(String.format(Locale.US, "%.1f", projection.weeksToTarget))
                  .append(" weeks\n");
            }
        }

        // Kalori dengesi
        ProgressPredictionService.CalorieBalance balance = progressPredictionService.calculateCalorieBalance(userId);
        if (balance != null && balance.avgDailyCalories > 0) {
            sb.append("Calorie Balance (last 14 days): ").append(balance.insight).append("\n");
            sb.append("  Avg daily: ").append(balance.avgDailyCalories)
              .append(" kcal | TDEE: ").append(String.format(Locale.US, "%.0f", balance.tdee))
              .append(" kcal | Daily balance: ").append(String.format(Locale.US, "%+.0f", balance.dailyBalance))
              .append(" kcal\n");
        }

        String result = sb.toString().trim();
        return result.isEmpty() ? "" : "\n" + result;
    }
}
