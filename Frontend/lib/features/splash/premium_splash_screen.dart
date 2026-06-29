import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/storage_helper.dart';
import '../auth/providers/auth_provider.dart';
import '../workout/providers/workout_provider.dart';
import '../nutrition/presentation/state/diet_provider.dart';

/// Premium splash screen - 3D lüks logo ile
class PremiumSplashScreen extends StatefulWidget {
  const PremiumSplashScreen({super.key});

  @override
  State<PremiumSplashScreen> createState() => _PremiumSplashScreenState();
}

class _PremiumSplashScreenState extends State<PremiumSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      _updateProgress(0.2);
      await Future.delayed(const Duration(milliseconds: 300));

      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      _updateProgress(0.4);
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
        debugPrint('Auth check error: $e');
      }

      if (!mounted) return;

      if (!authProvider.isAuthenticated) {
        _updateProgress(1.0);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      _updateProgress(0.6);
      if (!mounted) return;

      DietProvider? dietProvider;
      WorkoutProvider? workoutProvider;

      try {
        dietProvider = Provider.of<DietProvider>(context, listen: false);
        workoutProvider = Provider.of<WorkoutProvider>(context, listen: false);
      } catch (e) {
        debugPrint('Provider error: $e');
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      _updateProgress(0.8);
      final dataTimeout = isOffline
          ? const Duration(seconds: 2)
          : const Duration(seconds: 4);

      try {
        await dietProvider.init().timeout(
          dataTimeout,
          onTimeout: () {
            debugPrint('DietProvider timeout');
            return;
          },
        );

        final userId = authProvider.user?.id;
        if (userId != null && userId > 0) {
          await workoutProvider.loadWorkouts(userId).timeout(dataTimeout);
        }
      } catch (e) {
        debugPrint('Data init error: $e');
      }

      _updateProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      if (StorageHelper.getPendingInitialProfileSetup()) {
        await StorageHelper.savePendingInitialProfileSetup(false);
      }

      if (!StorageHelper.getOnboardingDone() && dietProvider.profile != null) {
        await StorageHelper.saveOnboardingDone(true);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (e) {
      debugPrint('Splash error: $e');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _updateProgress(double value) {
    if (!mounted) return;
    setState(() => _progress = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 3D Lüks Logo - Daha büyük
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.shade400.withOpacity(0.5),
                        blurRadius: 80,
                        spreadRadius: 25,
                      ),
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.4),
                        blurRadius: 60,
                        spreadRadius: 15,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 56),

                // App name - Gradient text
                ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      Colors.amber.shade200,
                      Colors.amber.shade400,
                      AppColors.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'PusulaFit',
                    style: TextStyle(
                      fontSize: 46,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2.5,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Tagline
                Text(
                  'Hedeflerine ulaş, sınırları aş',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withOpacity(0.9),
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 100),

                // Premium progress bar
                SizedBox(
                  width: 260,
                  child: Column(
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            // Background
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.border.withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            // Progress gradient
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                              height: 8,
                              width: 260 * _progress,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.amber.shade300,
                                    Colors.amber.shade500,
                                    AppColors.secondary,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.6),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Loading text
                      AnimatedOpacity(
                        opacity: _progress > 0 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _getLoadingText(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLoadingText() {
    if (_progress < 0.3) return 'Başlatılıyor...';
    if (_progress < 0.5) return 'Oturum kontrol ediliyor...';
    if (_progress < 0.7) return 'Veriler yükleniyor...';
    if (_progress < 0.9) return 'Neredeyse hazır...';
    return 'Hoş geldin!';
  }
}
