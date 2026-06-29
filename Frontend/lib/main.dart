import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart' show Options;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'core/services/iap_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_scheduler_service.dart';
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
import 'core/services/crash_reporting_service.dart';
import 'core/preferences/app_preferences.dart';
import 'core/routes/app_page_transitions.dart';
import 'core/widgets/global_offline_banner.dart';
import 'features/shell/app_providers.dart';
import 'features/splash/luxury_splash_screen.dart';
import 'core/utils/app_logger.dart'; // Added AppLogger import
import 'package:upgrader/upgrader.dart'; // Added upgrader import

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
  _installGlobalErrorHandlers();

  // 401 interceptor'ının global navigate için kullandığı key'i set et.
  ApiClient.navigatorKey = appNavigatorKey;

  // Notification service'e navigator key'i set et
  LocalNotificationService.instance.navigatorKey = appNavigatorKey;

  try {
    await HiveDietStorage.init();
  } catch (e) {
    debugPrint('HiveDietStorage init hatası: $e');
  }

  // Türkçe tarih formatı - arka planda yükle (main thread bloklamasın)
  unawaited(initializeDateFormatting('tr_TR'));

  if (CrashReportingService.canInitialize) {
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
    LocalNotificationService.instance
        .init()
        .then((_) async {
          // iOS badge'ini sıfırla (kırmızı bildirim sayısını kaldır)
          await LocalNotificationService.instance.clearAppBadge();
          await NotificationSchedulerService.instance
              .syncScheduledNotifications();
          await NotificationService().fetchNotifications(
            presentUnreadLocally: true,
          );
        })
        .catchError((e) {
          debugPrint('LocalNotificationService init hatası: $e');
        }),
  );

  unawaited(
    IapService.instance.init().catchError((e) {
      debugPrint('IapService init hatası: $e');
    }),
  );

  // Backend saglik kontrolunu sessizce calistir.
  // Splash ekranı gösterilirken arka planda çalışır, kullanıcıyı bekletmez.
  unawaited(_warmUpBackend());
}

void _installGlobalErrorHandlers() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    CrashReportingService.captureFlutterError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    CrashReportingService.captureException(
      error,
      stack,
      source: 'platform_dispatcher',
    );
    return true;
  };

  ErrorWidget.builder = (details) {
    CrashReportingService.captureFlutterError(details, source: 'error_widget');
    return Material(
      color: const Color(0xFF070B16),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBC374).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFEBC374).withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEBC374),
                    size: 26,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Bu bölüm yüklenemedi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uygulamayı kapatmadan başka bir ekrana geçebilirsin. Hata kaydı geliştiriciye iletilecek.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };
}

Future<void> _warmUpBackend() async {
  try {
    // ApiClient'ın varsayılan timeout'u kısa olduğundan Dio'yu doğrudan kullanıyoruz.
    await ApiClient().dio.get(
      '/api/auth/test',
      options: Options(
        sendTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
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
  void didHaveMemoryPressure() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    AppLogger.w('Memory pressure received; Flutter image cache cleared.');
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers,
      child: Consumer<AppPreferences>(
        builder: (context, prefs, _) => MaterialApp(
          title: 'PusulaFit',
          debugShowCheckedModeBanner: false,
          navigatorKey: appNavigatorKey,
          locale: prefs.effectiveLocale,
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          builder: (context, child) => GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.opaque,
            child: GlobalOfflineBanner(child: child ?? const SizedBox.shrink()),
          ),
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
          home: UpgradeAlert(
            upgrader: Upgrader(
              languageCode: 'tr',
              messages: UpgraderMessages(code: 'tr'),
            ),
            child: const LuxurySplashScreen(),
          ),
          routes: AppRoutes.getRoutes(),
        ),
      ),
    );
  }
}
