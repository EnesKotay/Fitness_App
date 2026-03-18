import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/notification_service.dart';
import '../nutrition/presentation/state/diet_provider.dart';
import '../auth/providers/auth_provider.dart';
import '../tasks/controllers/daily_tasks_controller.dart';
import '../tracking/providers/tracking_provider.dart';
import '../workout/providers/workout_provider.dart';
import '../weight/presentation/providers/weight_provider.dart';

class AppProviders {
  static List<SingleChildWidget> get providers => [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => DailyTasksController()..loadToday()),
        ChangeNotifierProvider(create: (_) => WeightProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
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
      ];
}
