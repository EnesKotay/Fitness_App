import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/ai_coach/models/ai_coach_models.dart';
import '../../features/ai_coach/screens/ai_coach_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/auth/screens/settings_notifications_screen.dart';
import '../../features/auth/screens/settings_password_screen.dart';
import '../../features/auth/screens/settings_privacy_screen.dart';
import '../../features/nutrition/presentation/pages/profile_setup_page.dart';
import '../../features/nutrition/presentation/state/diet_provider.dart';
import '../../features/onboarding/onboarding_page.dart';
import '../../features/shell/main_shell.dart';
import '../../features/tasks/screens/daily_tasks_screen.dart';
import '../../features/workout/providers/workout_provider.dart';

class AppRoutes {
  AppRoutes._();

  static const aiCoach = '/ai-coach';
  static const dailyTasks = '/daily-tasks';
  static const home = '/home';
  static const forgotPassword = '/forgot-password';
  static const verifyPin = '/verify-pin';
  static const resetPassword = '/reset-password';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      '/login': (context) => const LoginScreen(),
      '/onboarding': (context) => const OnboardingPage(),
      home: (context) => const MainShell(),
      aiCoach: (context) {
        final dietProvider = context.read<DietProvider>();
        final workout = context.read<WorkoutProvider>();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todayWorkouts = workout.workouts
            .where(
              (w) =>
                  w.workoutDate.year == today.year &&
                  w.workoutDate.month == today.month &&
                  w.workoutDate.day == today.day,
            )
            .toList();
        final todayWorkoutCount = todayWorkouts.length;
        final todayWorkoutMinutes = todayWorkouts.fold<int>(
          0,
          (sum, w) => sum + (w.durationMinutes ?? 0),
        );
        final todayWorkoutHighlights = todayWorkouts
            .map((w) => w.name.trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .take(6)
            .toList();
        final summary = DailySummary(
          steps: 0,
          calories: dietProvider.totals.totalKcal.round(),
          waterLiters: dietProvider.waterLiters,
          sleepHours: 7.0,
          workouts: todayWorkoutCount,
          workoutMinutes: todayWorkoutMinutes,
          workoutHighlights: todayWorkoutHighlights,
        );
        return AiCoachScreen(initialSummary: summary);
      },
      dailyTasks: (context) => const DailyTasksScreen(),
      '/profile': (context) => const ProfileScreen(),
      '/profile-setup': (context) => const ProfileSetupPage(),
      '/settings-password': (context) => const SettingsPasswordScreen(),
      '/settings-notifications': (context) =>
          const SettingsNotificationsScreen(),
      '/settings-privacy': (context) => const SettingsPrivacyScreen(),
      forgotPassword: (context) => const ForgotPasswordScreen(),
    };
  }
}
