import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/data/datasources/hive_diet_storage.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../weight/data/repositories/weight_repository_impl.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/validators.dart';
import 'legal_screen.dart';

const _kAccentColor = Color(0xFFCC7A4A);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _tosAccepted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_tosAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devam etmek için Kullanım Koşullarını kabul etmelisiniz.')),
      );
      return;
    }
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final oldSuffix = StorageHelper.getUserStorageSuffix();

      final success = await authProvider.register(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );

      if (!mounted) return;

      if (success) {
        await HiveDietStorage.closeBoxesForSuffix(oldSuffix);
        await HiveWeightRepository.closeBoxesForSuffix(oldSuffix);

        // Yeni kayıt olan kullanıcının suffix'i (email'e göre)
        final newSuffix = StorageHelper.getUserStorageSuffix();

        // Eğer geliştirici/kullanıcı aynı email ile hesabını silip tekrar açtıysa,
        // lokalde kalan eski Hive çöp verilerini temizleyelim.
        await HiveDietStorage.clearBoxesForSuffix(newSuffix);
        await HiveWeightRepository.clearBoxesForSuffix(newSuffix);

        if (!mounted) return;
        final dietProvider = Provider.of<DietProvider>(context, listen: false);
        final weightProvider = Provider.of<WeightProvider>(
          context,
          listen: false,
        );
        final trackingProvider = Provider.of<TrackingProvider>(
          context,
          listen: false,
        );
        final workoutProvider = Provider.of<WorkoutProvider>(
          context,
          listen: false,
        );

        dietProvider.reset();
        weightProvider.reset();
        trackingProvider.reset();
        workoutProvider.reset();

        await dietProvider.init();

        if (!mounted) return;
        final shouldShowProfileSetup =
            dietProvider.error == null && dietProvider.profile == null;

        final nextRoute = shouldShowProfileSetup ? '/profile-setup' : '/home';

        Navigator.of(context).pushReplacementNamed(nextRoute);
      } else {
        // Hata mesajını göster
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Kayıt başarısız'),
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
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
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
              painter: _RegisterBackgroundPainter(),
            ),
          ),
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
                      bottom: bottomPadding + 24 + viewInsetsBottom,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Logo & başlık
                        Column(
                          children: [
                            Image.asset(
                              'assets/images/app_icon.png',
                              width: 220,
                              height: 220,
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'FitMentor',
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Aramıza katıl, hedeflerini kur ve başla',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        
                        // Form kartı (Glassmorphism Stili)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 36,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
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
                                    // Ad Soyad alanı
                                    TextFormField(
                                      controller: _nameController,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Ad Soyad',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 16,
                                        ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.only(left: 4, right: 8),
                                          child: Icon(
                                            Icons.person_outline_rounded,
                                            color: Colors.white.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
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
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Ad soyad gerekli';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 20),
                                    
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
                                        hintText: 'E-posta Adresi',
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
                                      validator: AppValidators.email,
                                    ),
                                    const SizedBox(height: 20),
                                    
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
                                    const SizedBox(height: 20),
                                    
                                    // Şifre tekrar alanı
                                    TextFormField(
                                      controller: _confirmPasswordController,
                                      obscureText: _obscureConfirmPassword,
                                      keyboardType: TextInputType.visiblePassword,
                                      autocorrect: false,
                                      enableSuggestions: false,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Şifre Tekrar',
                                        hintStyle: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          fontSize: 16,
                                        ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.only(left: 4, right: 8),
                                          child: Icon(
                                            Icons.lock_reset_outlined,
                                            color: Colors.white.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_outlined
                                                : Icons.visibility_off_outlined,
                                            color: Colors.white.withValues(alpha: 0.6),
                                            size: 24,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword = !_obscureConfirmPassword;
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
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Şifre tekrarı gerekli';
                                        }
                                        if (value != _passwordController.text) {
                                          return 'Şifreler eşleşmiyor';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),

                                    // ToS onay checkbox
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _tosAccepted,
                                            onChanged: (v) => setState(() => _tosAccepted = v ?? false),
                                            fillColor: WidgetStateProperty.resolveWith((s) =>
                                              s.contains(WidgetState.selected) ? _kAccentColor : Colors.white.withValues(alpha: 0.1)),
                                            checkColor: Colors.white,
                                            side: BorderSide(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setState(() => _tosAccepted = !_tosAccepted),
                                            child: RichText(
                                              text: TextSpan(
                                                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.45),
                                                children: [
                                                  const TextSpan(text: 'Devam ederek '),
                                                  WidgetSpan(
                                                    child: GestureDetector(
                                                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                                        builder: (_) => const LegalScreen(initialTab: LegalTab.terms),
                                                      )),
                                                      child: const Text('Kullanım Koşulları',
                                                        style: TextStyle(color: _kAccentColor, fontSize: 13,
                                                          decoration: TextDecoration.underline, decorationColor: _kAccentColor)),
                                                    ),
                                                  ),
                                                  const TextSpan(text: ' ve '),
                                                  WidgetSpan(
                                                    child: GestureDetector(
                                                      onTap: () => Navigator.of(context).push(MaterialPageRoute(
                                                        builder: (_) => const LegalScreen(initialTab: LegalTab.privacy),
                                                      )),
                                                      child: const Text('Gizlilik Politikası',
                                                        style: TextStyle(color: _kAccentColor, fontSize: 13,
                                                          decoration: TextDecoration.underline, decorationColor: _kAccentColor)),
                                                    ),
                                                  ),
                                                  const TextSpan(text: ' metinlerini kabul etmiş olursun.'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 32),

                                    // Kayıt Ol butonu
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _kAccentColor.withValues(alpha: 0.5),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: (authProvider.isLoading || !_tosAccepted) ? null : _handleRegister,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _kAccentColor,
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: _kAccentColor.withValues(alpha: 0.5),
                                          disabledForegroundColor: Colors.white70,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 20),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                        ),
                                        child: authProvider.isLoading
                                            ? const SizedBox(
                                                height: 24,
                                                width: 24,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 3,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              )
                                            : const Text(
                                                'Kayıt Ol',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
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
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                          },
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              text: 'Hesabınız var mı? ',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Giriş Yap',
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

class _RegisterBackgroundPainter extends CustomPainter {
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
