import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/storage_helper.dart';
import '../../../core/utils/validators.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

/// Temiz, modern, ultra-premium login ekranı
class CleanLoginScreen extends StatefulWidget {
  const CleanLoginScreen({super.key});

  @override
  State<CleanLoginScreen> createState() => _CleanLoginScreenState();
}

class _CleanLoginScreenState extends State<CleanLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _obscure = true;
  bool _remember = false;
  String? _loadingMsg;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    final saved = StorageHelper.getRememberedEmail();
    if (saved != null && saved.isNotEmpty) {
      _emailCtrl.text = saved;
      _remember = true;
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _loadingMsg = 'Sunucu başlatılıyor...');
      }
    });
  }

  void _stopTimer() {
    _loadingTimer?.cancel();
    if (mounted) setState(() => _loadingMsg = null);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _startTimer();
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.login(_emailCtrl.text.trim(), _passwordCtrl.text);

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Giriş başarısız'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (_remember) {
        await StorageHelper.saveRememberedEmail(_emailCtrl.text.trim());
      } else {
        await StorageHelper.clearRememberedEmail();
      }

      if (!mounted) return;

      final dietProvider = Provider.of<DietProvider>(context, listen: false);
      final workoutProvider =
          Provider.of<WorkoutProvider>(context, listen: false);

      await dietProvider.init();
      final userId = auth.user?.id;
      if (userId != null) {
        await workoutProvider.loadWorkouts(userId);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _stopTimer();
    }
  }

  Future<void> _handleGoogle() async {
    _startTimer();
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.loginWithGoogle();

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Google giriş başarısız'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final dietProvider = Provider.of<DietProvider>(context, listen: false);
      final workoutProvider =
          Provider.of<WorkoutProvider>(context, listen: false);

      await dietProvider.init();
      final userId = auth.user?.id;
      if (userId != null) {
        await workoutProvider.loadWorkouts(userId);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _stopTimer();
    }
  }

  Future<void> _handleApple() async {
    _startTimer();
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final success = await auth.loginWithApple();

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(auth.errorMessage ?? 'Apple giriş başarısız'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      final dietProvider = Provider.of<DietProvider>(context, listen: false);
      final workoutProvider =
          Provider.of<WorkoutProvider>(context, listen: false);

      await dietProvider.init();
      final userId = auth.user?.id;
      if (userId != null) {
        await workoutProvider.loadWorkouts(userId);
      }

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      _stopTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

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
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2E7D32).withValues(alpha: 0.15),
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
                color: const Color(0xFFCC7A4A).withValues(alpha: 0.12),
              ),
            ),
          ),

          // Aurora Blob 3: Center-Left Indigo Glow
          Positioned(
            top: 280,
            left: -120,
            child: Container(
              width: 260,
              height: 260,
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

          // Interactive Content Layer
          Positioned.fill(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),

                        // Logo Container with breathing scale
                        Hero(
                          tag: 'app_logo',
                          child: Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFFEBC374).withValues(alpha: 0.35),
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEBC374).withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/app_icon.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ).animate(
                          onPlay: (controller) => controller.repeat(reverse: true),
                        ).scale(
                          begin: const Offset(1.0, 1.0),
                          end: const Offset(1.03, 1.03),
                          duration: 2400.ms,
                          curve: Curves.easeInOut,
                        ),

                        const SizedBox(height: 20),

                        // Golden Shader Text Title
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFFFFF0D0),
                              Color(0xFFEBC374),
                              Color(0xFFCC7A4A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            'Hoş Geldin',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: Colors.white,
                            ),
                          ),
                        ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.15, end: 0, duration: 500.ms),

                        const SizedBox(height: 6),

                        // Subtitle
                        Text(
                          'Fitness yolculuğuna devam et',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ).animate().fadeIn(duration: 500.ms, delay: 100.ms).slideY(begin: -0.1, end: 0, duration: 500.ms),

                        const SizedBox(height: 30),

                        // Glassmorphic Form Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 32,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Email Address Input
                                    TextFormField(
                                      controller: _emailCtrl,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: AppValidators.email,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'E-posta',
                                        labelStyle: GoogleFonts.outfit(
                                          color: Colors.white.withValues(alpha: 0.45),
                                          fontSize: 14,
                                        ),
                                        floatingLabelStyle: GoogleFonts.outfit(
                                          color: const Color(0xFFEBC374),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.mail_outline_rounded,
                                          color: Colors.white.withValues(alpha: 0.45),
                                          size: 22,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.01),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFEBC374),
                                            width: 1.5,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: AppColors.error,
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: -0.05, end: 0),

                                    const SizedBox(height: 16),

                                    // Password Input
                                    TextFormField(
                                      controller: _passwordCtrl,
                                      obscureText: _obscure,
                                      validator: AppValidators.password,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      decoration: InputDecoration(
                                        labelText: 'Şifre',
                                        labelStyle: GoogleFonts.outfit(
                                          color: Colors.white.withValues(alpha: 0.45),
                                          fontSize: 14,
                                        ),
                                        floatingLabelStyle: GoogleFonts.outfit(
                                          color: const Color(0xFFEBC374),
                                          fontWeight: FontWeight.w600,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.lock_outline_rounded,
                                          color: Colors.white.withValues(alpha: 0.45),
                                          size: 22,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.white.withValues(alpha: 0.45),
                                            size: 20,
                                          ),
                                          onPressed: () =>
                                              setState(() => _obscure = !_obscure),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.01),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFEBC374),
                                            width: 1.5,
                                          ),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: AppColors.error,
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: AppColors.error,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideX(begin: -0.05, end: 0),

                                    const SizedBox(height: 16),

                                    // Remember Me & Forgot Password
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: Theme(
                                                data: ThemeData(
                                                  unselectedWidgetColor: Colors.white.withValues(alpha: 0.4),
                                                ),
                                                child: Checkbox(
                                                  value: _remember,
                                                  onChanged: (val) =>
                                                      setState(() => _remember = val ?? false),
                                                  activeColor: const Color(0xFF4CAF50),
                                                  checkColor: Colors.white,
                                                  side: BorderSide(
                                                    color: Colors.white.withValues(alpha: 0.3),
                                                    width: 1.5,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Beni hatırla',
                                              style: GoogleFonts.outfit(
                                                color: Colors.white.withValues(alpha: 0.65),
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const ForgotPasswordScreen(),
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            'Şifremi Unuttum?',
                                            style: GoogleFonts.outfit(
                                              color: const Color(0xFFEBC374),
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ).animate().fadeIn(duration: 400.ms, delay: 400.ms),

                                    const SizedBox(height: 26),

                                    // Shimmering Login Button
                                    Opacity(
                                      opacity: auth.isLoading ? 0.65 : 1.0,
                                      child: Container(
                                        width: double.infinity,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF2E7D32),
                                              Color(0xFF4CAF50),
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                                              blurRadius: 16,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: auth.isLoading ? null : _handleLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: auth.isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    valueColor: AlwaysStoppedAnimation(
                                                      Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : Text(
                                                  'Giriş Yap',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 15.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    )
                                        .animate(onPlay: (controller) => controller.repeat())
                                        .shimmer(
                                          duration: 2600.ms,
                                          delay: 1500.ms,
                                          color: Colors.white.withValues(alpha: 0.18),
                                        )
                                        .animate()
                                        .fadeIn(duration: 400.ms, delay: 500.ms)
                                        .slideY(begin: 0.1, end: 0),

                                    if (_loadingMsg != null) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        _loadingMsg!,
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          color: Colors.white.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 20),

                                    // Divider "veya"
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Divider(color: Colors.white.withValues(alpha: 0.08)),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          child: Text(
                                            'veya',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white.withValues(alpha: 0.45),
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Divider(color: Colors.white.withValues(alpha: 0.08)),
                                        ),
                                      ],
                                    ).animate().fadeIn(duration: 400.ms, delay: 600.ms),

                                    const SizedBox(height: 20),

                                    // Social Sign-Ins in a side-by-side Row
                                    Row(
                                      children: [
                                        // Google Button
                                        Expanded(
                                          child: SizedBox(
                                            height: 50,
                                            child: OutlinedButton(
                                              onPressed: auth.isLoading ? null : _handleGoogle,
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.white,
                                                backgroundColor: Colors.white.withValues(alpha: 0.02),
                                                side: BorderSide(
                                                  color: Colors.white.withValues(alpha: 0.08),
                                                  width: 1.2,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                padding: EdgeInsets.zero,
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Image.asset(
                                                    'assets/images/google_logo.png',
                                                    width: 18,
                                                    height: 18,
                                                    errorBuilder: (_, __, ___) =>
                                                        const Icon(Icons.g_mobiledata, size: 22),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Google',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),

                                        if (Platform.isIOS) ...[
                                          const SizedBox(width: 12),
                                          // Apple Button
                                          Expanded(
                                            child: SizedBox(
                                              height: 50,
                                              child: OutlinedButton(
                                                onPressed: auth.isLoading ? null : _handleApple,
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.white,
                                                  backgroundColor: Colors.white.withValues(alpha: 0.02),
                                                  side: BorderSide(
                                                    color: Colors.white.withValues(alpha: 0.08),
                                                    width: 1.2,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  padding: EdgeInsets.zero,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(Icons.apple, size: 19, color: Colors.white),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Apple',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ).animate().fadeIn(duration: 400.ms, delay: 700.ms).slideY(begin: 0.1, end: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 800.ms, delay: 150.ms).slideY(begin: 0.08, end: 0, duration: 800.ms, curve: Curves.easeOutQuad),

                        const SizedBox(height: 24),

                        // Register Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Hesabın yok mu? ',
                              style: GoogleFonts.outfit(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 14.5,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Kayıt Ol',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFEBC374),
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ).animate().fadeIn(duration: 800.ms, delay: 850.ms),
                        
                        const SizedBox(height: 12),
                      ],
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
}
