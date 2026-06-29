import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/storage_helper.dart';
import '../auth/providers/auth_provider.dart';
import '../workout/providers/workout_provider.dart';
import '../nutrition/presentation/state/diet_provider.dart';

/// Ultra premium luxury splash screen - 3D logo + premium animasyonlar
class LuxurySplashScreen extends StatefulWidget {
  const LuxurySplashScreen({super.key});

  @override
  State<LuxurySplashScreen> createState() => _LuxurySplashScreenState();
}

class _LuxurySplashScreenState extends State<LuxurySplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _rotateController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _rotateAnimation;

  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    // Fade animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Scale animation - elastic bounce
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    // Glow pulse animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Subtle rotation
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _rotateAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    _scaleController.forward();
    _glowController.repeat(reverse: true);
    _rotateController.repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeApp());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _rotateController.dispose();
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
      backgroundColor: const Color(0xFF06080C),
      body: Stack(
        children: [
          // Background Gradient Canvas
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF05070A),
                    Color(0xFF0C0F17),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          // Aurora Blob 1: Top-Right Green Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
              ),
            ),
          ),

          // Aurora Blob 2: Bottom-Left Amber Glow
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFCC7A4A).withValues(alpha: 0.10),
              ),
            ),
          ),

          // Aurora Blob 3: Center-Right Indigo Glow
          Positioned(
            top: 300,
            right: -150,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A237E).withValues(alpha: 0.08),
              ),
            ),
          ),

          // Global Backdrop Blur for Mesh Background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 85, sigmaY: 85),
              child: const SizedBox.shrink(),
            ),
          ),

          // Content Layer
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 3D Luxury Logo - with rotate & glow animations
                            AnimatedBuilder(
                              animation: Listenable.merge([_glowAnimation, _rotateAnimation]),
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle: _rotateAnimation.value,
                                  child: Container(
                                    width: 260,
                                    height: 260,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFFEBC374).withValues(alpha: 0.25),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        // Outer glow - amber/gold
                                        BoxShadow(
                                          color: const Color(0xFFEBC374).withValues(alpha: 0.45 * _glowAnimation.value),
                                          blurRadius: 100 * _glowAnimation.value,
                                          spreadRadius: 30 * _glowAnimation.value,
                                        ),
                                        // Mid glow - orange
                                        BoxShadow(
                                          color: const Color(0xFFFF9800).withValues(alpha: 0.35 * _glowAnimation.value),
                                          blurRadius: 70 * _glowAnimation.value,
                                          spreadRadius: 20 * _glowAnimation.value,
                                        ),
                                        // Inner glow - green
                                        BoxShadow(
                                          color: const Color(0xFF2E7D32).withValues(alpha: 0.25 * _glowAnimation.value),
                                          blurRadius: 50 * _glowAnimation.value,
                                          spreadRadius: 10 * _glowAnimation.value,
                                        ),
                                      ],
                                    ),
                                    child: child,
                                  ),
                                );
                              },
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/images/app_icon.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            const SizedBox(height: 56),

                            // App name - Premium gradient with shadow
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  Color(0xFFFFF6E0),
                                  Color(0xFFEBC374),
                                  Color(0xFFCC7A4A),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: Text(
                                'PusulaFit',
                                style: GoogleFonts.outfit(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Premium tagline
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.95),
                                  const Color(0xFFEBC374).withValues(alpha: 0.85),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                'Hedeflerine ulaş, sınırları aş',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),

                            const SizedBox(height: 80),

                            // Ultra premium progress bar
                            SizedBox(
                              width: 280,
                              child: Column(
                                children: [
                                  // Progress bar container
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: Stack(
                                        children: [
                                          // Background
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.03),
                                              border: Border.all(
                                                color: Colors.white.withValues(alpha: 0.08),
                                                width: 1.0,
                                              ),
                                              borderRadius: BorderRadius.circular(15),
                                            ),
                                          ),
                                          // Animated progress gradient
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 400),
                                            curve: Curves.easeOutCubic,
                                            width: 280 * _progress,
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFEBC374),
                                                  Color(0xFFCC7A4A),
                                                  Color(0xFF2E7D32),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(15),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFFEBC374).withValues(alpha: 0.5),
                                                  blurRadius: 12,
                                                  spreadRadius: 2,
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Shimmer overlay
                                          if (_progress > 0)
                                            AnimatedBuilder(
                                              animation: _glowController,
                                              builder: (context, child) {
                                                return Container(
                                                  width: 280 * _progress,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.centerLeft,
                                                      end: Alignment.centerRight,
                                                      colors: [
                                                        Colors.white.withValues(alpha: 0),
                                                        Colors.white.withValues(alpha: 0.25 * _glowAnimation.value),
                                                        Colors.white.withValues(alpha: 0),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Loading text with fade
                                  AnimatedOpacity(
                                    opacity: _progress > 0 ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 350),
                                    child: Text(
                                      _getLoadingText(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: _progress >= 1.0
                                            ? const Color(0xFFEBC374)
                                            : Colors.white.withValues(alpha: 0.65),
                                        letterSpacing: 0.8,
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
                ),
              ),
            ),
          ),
        ],
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
