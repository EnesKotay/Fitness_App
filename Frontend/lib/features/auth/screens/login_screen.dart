import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/data/datasources/hive_diet_storage.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/data/repositories/weight_repository_impl.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/validators.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'legal_screen.dart';

/// Uygulama accent rengi (main.dart, HomeScreen ile uyumlu)
const _kAccentColor = Color(0xFFCC7A4A);


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    final savedEmail = StorageHelper.getRememberedEmail();
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
      _rememberMe = true;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Hesap değişmeden önce eski suffix; login sonrası bu box'lar kapatılacak
    final oldSuffix = StorageHelper.getUserStorageSuffix();

    try {
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      final currentContext = context;
      if (!currentContext.mounted) return;

      if (success) {
        if (_rememberMe) {
          await StorageHelper.saveRememberedEmail(_emailController.text.trim());
        } else {
          await StorageHelper.clearRememberedEmail();
        }
        if (!currentContext.mounted) return;
        // Eski kullanıcının Hive box'larını kapat; yeni userId ile yeniden açılacak
        await HiveDietStorage.closeBoxesForSuffix(oldSuffix);
        await HiveWeightRepository.closeBoxesForSuffix(oldSuffix);
        debugPrint(
          'Login: switchUser -> ${StorageHelper.getUserStorageSuffix()} (closed $oldSuffix)',
        );
        if (!currentContext.mounted) return;
        final dietProvider = Provider.of<DietProvider>(
          currentContext,
          listen: false,
        );
        final weightProvider = Provider.of<WeightProvider>(
          currentContext,
          listen: false,
        );
        final trackingProvider = Provider.of<TrackingProvider>(
          currentContext,
          listen: false,
        );
        final workoutProvider = Provider.of<WorkoutProvider>(
          currentContext,
          listen: false,
        );

        dietProvider.reset();
        weightProvider.reset();
        trackingProvider.reset();
        workoutProvider.reset();

        await dietProvider.init();
        if (!currentContext.mounted) return;
        final shouldShowProfileSetup =
            dietProvider.error == null && dietProvider.profile == null;
        Navigator.of(currentContext).pushReplacementNamed(
          shouldShowProfileSetup ? '/profile-setup' : '/home',
        );
      } else {
        ScaffoldMessenger.of(currentContext).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Giriş başarısız'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Login hatası: $e');
      debugPrint('Stack: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bir hata oluştu: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset:
          false, // Klavye açılınca ekranı sıkıştırma (arkaplan sabit kalsın)
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Arkaplan — marka renkleriyle daha derin, ama yine de sakin
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomLeft,
                  colors: const [
                    Color(0xFF0B1220),
                    Color(0xFF090E17),
                    Color(0xFF070A11),
                    Color(0xFF120B09),
                  ],
                ),
                image: DecorationImage(
                  image: const AssetImage('assets/images/tracking_bg_light.png'),
                  fit: BoxFit.cover,
                  opacity: 0.05,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.55),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: _LoginBackgroundPainter(),
            ),
          ),
          // Sağ-üst ana mavi aura
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF2563EB).withValues(alpha: 0.22),
                    const Color(0xFF38BDF8).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Logo çevresine hafif spot ışık
          Positioned(
            top: 160,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      const Color(0xFF38BDF8).withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Sol-alt ana turuncu aura
          Positioned(
            bottom: -120,
            left: -100,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD97706).withValues(alpha: 0.2),
                    _kAccentColor.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Alt orta yumuşak sıcak parlama
          Positioned(
            bottom: 120,
            left: 40,
            right: 40,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: RadialGradient(
                  colors: [
                    _kAccentColor.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.16),
                  ],
                ),
              ),
            ),
          ),
          // Ana içerik
          SafeArea(
            bottom: false,
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom:
                          bottomPadding +
                          24 +
                          viewInsetsBottom, // Klavye boşluğunu manuel ekle
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Logo & başlık (uygulama UI ile uyumlu)
                        Column(
                          children: [
                            Image.asset(
                              'assets/images/app_icon.png',
                              width: 220,
                              height: 220,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'FitMentor',
                              style: TextStyle(
                                fontSize: 32, // 24 -> 32
                                fontWeight: FontWeight.w900, // bold -> w900
                                color: Colors.white,
                                letterSpacing: 1.2, // 0.5 -> 1.2
                              ),
                            ),
                            const SizedBox(height: 6), // 4 -> 6
                            Text(
                              'Hedeflerine ulaş, sınırları aş', // Hedeflerine ulaş -> Hedeflerine ulaş, sınırları aş
                              style: TextStyle(
                                fontSize: 16, // 14 -> 16
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48), // 28 -> 48
                        
                        // Form kartı (Glassmorphism Stili)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28, // 24 -> 28
                                vertical: 36, // 28 -> 36
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4), // 0xFF1F1F1F -> Transparent black
                                borderRadius: BorderRadius.circular(28), // 20 -> 28
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15), // 0.08 -> 0.15
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // E-posta alanı
                                    TextFormField(
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'E-posta Adresi', // E-posta -> E-posta Adresi
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 16,
                                        ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.only(left: 4, right: 8),
                                          child: Icon(
                                            Icons.email_outlined,
                                            color: Colors.white.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.05), // 0xFF2A2A2A -> Glass
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.1),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: _kAccentColor,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 20, // 16 -> 20
                                        ),
                                      ),
                                      validator: AppValidators.email,
                                    ),
                                    const SizedBox(height: 20), // 16 -> 20
                                    
                                    // Şifre alanı
                                    TextFormField(
                                      controller: _passwordController,
                                      obscureText: _obscurePassword,
                                      keyboardType: TextInputType.visiblePassword,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Şifre',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 16,
                                        ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.only(left: 4, right: 8),
                                          child: Icon(
                                            Icons.lock_outline_rounded,
                                            color: Colors.white.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.white.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(alpha: 0.05),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.1),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: _kAccentColor,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 20,
                                        ),
                                      ),
                                      validator: AppValidators.password,
                                    ),
                                    const SizedBox(height: 24), // 20 -> 24
                                    
                                      // Beni hatırla ve Şifremi Unuttum
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              SizedBox(
                                                height: 24, // 22 -> 24
                                                width: 24, // 22 -> 24
                                                child: Checkbox(
                                                  value: _rememberMe,
                                                  onChanged: (value) {
                                                    setState(() => _rememberMe = value ?? false);
                                                  },
                                                  fillColor: WidgetStateProperty.resolveWith((states) {
                                                    if (states.contains(WidgetState.selected)) {
                                                      return _kAccentColor;
                                                    }
                                                    return Colors.white.withValues(alpha: 0.1); // 0.2 -> 0.1
                                                  }),
                                                  checkColor: Colors.white,
                                                  side: BorderSide(
                                                    color: Colors.white.withValues(alpha: 0.3), // 0.4 -> 0.3
                                                    width: 1.5, // 1 -> 1.5
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(6), // 5 -> 6
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() => _rememberMe = !_rememberMe);
                                                },
                                                child: Text(
                                                  'Beni hatırla',
                                                  style: TextStyle(
                                                    fontSize: 15, // 14 -> 15
                                                    color: Colors.white.withValues(alpha: 0.9),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) => const ForgotPasswordScreen(),
                                                ),
                                              );
                                            },
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.zero,
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: const Text(
                                              'Şifremi Unuttum?',
                                              style: TextStyle(
                                                color: _kAccentColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 32), // 24 -> 32
                                    
                                    // Giriş butonu
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16), // 14 -> 16
                                        boxShadow: [
                                          BoxShadow(
                                            color: _kAccentColor.withValues(alpha: 0.5), // 0.35 -> 0.5
                                            blurRadius: 20, // 12 -> 20
                                            offset: const Offset(0, 8), // 4 -> 8
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: authProvider.isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _kAccentColor,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: _kAccentColor.withValues(alpha: 0.5),
                                          disabledForegroundColor: Colors.white70,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 20), // 16 -> 20
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: authProvider.isLoading
                                            ? const SizedBox(
                                                height: 24, // 22 -> 24
                                                width: 24, // 22 -> 24
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 3, // 2.5 -> 3
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Giriş Yap',
                                                style: TextStyle(
                                                  fontSize: 18, // 16 -> 18
                                                  fontWeight: FontWeight.bold, // w600 -> bold
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Kayıt Ol linki
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              text: 'Hesabınız yok mu? ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Kayıt Ol',
                                  style: TextStyle(
                                    color: _kAccentColor,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                    decorationColor: _kAccentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Legal linkler
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const LegalScreen(initialTab: LegalTab.privacy),
                              )),
                              child: Text(
                                'Gizlilik Politikası',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white38,
                                ),
                              ),
                            ),
                            Text('  ·  ', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 12)),
                            GestureDetector(
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => const LegalScreen(initialTab: LegalTab.terms),
                              )),
                              child: Text(
                                'Kullanım Koşulları',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white38,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bluePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.48, size.height * 0.1),
        Offset(size.width * 0.9, size.height * 0.42),
        [
          const Color(0xFF38BDF8).withValues(alpha: 0.12),
          Colors.transparent,
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final orangePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width * 0.05, size.height * 0.72),
        Offset(size.width * 0.52, size.height),
        [
          _kAccentColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final bluePath = Path()
      ..moveTo(size.width * 0.58, 0)
      ..quadraticBezierTo(
        size.width * 0.82,
        size.height * 0.2,
        size.width * 0.7,
        size.height * 0.43,
      )
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.55,
        size.width * 0.74,
        size.height * 0.72,
      );
    canvas.drawPath(bluePath, bluePaint);

    final orangePath = Path()
      ..moveTo(0, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.16,
        size.height * 0.78,
        size.width * 0.26,
        size.height * 0.92,
      )
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height,
        size.width * 0.56,
        size.height * 0.96,
      );
    canvas.drawPath(orangePath, orangePaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;

    const spacing = 32.0;
    for (double y = size.height * 0.58; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
