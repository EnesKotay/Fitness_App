import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/notification_service.dart';
import '../nutrition/presentation/state/diet_provider.dart';
import '../auth/providers/auth_provider.dart';
import '../tasks/controllers/daily_tasks_controller.dart';
import '../tracking/providers/tracking_provider.dart';
import '../workout/providers/workout_provider.dart';
import '../workout/providers/workout_program_provider.dart';
import '../workout/providers/streak_provider.dart';
import '../weight/presentation/providers/weight_provider.dart';
import '../ai_coach/providers/weekly_plan_provider.dart';
import '../recipes/presentation/state/recipe_provider.dart';

class AppProviders {
  static List<SingleChildWidget> get providers => [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => DailyTasksController()..loadToday()),
        ChangeNotifierProvider(create: (_) => WeightProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProgramProvider()..load()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => StreakProvider()..init()),
        ChangeNotifierProvider(create: (_) => WeeklyPlanProvider()..init()),
        ChangeNotifierProvider(create: (_) => RecipeProvider()),
        Provider(create: (_) => AIService()),
        ChangeNotifierProxyProvider3<
            WeightProvider,
            WorkoutProvider,
            AIService,
            DietProvider>(
          create: (_) => DietProvider(),
          update: (_, weightProvider, workoutProvider, aiService, dietProvider) =>
              dietProvider!
                ..setWeightProvider(weightProvider)
                ..setWorkoutProvider(workoutProvider)
                ..setAIService(aiService),
        ),
        // Logout callback'lerini wire-up et: AuthProvider logout/deleteAccount
        // çağrıldığında tüm provider'lar otomatik reset edilir.
        ProxyProvider6<
            AuthProvider,
            DietProvider,
            WorkoutProvider,
            WeightProvider,
            TrackingProvider,
            DailyTasksController,
            void>(
          create: (_) {},
          update: (
            _,
            auth,
            diet,
            workout,
            weight,
            tracking,
            tasks,
            _,
          ) {
            auth.addLogoutCallback(diet.reset);
            auth.addLogoutCallback(workout.reset);
            auth.addLogoutCallback(weight.reset);
            auth.addLogoutCallback(tracking.reset);
            auth.addLogoutCallback(tasks.reset);
          },
        ),
      ];
}
