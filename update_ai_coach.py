import re

# 1. Create AiCoachSyncService
sync_service_code = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/ai_coach_controller.dart';
import '../models/ai_coach_models.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../weight/presentation/providers/weight_provider.dart';

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

    final mealNames = diet.entries.map((e) => e.foodName).take(6).toList();

    final profile = diet.profile;
    final userAge = profile?.age;
    final userHeightCm = profile?.height;
    final userGender = profile?.gender.name;
    final activityLevel = profile?.activityLevel.name;
    final tdee = profile?.tdee.round();

    final weeklyWeightChangeKg = weight.entries.isNotEmpty ? weight.weeklyChange : null;
    final weightStreak = weight.currentStreak > 0 ? weight.currentStreak : null;

    int? avgCalories;
    double? avgWater;

    try {
      final logs = await diet.getRecentDaysLogs(7);
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
        avgCaloriesLast7Days: avgCalories,
        avgWaterLast7Days: avgWater,
        avgStepsLast7Days: null,
        targetCalories: diet.dailyTargetKcal?.round(),
        currentWeightKg: diet.profile?.weight,
        targetWeightKg: diet.profile?.targetWeight,
        bmi: diet.bmi > 0 ? diet.bmi : null,
        proteinGrams: proteinGrams,
        carbsGrams: carbsGrams,
        fatGrams: fatGrams,
        mealNames: mealNames,
        weeklyWeightChangeKg: weeklyWeightChangeKg,
        weightStreak: weightStreak,
        userAge: userAge,
        userHeightCm: userHeightCm,
        userGender: userGender,
        activityLevel: activityLevel,
        tdee: tdee,
      ),
    );

    if (diet.profile != null) {
      controller.setGoal(diet.profile!.goal);
    }
  }
}
"""

with open('Frontend/lib/features/ai_coach/services/ai_coach_sync_service.dart', 'w') as f:
    f.write(sync_service_code)

# 2. Modify ai_coach_screen.dart
file_path = 'Frontend/lib/features/ai_coach/screens/ai_coach_screen.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Add imports and part directive
if "import '../services/ai_coach_sync_service.dart';" not in content:
    content = content.replace(
        "import '../services/ai_coach_usage_service.dart';",
        "import '../services/ai_coach_usage_service.dart';\nimport '../services/ai_coach_sync_service.dart';"
    )

if "part 'ai_coach_screen_components.dart';" not in content:
    content = re.sub(
        r'(class AiCoachScreen extends StatelessWidget \{)',
        r"part 'ai_coach_screen_components.dart';\n\n\1",
        content
    )

# Replace _syncUserData body
sync_pattern = r'Future<void> _syncUserData\(\) async \{.*?\s+if \(diet\.profile != null\) \{\s+controller\.setGoal\(diet\.profile!\.goal\);\s+\}\s+\}'
new_sync_method = r'''Future<void> _syncUserData() async {
    await AiCoachSyncService.syncUserData(context);
  }'''
content = re.sub(sync_pattern, new_sync_method, content, flags=re.DOTALL)

# Add Glassmorphism to input area (already has some, but let's tweak the background opacity)
content = content.replace('color: Colors.black.withValues(alpha: 0.24)', 'color: Colors.black.withValues(alpha: 0.35)')

# Add Glow to Compact Mode Bar
glow_boxshadow = '''                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: _brandBlue.withValues(alpha: 0.35),
                            blurRadius: 16,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,'''
content = re.sub(
    r'(borderRadius: BorderRadius\.circular\(999\),\s+border: Border\.all\([^)]+\),\s*\n\s+\),)',
    r'\1\n' + glow_boxshadow,
    content
)

# Improve ChatBubble animation
content = content.replace(
    '.slideY(begin: 0.08, end: 0)',
    '.slideY(begin: 0.25, end: 0, duration: 650.ms, curve: Curves.elasticOut)'
)
content = content.replace(
    '.fadeIn(duration: 320.ms, curve: Curves.easeOut)',
    '.fadeIn(duration: 400.ms, curve: Curves.easeOut)'
)

# Extract components to ai_coach_screen_components.dart
components_match = re.search(r'class _AnimatedMeshBackground extends StatefulWidget \{.*', content, flags=re.DOTALL)
if components_match:
    components_code = components_match.group(0)
    
    # Save components file
    with open('Frontend/lib/features/ai_coach/screens/ai_coach_screen_components.dart', 'w') as f:
        f.write("part of 'ai_coach_screen.dart';\n\n" + components_code)
    
    # Remove components from main file
    content = content[:components_match.start()].strip() + '\n'

with open(file_path, 'w') as f:
    f.write(content)

print("SUCCESS")
