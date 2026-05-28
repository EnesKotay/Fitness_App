import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/data/datasources/hive_diet_storage.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/data/repositories/weight_repository_impl.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../workout/data/hive_workout_repository.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/validators.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'legal_screen.dart';
import 'widgets/auth_scaffold.dart';

const _kAccent = Color(0xFFCC7A4A);
const _kAccentLight = Color(0xFFE8955A);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscure = true;
  bool _remember = false;
  bool _emailFocused = false;
  bool _passwordFocused = false;
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
    _emailFocus.addListener(
      () => setState(() => _emailFocused = _emailFocus.hasFocus),
    );
    _passwordFocus.addListener(
      () => setState(() => _passwordFocused = _passwordFocus.hasFocus),
    );
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _startTimer() {
    _loadingTimer?.cancel();
    _loadingTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _loadingMsg = 'Sunucu başlatılıyor, lütfen bekleyin...');
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
        (p) => p.login(_emailCtrl.text.trim(), _passwordCtrl.text),
        saveEmail: true,
      );
    } finally {
      _stopTimer();
    }
  }

  Future<void> _handleGoogle() async {
    _startTimer();
    try {
      await _runAuthFlow((p) => p.loginWithGoogle());
    } finally {
      _stopTimer();
    }
  }

  Future<void> _handleApple() async {
    _startTimer();
    try {
      await _runAuthFlow((p) => p.loginWithApple());
    } catch (e) {
      debugPrint('Apple login hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bir hata oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _stopTimer();
    }
  }

  Future<void> _runAuthFlow(
    Future<bool> Function(AuthProvider) action, {
    bool saveEmail = false,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final oldSuffix = StorageHelper.getUserStorageSuffix();
    final success = await action(auth);
    final ctx = context;
    if (!ctx.mounted) return;

    if (success) {
      if (saveEmail) {
        if (_remember) {
          await StorageHelper.saveRememberedEmail(_emailCtrl.text.trim());
        } else {
          await StorageHelper.clearRememberedEmail();
        }
      }
      if (!ctx.mounted) return;
      await _onSuccess(ctx, oldSuffix);
      return;
    }

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(auth.errorMessage ?? 'Giriş başarısız'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _onSuccess(BuildContext ctx, String oldSuffix) async {
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

    // Social login (Google/Apple) ile ilk kez giren kullanıcının profili yoktur.
    // Bu durumda profil kurulum ekranına yönlendir.
    final shouldShowProfileSetup = diet.error == null && diet.profile == null;
    await StorageHelper.savePendingInitialProfileSetup(shouldShowProfileSetup);
    if (!ctx.mounted) return;
    final nextRoute = shouldShowProfileSetup ? '/profile-setup' : '/home';
    Navigator.of(ctx).pushReplacementNamed(nextRoute);
  }

  bool get _showApple => Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => AuthScaffold(
        title: 'PusulaFit',
        subtitle: 'Hedeflerine ulaş, sınırları aş',
        formContent: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _LoginCardHeader(),
              const SizedBox(height: 20),

              // ── E-posta ─────────────────────────────────────
              _FloatingField(
                controller: _emailCtrl,
                focusNode: _emailFocus,
                focused: _emailFocused,
                hint: 'E-posta Adresi',
                icon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: AppValidators.email,
              ),
              const SizedBox(height: 14),

              // ── Şifre ───────────────────────────────────────
              _FloatingField(
                controller: _passwordCtrl,
                focusNode: _passwordFocus,
                focused: _passwordFocused,
                hint: 'Şifre',
                icon: Icons.lock_outline_rounded,
                obscureText: _obscure,
                validator: AppValidators.password,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 18),
                    child: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                      color: _passwordFocused
                          ? _kAccentLight
                          : Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Beni hatırla + Şifremi Unuttum ──────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _remember = !_remember),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: _remember ? _kAccent : Colors.transparent,
                            border: Border.all(
                              color: _remember
                                  ? _kAccent
                                  : Colors.white.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: _remember
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 12,
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Beni hatırla',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.65),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: const Text(
                      'Şifremi Unuttum?',
                      style: TextStyle(
                        color: _kAccentLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // ── Giriş Yap ───────────────────────────────────
              _PremiumButton(
                isLoading: auth.isLoading,
                onPressed: _handleLogin,
              ),

              if (_loadingMsg != null) ...[
                const SizedBox(height: 12),
                Text(
                  _loadingMsg!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // ── Divider ─────────────────────────────────────
              const _DividerLabel(label: 'veya'),
              const SizedBox(height: 18),

              // ── Sosyal butonlar ──────────────────────────────
              _SocialButton(
                label: 'Google ile devam et',
                icon: const _GoogleIcon(),
                onPressed: auth.isLoading ? null : _handleGoogle,
                borderColor: const Color(0xFF4285F4).withValues(alpha: 0.30),
              ),
              if (_showApple) ...[
                const SizedBox(height: 10),
                _SocialButton(
                  label: 'Apple ile devam et',
                  icon: const Icon(Icons.apple, color: Colors.white, size: 20),
                  onPressed: auth.isLoading ? null : _handleApple,
                ),
              ],
            ],
          ),
        ),
        bottomContent: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: Ink(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E0F13).withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: RichText(
                    text: TextSpan(
                      text: 'Hesabınız yok mu?  ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Kayıt Ol',
                          style: TextStyle(
                            color: _kAccentLight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const LegalScreen(initialTab: LegalTab.privacy),
                    ),
                  ),
                  child: Text(
                    'Gizlilik Politikası',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 11.5,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                Text(
                  '  ·  ',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.2),
                    fontSize: 11.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          const LegalScreen(initialTab: LegalTab.terms),
                    ),
                  ),
                  child: Text(
                    'Kullanım Koşulları',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 11.5,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginCardHeader extends StatelessWidget {
  const _LoginCardHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _kAccentLight.withValues(alpha: 0.22),
                _kAccent.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kAccentLight.withValues(alpha: 0.18)),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: _kAccentLight,
            size: 22,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hesabına giriş yap',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Planların ve ilerlemen seninle.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.045),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: Colors.white.withValues(alpha: 0.58),
                size: 13,
              ),
              const SizedBox(width: 5),
              Text(
                'Güvenli',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DividerLabel extends StatelessWidget {
  const _DividerLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _DividerLine(reverse: true)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.36),
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: _DividerLine()),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine({this.reverse = false});

  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final colors = [Colors.transparent, Colors.white.withValues(alpha: 0.12)];
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: reverse ? colors.reversed.toList() : colors,
        ),
      ),
    );
  }
}

