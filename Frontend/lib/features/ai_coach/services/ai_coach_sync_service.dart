import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ai_coach_controller.dart';
import '../models/ai_coach_models.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../../../core/utils/storage_helper.dart';

class AiCoachSyncService {
  static Future<void> syncUserData(BuildContext context) async {
    if (!context.mounted) return;

    final controller = context.read<AiCoachController>();
    final diet = context.read<DietProvider>();
    final workout = context.read<WorkoutProvider>();
    final weight = context.read<WeightProvider>();

    final calories = diet.totals.totalKcal.round();
    final todayWorkouts = workout.workoutsForSelectedDate;
    final workoutMinutes = todayWorkouts.fold<int>(
      0,
      (sum, w) => sum + (w.durationMinutes ?? 0),
    );
    final highlights = todayWorkouts.map((w) => w.name).take(5).toList();

    final proteinGrams = diet.totals.totalProtein > 0 ? diet.totals.totalProtein.round() : null;
    final carbsGrams = diet.totals.totalCarb > 0 ? diet.totals.totalCarb.round() : null;
    final fatGrams = diet.totals.totalFat > 0 ? diet.totals.totalFat.round() : null;
    final allowPersonalization = StorageHelper.getPrivacyPersonalization();

    final mealNames = allowPersonalization
        ? diet.entries.map((e) => e.foodName).take(6).toList()
        : const <String>[];

    final profile = allowPersonalization ? diet.profile : null;
    final userAge = profile?.age;
    final userHeightCm = profile?.height;
    final userGender = profile?.gender.name;
    final activityLevel = profile?.activityLevel.name;
    final tdee = profile?.tdee.round();

    final weeklyWeightChangeKg = allowPersonalization && weight.entries.isNotEmpty
        ? weight.weeklyChange
        : null;
    final weightStreak = allowPersonalization && weight.currentStreak > 0
        ? weight.currentStreak
        : null;

    int? avgCalories;
    double? avgWater;

    try {
      final logs = allowPersonalization ? await diet.getRecentDaysLogs(7) : const [];
      if (!context.mounted) return;
      if (logs.isNotEmpty) {
        final totalKcal = logs.fold<double>(0, (sum, l) => sum + l.totalKcal);
        final totalWater = logs.fold<double>(0, (sum, l) => sum + (l.totalKcal > 0 ? 2.0 : 0.0));
        avgCalories = (totalKcal / logs.length).round();
        avgWater = totalWater / logs.length;
      }
    } catch (e) {
      debugPrint('Error calculating averages for AI Coach: $e');
    }

    controller.setDailySummary(
      DailySummary(
        steps: null,
        calories: calories,
        waterLiters: diet.waterLiters,
        sleepHours: null,
        workouts: todayWorkouts.length,
        workoutMinutes: workoutMinutes,
        workoutHighlights: highlights,
        avgCaloriesLast7Days: allowPersonalization ? avgCalories : null,
        avgWaterLast7Days: allowPersonalization ? avgWater : null,
        avgStepsLast7Days: null,
        targetCalories: diet.dailyTargetKcal?.round(),
        currentWeightKg: allowPersonalization ? diet.profile?.weight : null,
        targetWeightKg: allowPersonalization ? diet.profile?.targetWeight : null,
        bmi: allowPersonalization && diet.bmi > 0 ? diet.bmi : null,
        proteinGrams: allowPersonalization ? proteinGrams : null,
        carbsGrams: allowPersonalization ? carbsGrams : null,
        fatGrams: allowPersonalization ? fatGrams : null,
        mealNames: mealNames,
        weeklyWeightChangeKg: weeklyWeightChangeKg,
        weightStreak: weightStreak,
        userAge: userAge,
        userHeightCm: userHeightCm,
        userGender: userGender,
        activityLevel: activityLevel,
        tdee: tdee,
        workoutLocation: StorageHelper.getWorkoutLocation(),
        equipmentType: StorageHelper.getEquipmentType(),
      ),
    );

    if (profile != null) {
      controller.setGoal(profile.goal);
    }
  }
}
