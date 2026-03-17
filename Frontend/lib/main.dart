import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/iap_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/utils/storage_helper.dart';
import 'features/nutrition/data/datasources/hive_diet_storage.dart';
import 'features/nutrition/presentation/state/diet_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/workout/providers/workout_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_routes.dart';
import 'core/routes/app_page_transitions.dart';
import 'features/shell/app_providers.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Zorunlu: Token ve prefs init edilmeden getToken() kullanılmamalı; yoksa null döner ve login'e atar.
  await StorageHelper.init();

  try {
    await HiveDietStorage.init();
  } catch (e) {
    debugPrint('HiveDietStorage init hatası: $e');
  }

  // Türkçe tarih formatı - arka planda yükle (main thread bloklamasın)
  unawaited(initializeDateFormatting('tr_TR'));

  runApp(const MyApp());

  unawaited(
    LocalNotificationService.instance.init().catchError((e) {
      debugPrint('LocalNotificationService init hatası: $e');
    }),
  );

  unawaited(
    IapService.instance.init().catchError((e) {
      debugPrint('IapService init hatası: $e');
    }),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: MaterialApp(
        title: 'FitMentor',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: AppPageTransitionsBuilder(),
              TargetPlatform.iOS: AppPageTransitionsBuilder(),
              TargetPlatform.macOS: AppPageTransitionsBuilder(),
              TargetPlatform.windows: AppPageTransitionsBuilder(),
              TargetPlatform.linux: AppPageTransitionsBuilder(),
            },
          ),
        ),
        home: const SplashScreen(),
        routes: AppRoutes.getRoutes(),
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
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );
    DietProvider? dietProvider;
    try {
      dietProvider = Provider.of<DietProvider>(context, listen: false);
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
      await dietProvider.init().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('Splash: DietProvider.init timeout, devam ediliyor.');
          return;
        },
      );
      final userId = authProvider.user?.id;
      if (userId != null && userId > 0) {
        try {
          await workoutProvider
              .loadWorkouts(userId)
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('Splash workout init error: $e');
        }
      }
    } catch (e) {
      debugPrint('Splash init error: $e');
    }

    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 80));
    if (!mounted) return;

    // Onboarding kontrolü — giriş yapılmışsa atla (yeniden kurulum senaryosu)
    final onboardingDone =
        StorageHelper.getOnboardingDone() || authProvider.isAuthenticated;
    if (onboardingDone) await StorageHelper.saveOnboardingDone(true);

    if (!mounted) return;

    if (!onboardingDone) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }

    final shouldShowProfileSetup =
        authProvider.isAuthenticated &&
        dietProvider.error == null &&
        dietProvider.profile == null;

    Navigator.of(context).pushReplacementNamed(
      shouldShowProfileSetup ? '/profile-setup' : AppRoutes.home,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/app_icon.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            Text(
              'FitMentor',
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