// ─── Floating input alanı ──────────────────────────────────────────────────
class _FloatingField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const _FloatingField({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: focused ? const Color(0xFF202127) : const Color(0xFF18191F),
        border: Border.all(
          color: focused
              ? _kAccentLight.withValues(alpha: 0.72)
              : Colors.white.withValues(alpha: 0.08),
          width: focused ? 1.4 : 1.0,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: _kAccent.withValues(alpha: 0.18),
                  blurRadius: 16,
                  spreadRadius: -8,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: !obscureText,
        style: const TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.34),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 10),
            child: Icon(
              icon,
              size: 19,
              color: focused
                  ? _kAccentLight
                  : Colors.white.withValues(alpha: 0.35),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 17,
          ),
          errorStyle: const TextStyle(fontSize: 11.5),
        ),
        validator: validator,
      ),
    );
  }
}

// ─── Premium gradient buton ────────────────────────────────────────────────
class _PremiumButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _PremiumButton({required this.isLoading, required this.onPressed});

  @override
  State<_PremiumButton> createState() => _PremiumButtonState();
}

class _PremiumButtonState extends State<_PremiumButton>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    // Shimmer: 700ms animasyon, 3s duraksama (1:~4.3 ratio)
    _shimmerCtrl = AnimationController(
      duration: const Duration(milliseconds: 3700),
      vsync: this,
    )..repeat();

    _pressCtrl = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isLoading) _pressCtrl.forward();
      },
      onTapUp: (_) {
        _pressCtrl.reverse();
        if (!widget.isLoading) widget.onPressed();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: widget.isLoading
                ? LinearGradient(
                    colors: [
                      _kAccentLight.withValues(alpha: 0.4),
                      _kAccent.withValues(alpha: 0.4),
                    ],
                  )
                : const LinearGradient(
                    colors: [
                      Color(0xFFED9B61),
                      Color(0xFFCC7A4A),
                      Color(0xFFAA5E2E),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.0, 0.5, 1.0],
                  ),
            boxShadow: widget.isLoading
                ? []
                : [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: _kAccentLight.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Shimmer katmanı
                if (!widget.isLoading)
                  AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (_, _) {
                      // İlk %19 içinde (700ms / 3700ms) geç, geri kalanı bekle
                      final t = _shimmerCtrl.value;
                      final x = t < 0.19 ? -1.0 + (t / 0.19) * 3.0 : 99.0;
                      return Positioned.fill(
                        child: CustomPaint(
                          painter: _ShimmerPainter(position: x),
                        ),
                      );
                    },
                  ),
                // İçerik
                widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Giriş Yap',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.5,
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

class _ShimmerPainter extends CustomPainter {
  final double position;
  const _ShimmerPainter({required this.position});

  @override
  void paint(Canvas canvas, Size size) {
    if (position < -0.8 || position > 1.8) return;
    final x = size.width * (position * 0.5 + 0.5);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(x - 60, 0, 120, size.height));
    canvas.drawRect(Rect.fromLTWH(x - 60, 0, 120, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.position != position;
}

// ─── Sosyal buton ─────────────────────────────────────────────────────────
class _SocialButton extends StatefulWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final Color? borderColor;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.borderColor,
  });

  @override
  State<_SocialButton> createState() => _SocialButtonState();
}

