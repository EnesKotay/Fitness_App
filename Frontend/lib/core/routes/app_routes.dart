import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../features/ai_coach/models/ai_coach_models.dart';
import '../../features/ai_coach/screens/ai_coach_screen.dart';
import '../../features/ai_coach/screens/ai_memory_screen.dart';
import '../../features/ai_coach/screens/weekly_plan_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/profile_screen.dart';
import '../../features/auth/screens/settings_help_screen.dart';
import '../../features/auth/screens/settings_notifications_screen.dart';
import '../../features/auth/screens/settings_nutrition_screen.dart';
import '../../features/workout/screens/achievements_screen.dart';
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
  static const aiMemory = '/ai-memory';
  static const weeklyPlan = '/weekly-plan';
  static const dailyTasks = '/daily-tasks';
  static const home = '/home';
  static const forgotPassword = '/forgot-password';

  /// Oturum açmamış kullanıcıyı login'e yönlendirir.
  static Widget _guard(BuildContext context, Widget child) {
    final isAuth = context.read<AuthProvider>().isAuthenticated;
    if (!isAuth) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      });
      return const SizedBox.shrink();
    }
    return child;
  }

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      '/login': (context) => const LoginScreen(),
      '/onboarding': (context) => const OnboardingPage(),
      home: (context) => _guard(context, const MainShell()),
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
          sleepHours: 0,
          workouts: todayWorkoutCount,
          workoutMinutes: todayWorkoutMinutes,
          workoutHighlights: todayWorkoutHighlights,
        );
        return _guard(context, AiCoachScreen(initialSummary: summary));
      },
      aiMemory: (context) => _guard(context, const AiMemoryScreen()),
      weeklyPlan: (context) => _guard(context, const WeeklyPlanScreen()),
      dailyTasks: (context) => _guard(context, const DailyTasksScreen()),
      '/profile': (context) => _guard(context, const ProfileScreen()),
      '/profile-setup': (context) => _guard(context, const ProfileSetupPage()),
      '/settings-password': (context) =>
          _guard(context, const SettingsPasswordScreen()),
      '/settings-notifications': (context) =>
          _guard(context, const SettingsNotificationsScreen()),
      '/settings-privacy': (context) =>
          _guard(context, const SettingsPrivacyScreen()),
      '/settings-nutrition': (context) =>
          _guard(context, const SettingsNutritionScreen()),

      '/settings-help': (context) =>
          _guard(context, const SettingsHelpScreen()),
      '/achievements': (context) =>
          _guard(context, const AchievementsScreen()),
      forgotPassword: (context) => const ForgotPasswordScreen(),
    };
  }
}
