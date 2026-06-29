import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/services/page_guide_service.dart';
import '../../../core/utils/storage_helper.dart';
import '../../../core/utils/validators.dart';
import '../../nutrition/data/datasources/hive_diet_storage.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../tracking/providers/tracking_provider.dart';
import '../../weight/data/repositories/weight_repository_impl.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../workout/data/hive_workout_repository.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/auth_provider.dart';
import 'legal_screen.dart';
import 'widgets/auth_scaffold.dart';

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
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _tosAccepted = false;
  bool _healthDataAccepted = false;
  bool _aiTransferAccepted = false;
  bool _paymentTransferAccepted = false;

  bool get _allRequiredConsentsAccepted =>
      _tosAccepted &&
      _healthDataAccepted &&
      _aiTransferAccepted &&
      _paymentTransferAccepted;

  int get _acceptedConsentCount => [
    _tosAccepted,
    _healthDataAccepted,
    _aiTransferAccepted,
    _paymentTransferAccepted,
  ].where((value) => value).length;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _focusNext(FocusNode focusNode) {
    FocusScope.of(context).requestFocus(focusNode);
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  Future<void> _handleRegister() async {
    _dismissKeyboard();

    if (!_tosAccepted) {
      _showSnack(
        'Devam etmek için kullanım koşulları ve gizlilik onayı gerekli.',
      );
      return;
    }
    if (!_healthDataAccepted) {
      _showSnack('Sağlık verisi işleme onayını vermelisiniz.');
      return;
    }
    if (!_aiTransferAccepted) {
      _showSnack('AI koç için veri aktarım onayını vermelisiniz.');
      return;
    }
    if (!_paymentTransferAccepted) {
      _showSnack('Abonelik doğrulama aktarım onayını vermelisiniz.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final oldSuffix = StorageHelper.getUserStorageSuffix();

    final success = await authProvider.register(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    );

    if (!mounted) return;

    if (!success) {
      _showSnack(
        authProvider.errorMessage ?? 'Kayıt başarısız',
        backgroundColor: Colors.red,
      );
      return;
    }

    await HiveDietStorage.closeBoxesForSuffix(oldSuffix);
    await HiveWeightRepository.closeBoxesForSuffix(oldSuffix);
    await HiveWorkoutRepository.closeBoxesForSuffix(oldSuffix);

    final newSuffix = StorageHelper.getUserStorageSuffix();
    await HiveDietStorage.clearBoxesForSuffix(newSuffix);
    await HiveWeightRepository.clearBoxesForSuffix(newSuffix);
    await HiveWorkoutRepository.clearBoxesForSuffix(newSuffix);

    if (!mounted) return;
    final dietProvider = Provider.of<DietProvider>(context, listen: false);
    final weightProvider = Provider.of<WeightProvider>(context, listen: false);
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
    await StorageHelper.savePrivacyHealthConsent(true);
    await StorageHelper.savePrivacyTransferConsent(true);
    await StorageHelper.savePrivacyPaymentTransferConsent(true);
    await StorageHelper.savePendingAppTour(true);
    await StorageHelper.saveAppTourSeen(false);
    await PageGuideService.resetAllGuides();

    if (!mounted) return;
    final shouldShowProfileSetup =
        dietProvider.error == null && dietProvider.profile == null;
    if (!mounted) return;
    final nextRoute = shouldShowProfileSetup ? '/profile-setup' : '/home';
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return AuthScaffold(
          title: 'PusulaFit',
          subtitle: 'Aramıza katıl, hedeflerini kur ve başla',
          formContent: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _FormSectionTitle(
                  title: 'Hesap Bilgileri',
                  subtitle: 'Önce temel bilgilerini oluşturalım.',
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: -0.1, end: 0),
                const SizedBox(height: 18),
                
                // Full Name Input
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNext(_emailFocusNode),
                  onTapOutside: (_) => _dismissKeyboard(),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'Ad Soyad',
                    icon: Icons.person_outline_rounded,
                  ),
                  validator: (value) => AppValidators.required(
                    value,
                    message: 'Ad soyad gerekli',
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 150.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 16),
                
                // Email Address Input
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNext(_passwordFocusNode),
                  onTapOutside: (_) => _dismissKeyboard(),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'E-posta Adresi',
                    icon: Icons.email_outlined,
                  ),
                  validator: AppValidators.email,
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 16),
                
                // Password Input
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      _focusNext(_confirmPasswordFocusNode),
                  onTapOutside: (_) => _dismissKeyboard(),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'Şifre',
                    icon: Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white.withValues(alpha: 0.45),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: AppValidators.password,
                ).animate().fadeIn(duration: 400.ms, delay: 250.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 16),
                
                // Confirm Password Input
                TextFormField(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocusNode,
                  obscureText: _obscureConfirmPassword,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _handleRegister(),
                  onTapOutside: (_) => _dismissKeyboard(),
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'Şifre Tekrar',
                    icon: Icons.lock_reset_outlined,
                    suffix: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: Colors.white.withValues(alpha: 0.45),
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) => AppValidators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 300.ms).slideX(begin: -0.05, end: 0),
                const SizedBox(height: 14),
                
                // Password Alert Info Block
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.01),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _kAccentColor.withValues(alpha: 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _kAccentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.shield_outlined,
                          color: Color(0xFFEBC374),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Şifren en az 8 karakter olmalı. Bilgilerini tamamladıktan sonra gerekli onayları vererek hesabını oluşturabilirsin.',
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 350.ms).slideY(begin: 0.1, end: 0),
                
                const SizedBox(height: 24),
                
                // Consents Section Header
                _FormSectionTitle(
                  title: 'Gerekli Onaylar',
                  subtitle:
                      'Devam etmek için 4 zorunlu onayın tamamı gerekiyor. '
                      'Tamamlanan: $_acceptedConsentCount/4',
                ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                const SizedBox(height: 12),
                
                // Glassmorphic Consents Card Wrapper
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.015),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    children: [
                      _ConsentRow(
                        value: _tosAccepted,
                        onChanged: (v) =>
                            setState(() => _tosAccepted = v ?? false),
                        title: 'Kullanım koşulları ve gizlilik',
                        description:
                            'Hesap açarken temel kullanım ve gizlilik metinlerini kabul edersin.',
                        kvkkTab: LegalTab.terms,
                        linkText: 'Koşulları aç',
                        secondaryTab: LegalTab.privacy,
                        secondaryLinkText: 'Gizliliği aç',
                      ),
                      const _ConsentDivider(),
                      _ConsentRow(
                        value: _healthDataAccepted,
                        onChanged: (v) =>
                            setState(() => _healthDataAccepted = v ?? false),
                        title: 'Sağlık verisi işleme izni',
                        description:
                            'Boy, kilo, beslenme ve egzersiz verilerin kişiselleştirilmiş takip için işlenir.',
                        kvkkTab: LegalTab.kvkk,
                        linkText: 'KVKK metnini aç',
                      ),
                      const _ConsentDivider(),
                      _ConsentRow(
                        value: _aiTransferAccepted,
                        onChanged: (v) =>
                            setState(() => _aiTransferAccepted = v ?? false),
                        title: 'AI koç için veri aktarımı',
                        description:
                            'AI koç deneyimi için gerekli sağlık ve beslenme verileri iş ortağı servislere aktarılabilir.',
                        kvkkTab: LegalTab.kvkk,
                        linkText: 'Aktarım detayını aç',
                      ),
                      const _ConsentDivider(),
                      _ConsentRow(
                        value: _paymentTransferAccepted,
                        onChanged: (v) => setState(
                          () => _paymentTransferAccepted = v ?? false,
                        ),
                        title: 'Abonelik doğrulama aktarımı',
                        description:
                            'Premium abonelik doğrulaması için Apple veya Google tarafına gerekli bilgiler iletilir.',
                        kvkkTab: LegalTab.kvkk,
                        linkText: 'Ödeme detayını aç',
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 450.ms).slideY(begin: 0.05, end: 0),
                
                const SizedBox(height: 28),
                
                // Shimmering Golden Gradient Button
                Opacity(
                  opacity: (authProvider.isLoading || !_allRequiredConsentsAccepted)
                      ? 0.55
                      : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFCC7A4A),
                          Color(0xFFEBC374),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kAccentColor.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed:
                          (authProvider.isLoading || !_allRequiredConsentsAccepted)
                          ? null
                          : _handleRegister,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.white70,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: authProvider.isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Hesabı Oluştur',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ).animate(
                  onPlay: (controller) => controller.repeat(),
                ).shimmer(
                  duration: 2600.ms,
                  delay: 1800.ms,
                  color: Colors.white.withValues(alpha: 0.18),
                ).animate().fadeIn(duration: 400.ms, delay: 500.ms).slideY(begin: 0.1, end: 0),
              ],
            ),
          ),
          bottomContent: Column(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: 'Hesabınız var mı? ',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    children: [
                      TextSpan(
                        text: 'Giriş Yap',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFEBC374),
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFFEBC374),
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const LegalScreen(initialTab: LegalTab.privacy),
                      ),
                    ),
                    child: Text(
                      'Gizlilik Politikası',
                      style: GoogleFonts.outfit(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white38,
                      ),
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: GoogleFonts.outfit(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
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
                      style: GoogleFonts.outfit(
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
          ).animate().fadeIn(duration: 800.ms, delay: 600.ms),
        );
      },
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: hintText,
      labelStyle: GoogleFonts.outfit(
        color: Colors.white.withValues(alpha: 0.45),
        fontSize: 14,
      ),
      floatingLabelStyle: GoogleFonts.outfit(
        color: const Color(0xFFEBC374),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 4, right: 8),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.45), size: 22),
      ),
      suffixIcon: suffix,
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
        borderSide: const BorderSide(
          color: Color(0xFFD32F2F),
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFD32F2F),
          width: 1.5,
        ),
      ),
    );
  }
}

class _FormSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _FormSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ConsentRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String title;
  final String description;
  final LegalTab kvkkTab;
  final String linkText;
  final LegalTab? secondaryTab;
  final String? secondaryLinkText;

  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.description,
    required this.kvkkTab,
    required this.linkText,
    this.secondaryTab,
    this.secondaryLinkText,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Theme(
            data: ThemeData(
              unselectedWidgetColor: Colors.white.withValues(alpha: 0.4),
            ),
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFCC7A4A),
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
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _ConsentLink(
                      label: linkText,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LegalScreen(initialTab: kvkkTab),
                        ),
                      ),
                    ),
                    if (secondaryTab != null && secondaryLinkText != null)
                      _ConsentLink(
                        label: secondaryLinkText!,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LegalScreen(initialTab: secondaryTab!),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConsentDivider extends StatelessWidget {
  const _ConsentDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
    );
  }
}

class _ConsentLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ConsentLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: GoogleFonts.outfit(
          color: const Color(0xFFEBC374),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: const Color(0xFFEBC374),
        ),
      ),
    );
  }
}