class _SocialButtonState extends State<_SocialButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      duration: const Duration(milliseconds: 90),
      vsync: this,
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderCol =
        widget.borderColor ?? Colors.white.withValues(alpha: 0.11);
    return GestureDetector(
      onTapDown: (_) {
        if (widget.onPressed != null) _pressCtrl.forward();
      },
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: const Color(0xFF111217),
            border: Border.all(color: borderCol, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 14,
                spreadRadius: -10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.icon,
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.88),
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Google ikonu (brand renklerle) ───────────────────────────────────────
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(22, 22), painter: _GoogleLogoPainter());
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Beyaz daire zemin
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = Colors.white);

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72);

    void drawArc(double start, double sweep, Color color) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      // Merkez beyaz daire — G şekli için
      canvas.drawCircle(
        Offset(cx, cy),
        r * 0.44,
        Paint()..color = Colors.white,
      );
    }

    const pi = math.pi;
    // Kırmızı (üst sağ)
    drawArc(-pi / 6, pi * 2 / 3, const Color(0xFFEA4335));
    // Sarı (alt)
    drawArc(pi / 2, pi * 2 / 3, const Color(0xFFFBBC05));
    // Yeşil (sol)
    drawArc(pi * 7 / 6, pi * 2 / 3, const Color(0xFF34A853));
    // Mavi (üst sol + sağ gövde)
    drawArc(-pi * 5 / 6, pi * 2 / 3, const Color(0xFF4285F4));

    // Mavi sağ çıkıntı (Google G)
    final gPath = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx + r * 0.72, cy)
      ..lineTo(cx + r * 0.72, cy - r * 0.28)
      ..lineTo(cx + r * 0.28, cy - r * 0.28)
      ..close();
    canvas.drawPath(gPath, Paint()..color = const Color(0xFF4285F4));

    // Merkez temizle
    canvas.drawCircle(Offset(cx, cy), r * 0.44, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
