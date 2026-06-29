import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/storage_helper.dart';
import '../auth/providers/auth_provider.dart';
import '../workout/providers/workout_provider.dart';
import '../nutrition/presentation/state/diet_provider.dart';

/// Temiz, minimalist splash screen - sadece logo ve progress
class CleanSplashScreen extends StatefulWidget {
  const CleanSplashScreen({super.key});

  @override
  State<CleanSplashScreen> createState() => _CleanSplashScreenState();
}

class _CleanSplashScreenState extends State<CleanSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  double _progress = 0.0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
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
      // Check connectivity
      _updateProgress(0.2);
      await Future.delayed(const Duration(milliseconds: 300));

      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      // Check authentication
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

      // Not authenticated - go to login
      if (!authProvider.isAuthenticated) {
        _updateProgress(1.0);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // Load user data
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

      // Finalize
      _updateProgress(1.0);
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      // Clean up flags
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
                // Logo
                Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 48),

                // App name
                Text(
                  'PusulaFit',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),

                const SizedBox(height: 80),

                // Progress bar
                SizedBox(
                  width: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: AppColors.surfaceLight,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
