import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/storage_helper.dart';
import '../auth/providers/auth_provider.dart';
import '../workout/providers/workout_provider.dart';
import '../nutrition/presentation/state/diet_provider.dart';

/// Modern, animated splash screen with loading states
class ModernSplashScreen extends StatefulWidget {
  const ModernSplashScreen({super.key});

  @override
  State<ModernSplashScreen> createState() => _ModernSplashScreenState();
}

class _ModernSplashScreenState extends State<ModernSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _particleController;
  late AnimationController _progressController;

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _glowIntensity;

  String _loadingStatus = 'Başlatılıyor...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    // Logo entrance animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: Curves.elasticOut,
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Pulse animation for glow
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowIntensity = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Particle animation (for background)
    _particleController = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Progress animation
    _progressController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    // Start animations
    _logoController.forward();
    _progressController.forward();

    // Initialize app
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      // Phase 1: Check connectivity
      _updateStatus('Bağlantı kontrol ediliyor...', 0.15);
      await Future.delayed(const Duration(milliseconds: 300));

      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      // Phase 2: Check authentication
      _updateStatus('Oturum kontrol ediliyor...', 0.35);
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final authTimeout = isOffline
          ? const Duration(seconds: 1)
          : const Duration(seconds: 3);

      try {
        await authProvider.checkAuthStatus().timeout(
          authTimeout,
          onTimeout: () => null,
        );
      } catch (e) {
        debugPrint('Splash auth error: $e');
      }

      if (!mounted) return;

      // Not authenticated - go to login
      if (!authProvider.isAuthenticated) {
        _updateStatus('Giriş ekranına yönlendiriliyor...', 1.0);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // Phase 3: Load user data
      _updateStatus('Profil yükleniyor...', 0.55);
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;
      DietProvider? dietProvider;
      WorkoutProvider? workoutProvider;

      try {
        dietProvider = Provider.of<DietProvider>(context, listen: false);
        workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
      } catch (e) {
        debugPrint('Splash provider error: $e');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      final dataTimeout = isOffline
          ? const Duration(seconds: 2)
          : const Duration(seconds: 4);

      try {
        await dietProvider.init().timeout(
          dataTimeout,
          onTimeout: () {
            debugPrint('DietProvider.init timeout');
            return;
          },
        );

        _updateStatus('Antrenman planı hazırlanıyor...', 0.75);
        await Future.delayed(const Duration(milliseconds: 400));

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

      // Phase 4: Finalize
      _updateStatus('Neredeyse hazır!', 0.95);
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      // Clean up onboarding flags
      if (StorageHelper.getPendingInitialProfileSetup()) {
        await StorageHelper.savePendingInitialProfileSetup(false);
      }

      if (!StorageHelper.getOnboardingDone() && dietProvider.profile != null) {
        await StorageHelper.saveOnboardingDone(true);
      }

      _updateStatus('Hoş geldin!', 1.0);
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (e) {
      debugPrint('Splash error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _updateStatus(String status, double progress) {
    if (!mounted) return;
    setState(() {
      _loadingStatus = status;
      _progress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      0.3 * (_particleController.value * 2 - 1),
                      -0.2,
                    ),
                    radius: 1.5,
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.secondary.withOpacity(0.10),
                      AppColors.background,
                      AppColors.background,
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              );
            },
          ),

          // Floating particles
          ...List.generate(20, (index) {
            final dx = (index % 5) * 0.25;
            final dy = (index ~/ 5) * 0.25;
            return Positioned(
              left: size.width * dx,
              top: size.height * dy,
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  final offset = (_particleController.value + index * 0.05) % 1.0;
                  return Opacity(
                    opacity: 0.15 * (1 - offset),
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index % 2 == 0
                            ? AppColors.primary
                            : AppColors.secondary,
                      ),
                    ),
                  );
                },
              ),
            );
          }),

          // Main content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow
                AnimatedBuilder(
                  animation: Listenable.merge([_logoController, _pulseController]),
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _logoScale.value,
                      child: Opacity(
                        opacity: _logoFade.value,
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(
                                  0.4 * _glowIntensity.value,
                                ),
                                blurRadius: 80 * _glowIntensity.value,
                                spreadRadius: 20 * _glowIntensity.value,
                              ),
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(
                                  0.3 * _glowIntensity.value,
                                ),
                                blurRadius: 60 * _glowIntensity.value,
                                spreadRadius: 10 * _glowIntensity.value,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo_premium.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 48),

                // App name with gradient
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight,
                      AppColors.secondary,
                    ],
                  ).createShader(bounds),
                  child: const Text(
                    'PusulaFit',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms, duration: 600.ms)
                    .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 12),

                // Tagline
                Text(
                  'Fitness Yolculuğunun Pusulası',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 600.ms)
                    .slideY(begin: 0.3, end: 0),
              ],
            ),
          ),

          // Loading indicator at bottom
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Loading status text
                Text(
                  _loadingStatus,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 400.ms),

                const SizedBox(height: 20),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        // Background
                        Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        // Progress with gradient
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOut,
                          height: 4,
                          width: size.width * 0.8 * _progress,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryLight,
                                AppColors.secondary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 900.ms, duration: 400.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
