import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/storage_helper.dart';
import '../../../core/utils/validators.dart';
import '../../nutrition/data/datasources/hive_diet_storage.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/data/repositories/weight_repository_impl.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../workout/data/hive_workout_repository.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

/// Modern, açık ve ilgi çekici login ekranı
class ModernLoginScreen extends StatefulWidget {
  const ModernLoginScreen({super.key});

  @override
  State<ModernLoginScreen> createState() => _ModernLoginScreenState();
}

class _ModernLoginScreenState extends State<ModernLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  late AnimationController _animController;
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

    _animController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _animController.dispose();
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
    _loadingTimer = null;
    if (mounted) setState(() => _loadingMsg = null);
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _startTimer();
    try {
      await _runAuthFlow(
        (auth) => auth.login(_emailCtrl.text.trim(), _passwordCtrl.text),
        saveEmail: true,
      );
    } finally {
      _stopTimer();
    }
  }

  Future<void> _handleGoogle() async {
    _startTimer();
    try {
      await _runAuthFlow((auth) => auth.loginWithGoogle());
    } finally {
      _stopTimer();
    }
  }

  Future<void> _handleApple() async {
    _startTimer();
    try {
      await _runAuthFlow((auth) => auth.loginWithApple());
    } finally {
      _stopTimer();
    }
  }

  Future<void> _runAuthFlow(
    Future<bool> Function(AuthProvider auth) action, {
    bool saveEmail = false,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final oldSuffix = StorageHelper.getUserStorageSuffix();
    final success = await action(auth);
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Giriş başarısız'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (saveEmail) {
      if (_remember) {
        await StorageHelper.saveRememberedEmail(_emailCtrl.text.trim());
      } else {
        await StorageHelper.clearRememberedEmail();
      }
    }

    if (!mounted) return;
    await _onAuthSuccess(context, oldSuffix);
  }

  Future<void> _onAuthSuccess(BuildContext ctx, String oldSuffix) async {
    await HiveDietStorage.closeBoxesForSuffix(oldSuffix);
    await HiveWeightRepository.closeBoxesForSuffix(oldSuffix);
    await HiveWorkoutRepository.closeBoxesForSuffix(oldSuffix);
    if (!ctx.mounted) return;

    final diet = Provider.of<DietProvider>(ctx, listen: false);
    final weight = Provider.of<WeightProvider>(ctx, listen: false);
    final tracking = Provider.of<TrackingProvider>(ctx, listen: false);
    final workout = Provider.of<WorkoutProvider>(ctx, listen: false);

    diet.reset();
    weight.reset();
    tracking.reset();
    workout.reset();

    await diet.init();
    await StorageHelper.ensureKvkkConsentsInitialized();
    if (!ctx.mounted) return;

    final shouldShowProfileSetup = diet.error == null && diet.profile == null;
    await StorageHelper.savePendingInitialProfileSetup(shouldShowProfileSetup);
    if (!ctx.mounted) return;

    Navigator.of(
      ctx,
    ).pushReplacementNamed(shouldShowProfileSetup ? '/profile-setup' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: Stack(
        children: [
          // Modern gradient background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0A0E1A),
                  const Color(0xFF13161F),
                  AppColors.primary.withOpacity(0.05),
                  const Color(0xFF1A1E28),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),

          // Animated particles
          ...List.generate(15, (index) {
            return AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                final progress = (_animController.value + index * 0.07) % 1.0;
                return Positioned(
                  left: size.width * ((index % 5) * 0.25),
                  top: size.height * progress,
                  child: Opacity(
                    opacity: 0.1 * (1 - progress),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index % 2 == 0
                            ? AppColors.primary
                            : AppColors.secondary,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 60),

                  // Logo & Welcome
                  Column(
                    children: [
                      // Logo
                      Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryLight,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.directions_run_rounded,
                              size: 50,
                              color: Colors.white,
                            ),
                          )
                          .animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut)
                          .fadeIn(),

                      const SizedBox(height: 24),

                      // Title
                      ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryLight,
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Hoş Geldin!',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideY(begin: 0.3, end: 0),

                      const SizedBox(height: 8),

                      Text(
                            'Fitness yolculuğuna devam et',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideY(begin: 0.3, end: 0),
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Form card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          // Email field
                          _ModernTextField(
                            controller: _emailCtrl,
                            focusNode: _emailFocus,
                            hint: 'E-posta Adresi',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: AppValidators.email,
                          ),

                          const SizedBox(height: 16),

                          // Password field
                          _ModernTextField(
                            controller: _passwordCtrl,
                            focusNode: _passwordFocus,
                            hint: 'Şifre',
                            icon: Icons.lock_outline_rounded,
                            obscureText: _obscure,
                            validator: AppValidators.password,
                            suffix: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppColors.textTertiary,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Remember & Forgot
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Remember me
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _remember = !_remember),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: _remember
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        border: Border.all(
                                          color: _remember
                                              ? AppColors.primary
                                              : AppColors.textTertiary,
                                          width: 2,
                                        ),
                                      ),
                                      child: _remember
                                          ? const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 14,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Beni hatırla',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Forgot password
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                ),
                                child: Text(
                                  'Şifremi Unuttum?',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.primary
                                    .withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                                shadowColor: AppColors.primary.withOpacity(0.3),
                              ),
                              child: auth.isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : const Text(
                                      'Giriş Yap',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),

                          if (_loadingMsg != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _loadingMsg!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: AppColors.border,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: Text(
                                  'veya',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: AppColors.border,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Google Sign In
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: auth.isLoading ? null : _handleGoogle,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: Image.asset(
                                'assets/images/google_logo.png',
                                width: 20,
                                height: 20,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.g_mobiledata, size: 24),
                              ),
                              label: const Text(
                                'Google ile devam et',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          if (Platform.isIOS) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: auth.isLoading ? null : _handleApple,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                icon: const Icon(Icons.apple, size: 24),
                                label: const Text(
                                  'Apple ile devam et',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 32),

                  // Sign up link
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegisterScreen()),
                    ),
                    child: RichText(
                      text: TextSpan(
                        text: 'Hesabın yok mu? ',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Kayıt Ol',
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern text field widget
class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _ModernTextField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontSize: 15, color: AppColors.textTertiary),
        prefixIcon: Icon(icon, color: AppColors.textTertiary, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.surfaceLight.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}
