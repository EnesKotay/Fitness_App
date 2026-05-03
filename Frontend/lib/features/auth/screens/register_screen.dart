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
import '../../../core/services/page_guide_service.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Devam etmek için Kullanım Koşullarını kabul etmelisiniz.',
          ),
        ),
      );
      return;
    }
    if (!_healthDataAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Devam etmek için sağlık verisi işleme onayını vermelisiniz (KVKK Md.6).',
          ),
        ),
      );
      return;
    }
    if (!_aiTransferAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Devam etmek için Google AI aktarım onayını vermelisiniz (KVKK Md.9).',
          ),
        ),
      );
      return;
    }
    if (!_paymentTransferAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Devam etmek için ödeme aktarım onayını vermelisiniz (KVKK Md.9).',
          ),
        ),
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
        await StorageHelper.savePrivacyHealthConsent(true);
        await StorageHelper.savePrivacyTransferConsent(true);
        await StorageHelper.savePrivacyPaymentTransferConsent(true);
        await StorageHelper.savePendingAppTour(true);
        await StorageHelper.saveAppTourSeen(false);
        await PageGuideService.resetAllGuides();

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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return AuthScaffold(
          title: 'FitMentor',
          subtitle: 'Aramıza katıl, hedeflerini kur ve başla',
          formContent: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Ad Soyad alanı
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
                  validator: (value) => AppValidators.required(
                    value,
                    message: 'Ad soyad gerekli',
                  ),
                ),
                const SizedBox(height: 20),

                // E-posta alanı
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
                  validator: (value) => AppValidators.confirmPassword(
                    value,
                    _passwordController.text,
                  ),
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
                        onChanged: (v) =>
                            setState(() => _tosAccepted = v ?? false),
                        fillColor: WidgetStateProperty.resolveWith(
                          (s) => s.contains(WidgetState.selected)
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
                        onTap: () =>
                            setState(() => _tosAccepted = !_tosAccepted),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              height: 1.45,
                            ),
                            children: [
                              const TextSpan(text: 'Devam ederek '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const LegalScreen(
                                        initialTab: LegalTab.terms,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Kullanım Koşulları',
                                    style: TextStyle(
                                      color: _kAccentColor,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _kAccentColor,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' ve '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const LegalScreen(
                                        initialTab: LegalTab.privacy,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Gizlilik Politikası',
                                    style: TextStyle(
                                      color: _kAccentColor,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _kAccentColor,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(
                                text: ' metinlerini kabul etmiş olursun.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // KVKK Md.6 — Sağlık verisi açık rızası
                _ConsentRow(
                  value: _healthDataAccepted,
                  onChanged: (v) =>
                      setState(() => _healthDataAccepted = v ?? false),
                  label:
                      'Boy, kilo, beslenme ve egzersiz gibi sağlık verilerimin kişiselleştirilmiş '
                      'fitness takibi için işlenmesine açık rıza veriyorum (KVKK Md.6). '
                      'Bu rızamı istediğim zaman Ayarlar → Gizlilik\'ten geri alabilirim.',
                  kvkkTab: LegalTab.kvkk,
                  linkText: 'Aydınlatma Metni',
                ),
                const SizedBox(height: 10),

                // KVKK Md.9 — Google AI aktarım açık rızası
                _ConsentRow(
                  value: _aiTransferAccepted,
                  onChanged: (v) =>
                      setState(() => _aiTransferAccepted = v ?? false),
                  label:
                      'Sağlık ve beslenme verilerimin AI koç hizmeti için Google LLC (ABD)\'ye '
                      'aktarılmasına açık rıza veriyorum (KVKK Md.9). Rızamı geri alırsam AI koç '
                      'özelliği devre dışı kalır.',
                  kvkkTab: LegalTab.kvkk,
                  linkText: 'Aktarım Detayı',
                ),
                const SizedBox(height: 10),

                // KVKK Md.9 — Apple/Google ödeme aktarım açık rızası
                _ConsentRow(
                  value: _paymentTransferAccepted,
                  onChanged: (v) =>
                      setState(() => _paymentTransferAccepted = v ?? false),
                  label:
                      'Abonelik doğrulaması için Apple Inc. / Google Inc. (ABD)\'ye aktarım '
                      'yapılmasına açık rıza veriyorum (KVKK Md.9). Kart bilgisi FitMentor\'da '
                      'saklanmaz.',
                  kvkkTab: LegalTab.kvkk,
                  linkText: 'Aktarım Detayı',
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
                    onPressed:
                        (authProvider.isLoading ||
                            !_tosAccepted ||
                            !_healthDataAccepted ||
                            !_aiTransferAccepted ||
                            !_paymentTransferAccepted)
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
}

// ── Yeniden kullanılabilir onay satırı widget'ı ────────────────────────────────

class _ConsentRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final LegalTab kvkkTab;
  final String linkText;

  const _ConsentRow({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.kvkkTab,
    required this.linkText,
  });

  static const _kAccentColor = Color(0xFFCC7A4A);

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
              (s) => s.contains(WidgetState.selected)
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
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: label),
                  const TextSpan(text: ' '),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LegalScreen(initialTab: kvkkTab),
                        ),
                      ),
                      child: Text(
                        linkText,
                        style: const TextStyle(
                          color: _kAccentColor,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          decorationColor: _kAccentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
