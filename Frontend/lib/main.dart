import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/ai_service.dart';
import 'core/utils/storage_helper.dart';
import 'features/nutrition/data/datasources/hive_diet_storage.dart';
import 'features/nutrition/presentation/state/diet_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/tracking/providers/tracking_provider.dart';
import 'features/workout/providers/workout_provider.dart';
import 'features/workout/presentation/providers/workout_catalog_provider.dart';
import 'features/nutrition/providers/nutrition_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/profile_screen.dart';
import 'features/weight/presentation/providers/weight_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'features/nutrition/presentation/pages/profile_setup_page.dart';
import 'features/shell/main_shell.dart';
import 'features/ai_coach/screens/ai_coach_screen.dart';
import 'features/ai_coach/controllers/ai_coach_controller.dart';
import 'features/ai_coach/models/ai_coach_models.dart';
import 'features/tasks/controllers/daily_tasks_controller.dart';
import 'features/tasks/screens/daily_tasks_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: "assets/.env");
  } catch (_) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('dotenv load error: $e');
    }
  }

  // Zorunlu: Token ve prefs init edilmeden getToken() kullanılmamalı; yoksa null döner ve login'e atar.
  await StorageHelper.init();

  try {
    await HiveDietStorage.init();
  } catch (_) {}

  // Türkçe tarih formatı - arka planda yükle (main thread bloklamasın)
  unawaited(initializeDateFormatting('tr_TR'));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TrackingProvider()),
        ChangeNotifierProvider(create: (_) => WeightProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutProvider()),
        ChangeNotifierProvider(create: (_) => NutritionProvider()),
        ChangeNotifierProvider(create: (_) => WorkoutCatalogProvider()),
        Provider(create: (_) => AIService()),
        ChangeNotifierProxyProvider3<
          WeightProvider,
          WorkoutProvider,
          AIService,
          DietProvider
        >(
          create: (_) => DietProvider(),
          update:
              (_, weightProvider, workoutProvider, aiService, dietProvider) =>
                  dietProvider!
                    ..setWeightProvider(weightProvider)
                    ..setWorkoutProvider(workoutProvider)
                    ..setAIService(aiService),
        ),
      ],
      child: MaterialApp(
        title: 'Fitness Tracker',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          AppRoutes.home: (context) => const MainShell(),
          AppRoutes.aiCoach: (context) {
            final nutrition = context.read<NutritionProvider>();
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
                .length;
            final summary = DailySummary(
              steps: 0,
              calories: nutrition.dailyCalories,
              waterLiters: 2.0,
              sleepHours: 7.0,
              workouts: todayWorkouts,
            );
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<AiCoachController>(
                  create: (_) => AiCoachController(initialSummary: summary),
                ),
                ChangeNotifierProvider<DailyTasksController>(
                  create: (_) => DailyTasksController()..loadToday(),
                ),
              ],
              child: const AiCoachScreenBody(),
            );
          },
          AppRoutes.dailyTasks: (context) => ChangeNotifierProvider(
            create: (_) => DailyTasksController()..loadToday(),
            child: const DailyTasksScreen(),
          ),
          '/profile': (context) => const ProfileScreen(),
          '/profile-setup': (context) => const ProfileSetupPage(),
        },
      ),
    );
  }
}

/// Splash Screen - Uygulama başlangıcında oturum kontrolü yapar
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Provider'lar (özellikle ProxyProvider) ilk build'den sonra hazır olur;
    // build sırasında Navigator çağrısı yapılmamalı (setState during build hatası önlenir).
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkAuth());
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    DietProvider? dietProvider;
    WeightProvider? weightProvider;
    try {
      dietProvider = Provider.of<DietProvider>(context, listen: false);
      weightProvider = Provider.of<WeightProvider>(context, listen: false);
    } catch (e) {
      debugPrint('Splash provider error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      await authProvider.checkAuthStatus().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('Splash auth error: $e');
    }

    if (!mounted) return;
    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      unawaited(weightProvider.loadEntries());
      await dietProvider.init().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Splash: DietProvider.init timeout, devam ediliyor.');
          return;
        },
      );
    } catch (e) {
      debugPrint('Splash init error: $e');
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    if (dietProvider.profile == null) {
      Navigator.of(context).pushReplacementNamed('/profile-setup');
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fitness_center,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Fitness Tracker',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
