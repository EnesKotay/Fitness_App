import 'package:flutter/material.dart';
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
    // Profil kurulum sayfası: yeni kullanıcıda backend henüz profil oluşturmadı.
    // Eğer dietProvider.init() başarılı ama profil null ise ilk kurulum göster.
    // Hata varsa veya profil zaten varsa (Google/Apple ile kayıt gibi) direkt home.
    final shouldShowProfileSetup =
        dietProvider.error == null && dietProvider.profile == null;
    if (!mounted) return;
    final nextRoute = shouldShowProfileSetup ? '/profile-setup' : '/home';
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }

  void _showSnack(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
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
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNext(_emailFocusNode),
                  onTapOutside: (_) => _dismissKeyboard(),
                  style: const TextStyle(
                    fontSize: 16,
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
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) => _focusNext(_passwordFocusNode),
                  onTapOutside: (_) => _dismissKeyboard(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  decoration: _buildInputDecoration(
                    hintText: 'E-posta Adresi',
                    icon: Icons.email_outlined,
                  ),
                  validator: AppValidators.email,
                ),
                const SizedBox(height: 20),
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
                  style: const TextStyle(
                    fontSize: 16,
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
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 24,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: AppValidators.password,
                ),
                const SizedBox(height: 20),
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
                  style: const TextStyle(
                    fontSize: 16,
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
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 24,
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
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _kAccentColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.shield_outlined,
                          color: _kAccentColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Şifren en az 8 karakter olmalı. Bilgilerini tamamladıktan sonra gerekli onayları vererek hesabını oluşturabilirsin.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _FormSectionTitle(
                  title: 'Gerekli Onaylar',
                  subtitle:
                      'Devam etmek için 4 zorunlu onayın tamamı gerekiyor. '
                      'Tamamlanan: $_acceptedConsentCount/4',
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.035),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
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
                ),
                const SizedBox(height: 32),
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
                    onPressed:
                        (authProvider.isLoading ||
                            !_allRequiredConsentsAccepted)
                        ? null
                        : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccentColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _kAccentColor.withValues(
                        alpha: 0.5,
                      ),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Hesabı Oluştur',
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const LegalScreen(initialTab: LegalTab.privacy),
                      ),
                    ),
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
                  Text(
                    '  ·  ',
                    style: TextStyle(
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
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 16,
      ),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 4, right: 8),
        child: Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 24),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _kAccentColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
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
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? _kAccentColor
                  : Colors.white.withValues(alpha: 0.1),
            ),
            checkColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
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
        style: const TextStyle(
          color: _kAccentColor,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
          decorationColor: _kAccentColor,
        ),
      ),
    );
  }
}
