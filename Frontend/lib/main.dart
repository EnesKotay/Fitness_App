import 'dart:async';
import 'package:dio/dio.dart' show Options;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/iap_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/utils/storage_helper.dart';
import 'features/nutrition/data/datasources/hive_diet_storage.dart';
import 'features/nutrition/presentation/state/diet_provider.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/workout/providers/workout_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/theme/app_theme.dart';
import 'core/api/api_client.dart';
import 'core/routes/app_routes.dart';
import 'core/config/app_secrets.dart';
import 'core/routes/app_page_transitions.dart';
import 'core/widgets/global_offline_banner.dart';
import 'features/shell/app_providers.dart';
import 'core/utils/app_logger.dart'; // Added AppLogger import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Genel Logger Entegrasyonu: Tüm debugPrint çağrılarını logger paketine yönlendir.
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null && message.isNotEmpty) {
      AppLogger.d(message);
    }
  };

  // Zorunlu: Token ve prefs init edilmeden getToken() kullanılmamalı; yoksa null döner ve login'e atar.
  await StorageHelper.init();

  // 401 interceptor'ının global navigate için kullandığı key'i set et.
  ApiClient.navigatorKey = appNavigatorKey;

  try {
    await HiveDietStorage.init();
  } catch (e) {
    debugPrint('HiveDietStorage init hatası: $e');
  }

  // Türkçe tarih formatı - arka planda yükle (main thread bloklamasın)
  unawaited(initializeDateFormatting('tr_TR'));

  if (AppSecrets.sentryDsn.isNotEmpty) {
    await SentryFlutter.init((options) {
      options.dsn = AppSecrets.sentryDsn;
      options.tracesSampleRate = 0.2;
      options.environment = const bool.fromEnvironment('dart.vm.product')
          ? 'production'
          : 'development';
    }, appRunner: () => runApp(const MyApp()));
  } else {
    runApp(const MyApp());
  }

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

  // Backend'i sessizce uyandır (Render cold start için).
  // Splash ekranı gösterilirken arka planda çalışır, kullanıcıyı bekletmez.
  unawaited(_warmUpBackend());
}

Future<void> _warmUpBackend() async {
  try {
    // Render free tier cold start için backend'i sessizce uyandır.
    // ApiClient'ın varsayılan timeout'u kısa olduğundan Dio'yu doğrudan kullanıyoruz.
    await ApiClient().dio.get(
      '/api/auth/test',
      options: Options(
        sendTimeout: const Duration(seconds: 90),
        receiveTimeout: const Duration(seconds: 90),
      ),
    );
  } catch (_) {
    // Hata sessizce yutulur — warmup başarısız olsa bile uygulama çalışır.
  }
}

/// 401 / global navigate için kullanılan key. ApiClient'tan erişilebilir.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      IapService.instance.cancelSubscription();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: MaterialApp(
        title: 'FitMentor',
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        builder: (context, child) =>
            GlobalOfflineBanner(child: child ?? const SizedBox.shrink()),
        themeMode: ThemeMode.dark,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme.copyWith(
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    if (mounted) await _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final workoutProvider = Provider.of<WorkoutProvider>(
      context,
      listen: false,
    );

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    final authTimeout = isOffline
        ? const Duration(seconds: 1)
        : const Duration(seconds: 3);
    final dataTimeout = isOffline
        ? const Duration(seconds: 2)
        : const Duration(seconds: 4);
    if (!mounted) return;

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
        authTimeout,
        onTimeout: () => null,
      );
    } catch (e) {
      debugPrint('Splash auth error: $e');
    }

    if (!mounted) return;
    if (!authProvider.isAuthenticated) {
      if (isOffline) {
        // Offline and no auth -> force to login
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    try {
      await dietProvider.init().timeout(
        dataTimeout,
        onTimeout: () {
          debugPrint('Splash: DietProvider.init timeout, devam ediliyor.');
          return;
        },
      );
      final userId = authProvider.user?.id;
      if (userId != null && userId > 0) {
        try {
          await workoutProvider.loadWorkouts(userId).timeout(dataTimeout);
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

    if (!authProvider.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    // Eski kurulumlardan gelen onboarding durumunu authenticated kullanıcı için
    // korunmuş kabul ediyoruz; yeni rehber artık kayıt tamamlandıktan sonra gösteriliyor.
    if (!StorageHelper.getOnboardingDone()) {
      await StorageHelper.saveOnboardingDone(true);
    }
    if (!context.mounted) return;

    final shouldShowProfileSetup =
        authProvider.isAuthenticated &&
        dietProvider.error == null &&
        dietProvider.profile == null;
    final nextRoute = shouldShowProfileSetup
        ? '/profile-setup'
        : AppRoutes.home;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushReplacementNamed(nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/app_icon.png', width: 100, height: 100),
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
