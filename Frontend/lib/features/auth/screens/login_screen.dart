import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/storage_helper.dart';
import '../../nutrition/data/datasources/hive_diet_storage.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/data/repositories/weight_repository_impl.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

/// Uygulama accent rengi (main.dart, HomeScreen ile uyumlu)
const _kAccentColor = Color(0xFFCC7A4A);

/// Arka plan görseli (bulanıklık yok, net)
const _kGymBackground = 'assets/images/ChatGPT Image 30 Oca 2026 02_04_11.png';

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

      if (!mounted) return;

      if (success) {
        if (_rememberMe) {
          await StorageHelper.saveRememberedEmail(_emailController.text.trim());
        } else {
          await StorageHelper.clearRememberedEmail();
        }
        if (!mounted) return;
        // Eski kullanıcının Hive box'larını kapat; yeni userId ile yeniden açılacak
        await HiveDietStorage.closeBoxesForSuffix(oldSuffix);
        await HiveWeightRepository.closeBoxesForSuffix(oldSuffix);
        debugPrint('Login: switchUser -> ${StorageHelper.getUserStorageSuffix()} (closed $oldSuffix)');
        final dietProvider = Provider.of<DietProvider>(context, listen: false);
        final weightProvider = Provider.of<WeightProvider>(context, listen: false);
        dietProvider.reset();
        await dietProvider.init();
        weightProvider.reset();
        await weightProvider.loadEntries();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
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
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false, // Klavye açılınca ekranı sıkıştırma (arkaplan sabit kalsın)
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ... (arkaplan kodları aynı)
          Positioned.fill(
            child: Image.asset(
              _kGymBackground,
              fit: BoxFit.cover,
              cacheWidth: 1080,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF0A0A0A),
              ),
            ),
          ),
          // ... (overlay aynı)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.1),
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.5),
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
                      bottom: bottomPadding + 24 + viewInsetsBottom, // Klavye boşluğunu manuel ekle
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Logo & başlık (uygulama UI ile uyumlu)
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _kAccentColor.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _kAccentColor.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kAccentColor.withValues(alpha: 0.25),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.fitness_center_rounded,
                                size: 40,
                                color: _kAccentColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Fitness Tracker',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hedeflerine ulaş',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        // Form kartı (HomeScreen kart stili)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 28,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1F1F1F),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3), // 0.4 -> 0.3
                                blurRadius: 10, // 16 -> 10
                                offset: const Offset(0, 4), // 6 -> 4
                              ),
                              // İkinci gölge kaldırıldı veya basitleştirildi
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'E-posta',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      fontSize: 15,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.email_outlined,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      size: 22,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF2A2A2A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: _kAccentColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'E-posta gerekli';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Geçerli bir e-posta girin';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Şifre alanı
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  keyboardType: TextInputType.visiblePassword,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Şifre',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.45),
                                      fontSize: 15,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outlined,
                                      color: Colors.white.withValues(alpha: 0.5),
                                      size: 22,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: Colors.white.withValues(alpha: 0.5),
                                        size: 22,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF2A2A2A),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.15),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: _kAccentColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 16,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Şifre gerekli';
                                    }
                                    if (value.length < 6) {
                                      return 'Şifre en az 6 karakter olmalı';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                // Beni hatırla
                                Row(
                                  children: [
                                    SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: Checkbox(
                                        value: _rememberMe,
                                        onChanged: (value) {
                                          setState(() => _rememberMe = value ?? false);
                                        },
                                        fillColor: MaterialStateProperty.resolveWith((states) {
                                          if (states.contains(MaterialState.selected)) {
                                            return _kAccentColor;
                                          }
                                          return Colors.white.withValues(alpha: 0.2);
                                        }),
                                        checkColor: Colors.white,
                                        side: BorderSide(
                                          color: Colors.white.withValues(alpha: 0.4),
                                          width: 1,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(5),
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
                                          fontSize: 14,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                // Giriş butonu (accent renk - Yemek Ekle / BAŞLAT stili)
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _kAccentColor.withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _kAccentColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: _kAccentColor.withValues(alpha: 0.5),
                                      disabledForegroundColor: Colors.white70,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text(
                                            'Giriş Yap',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
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
                        const SizedBox(height: 12),
                        // Backend bağlantı testi (giriş yapamıyorsan önce bunu dene)
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              final res = await ApiClient().get(ApiConstants.healthTest);
                              final msg = res.data is Map && (res.data as Map).containsKey('message')
                                  ? (res.data as Map)['message'].toString()
                                  : 'Backend yanıt verdi';
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(msg), backgroundColor: Colors.green),
                                );
                              }
                            } on ApiException catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Backend yok: ${e.message}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Bağlantı hatası: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          icon: Icon(Icons.wifi_find, size: 18, color: Colors.white.withValues(alpha: 0.7)),
                          label: Text(
                            'Backend bağlantısını test et',
                            style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                          ),
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
