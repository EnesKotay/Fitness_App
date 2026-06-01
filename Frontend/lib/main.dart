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

  // Backend'i sessizce uyandır (Render cold start için).
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
    // Render free tier cold start için backend'i sessizce uyandır.
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
            child: const SplashScreen(),
          ),
          routes: AppRoutes.getRoutes(),
        ),
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

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Merged listenable — build() içinde değil initState'te oluşturulur
  late final Listenable _logoAnims;

  // Logo entrance: scale + fade
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Glow pulse around logo
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowRadius;
  late final Animation<double> _glowOpacity;

  // Outer ring slow rotation
  late final AnimationController _ringCtrl;

  // Text + tagline entrance
  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  // Loader fade-in
  late final AnimationController _loaderCtrl;
  late final Animation<double> _loaderOpacity;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _logoScale = CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.elasticOut,
    ).drive(Tween<double>(begin: 0.55, end: 1.0));
    _logoOpacity = CurvedAnimation(
      parent: _logoCtrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _glowCtrl = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);
    _glowRadius = Tween<double>(
      begin: 28,
      end: 52,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _glowOpacity = Tween<double>(
      begin: 0.35,
      end: 0.65,
    ).animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _ringCtrl = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();

    _textCtrl = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _textOpacity = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));

    _loaderCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _loaderOpacity = CurvedAnimation(parent: _loaderCtrl, curve: Curves.easeIn);

    _logoAnims = Listenable.merge([_logoCtrl, _glowCtrl, _ringCtrl]);

    // Zincir: logo gir → 380ms bekle → text gir → 200ms bekle → loader gir
    _logoCtrl.forward().whenComplete(() async {
      await Future.delayed(const Duration(milliseconds: 80));
      if (mounted) _textCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) _loaderCtrl.forward();
    });

    // Provider'lar (özellikle ProxyProvider) ilk build'den sonra hazır olur;
    // build sırasında Navigator çağrısı yapılmamalı (setState during build hatası önlenir).
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _glowCtrl.dispose();
    _ringCtrl.dispose();
    _textCtrl.dispose();
    _loaderCtrl.dispose();
    super.dispose();
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

    // Profil setup sayfasının bir uygulama güncellemesi veya beklenmedik flag
    // kalıntısı yüzünden tekrar gösterilmemesi için tüm olası bayrakları temizle.
    // Bu ekran SADECE kayıt akışından açılır; splash her zaman /home'a gider.
    if (StorageHelper.getPendingInitialProfileSetup()) {
      await StorageHelper.savePendingInitialProfileSetup(false);
    }
    if (!context.mounted) return;

    // Var olan kullanıcıları (profil kurulumu dışında gelenler) için
    // onboarding bayrağını güncelle — profil yoksa bile spam etme.
    if (!StorageHelper.getOnboardingDone() && dietProvider.profile != null) {
      await StorageHelper.saveOnboardingDone(true);
    }
    if (!context.mounted) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    navigator.pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    const logoSize = 140.0;
    const accent = Color(0xFFCC7A4A);
    const accentLight = Color(0xFFE8955A);

    return Scaffold(
      backgroundColor: const Color(0xFF080D16),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arka plan gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF0A1020),
                  Color(0xFF080D16),
                  Color(0xFF06090F),
                  Color(0xFF110A08),
                ],
              ),
            ),
          ),
          // Sol alt sıcak glow
          Positioned(
            bottom: -120,
            left: -80,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [accent.withValues(alpha: 0.14), Colors.transparent],
                ),
              ),
            ),
          ),
          // Sağ üst mavi glow
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Ana içerik
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Amblem + glow + halka
                AnimatedBuilder(
                  animation: _logoAnims,
                  builder: (context, _) {
                    return ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: SizedBox(
                          width: logoSize + 60,
                          height: logoSize + 60,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Dış dönen süslemeli halka
                              Transform.rotate(
                                angle: _ringCtrl.value * 2 * 3.14159,
                                child: CustomPaint(
                                  size: const Size(
                                    logoSize + 56,
                                    logoSize + 56,
                                  ),
                                  painter: _RingPainter(
                                    color: accent,
                                    progress: _ringCtrl.value,
                                  ),
                                ),
                              ),
                              // Pulsing glow
                              Container(
                                width: logoSize + _glowRadius.value,
                                height: logoSize + _glowRadius.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      accent.withValues(
                                        alpha: _glowOpacity.value * 0.45,
                                      ),
                                      accentLight.withValues(
                                        alpha: _glowOpacity.value * 0.15,
                                      ),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              // İç yumuşak hale
                              Container(
                                width: logoSize + 18,
                                height: logoSize + 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withValues(
                                        alpha: _glowOpacity.value * 0.6,
                                      ),
                                      blurRadius: 30,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              // Logo ikonu
                              ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  logoSize * 0.24,
                                ),
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  width: logoSize,
                                  height: logoSize,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                // Başlık + tagline
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFE8D5C4)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'PusulaFit',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hedeflerine ulaş, sınırları aş',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 64),
                // Özel loading indicator
                FadeTransition(
                  opacity: _loaderOpacity,
                  child: const _SplashLoader(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dönen kompas/halka çizici
class _RingPainter extends CustomPainter {
  final Color color;
  final double progress;

  const _RingPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Ana halka — kesik çizgi efekti (4 segment)
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    const dashCount = 16;
    const dashAngle = 3.14159 * 2 / dashCount;
    const gapRatio = 0.45;
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * dashAngle;
      final sweepAngle = dashAngle * (1 - gapRatio);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }

    // Parlak kısa yay (döner)
    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.85),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        startAngle: 0,
        endAngle: 3.14159 * 2,
        transform: GradientRotation(progress * 3.14159 * 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * 3.14159 * 2,
      1.2,
      false,
      arcPaint,
    );

    // 4 köşe noktası (pusula yönleri)
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 4; i++) {
      final angle = i * 3.14159 / 2;
      final dx = center.dx + radius * _cos(angle);
      final dy = center.dy + radius * _sin(angle);
      canvas.drawCircle(Offset(dx, dy), 2.5, dotPaint);
    }
  }

  double _cos(double a) => (a == 0)
      ? 1
      : (a == 3.14159 / 2)
      ? 0
      : (a == 3.14159)
      ? -1
      : (a == 3 * 3.14159 / 2)
      ? 0
      : _cosApprox(a);

  double _sin(double a) => (a == 0)
      ? 0
      : (a == 3.14159 / 2)
      ? 1
      : (a == 3.14159)
      ? 0
      : (a == 3 * 3.14159 / 2)
      ? -1
      : _sinApprox(a);

  double _cosApprox(double a) {
    double x = a % (2 * 3.14159);
    if (x < 0) x += 2 * 3.14159;
    // Taylor yaklaşım yerine dart:math kullan
    return _mathCos(x);
  }

  double _sinApprox(double a) => _mathSin(a);

  // dart:math'e bridge (import dart:math dışında da çalışsın diye static)
  static double _mathCos(double a) {
    // Simple: cos(a) = sin(a + pi/2)
    // Use series: cos(x) = 1 - x²/2! + x⁴/4! - ...
    double x = a % (2 * 3.14159265);
    if (x < 0) x += 2 * 3.14159265;
    // Use built-in through dart:math
    return _cosLookup(x);
  }

  static double _mathSin(double a) => _sinLookup(a);

  static double _cosLookup(double x) {
    // Redirect to dart:math sin
    return _sinLookup(x + 1.5707963268);
  }

  static double _sinLookup(double x) {
    // Normalize
    x = x % (2 * 3.14159265358979);
    if (x < 0) x += 2 * 3.14159265358979;
    // Bhaskara I approximation
    final sign = (x < 3.14159265358979) ? 1.0 : -1.0;
    if (x > 3.14159265358979) x -= 3.14159265358979;
    return sign *
        (16 * x * (3.14159265358979 - x)) /
        (5 * 3.14159265358979 * 3.14159265358979 -
            4 * x * (3.14159265358979 - x));
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Özel splash loading göstergesi — üç nokta dalgası
class _SplashLoader extends StatefulWidget {
  const _SplashLoader();

  @override
  State<_SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<_SplashLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFCC7A4A);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Her nokta farklı fazda titreşiyor
            final phase = ((_ctrl.value - i * 0.18) % 1.0);
            final t = (phase < 0 ? phase + 1 : phase);
            // Yukarı-aşağı sinüs benzeri hareket
            final sinVal = _sinFor(t * 3.14159 * 2);
            final dy = -sinVal * 6.0;
            final scale = 0.75 + sinVal.abs() * 0.35;
            final opacity = 0.4 + sinVal.abs() * 0.6;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: opacity),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: opacity * 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _sinFor(double x) {
    // Bhaskara I
    x = x % (2 * 3.14159265358979);
    if (x < 0) x += 2 * 3.14159265358979;
    final sign = (x < 3.14159265358979) ? 1.0 : -1.0;
    if (x > 3.14159265358979) x -= 3.14159265358979;
    return sign *
        (16 * x * (3.14159265358979 - x)) /
        (5 * 3.14159265358979 * 3.14159265358979 -
            4 * x * (3.14159265358979 - x));
  }
}
