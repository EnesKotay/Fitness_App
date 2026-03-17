import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/iap_service.dart';
import '../../../core/widgets/premium_state_badge.dart';
import '../providers/auth_provider.dart';

const Color _premiumGold = Color(0xFFD97706);
const Color _premiumLightGold = Color(0xFFFBBF24);
const Color _premiumAmber = Color(0xFFFF8F00);
const Color _darkBg = Color(0xFF070809);

// ─── Plan model ──────────────────────────────────────────────────────────────

class _Plan {
  final String id;
  final String title;
  final String subtitle;
  final String price;
  final String priceLabel;
  final String? badge;
  final int months;

  const _Plan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.priceLabel,
    this.badge,
    required this.months,
  });
}

const _plans = [
  _Plan(
    id: 'monthly',
    title: 'Aylık',
    subtitle: '149₺ / ay',
    price: '149',
    priceLabel: '149₺ / ay',
    months: 1,
  ),
  _Plan(
    id: 'yearly',
    title: 'Yıllık',
    subtitle: '1199₺ / yıl',
    price: '1199',
    priceLabel: '1199₺ / yıl',
    badge: '%33 indirim',
    months: 12,
  ),
];

// ─── Main Screen ─────────────────────────────────────────────────────────────

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen>
    with SingleTickerProviderStateMixin {
  bool _isPremiumActive = false;
  bool _canCancel = false;
  bool _cancelAtPeriodEnd = false;
  String? _activePlanId;
  DateTime? _premiumExpiresAt;
  _Plan _selectedPlan = _plans[1];
  bool _purchasing = false;
  bool _cancelling = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _checkStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final response = await ApiClient().get(ApiConstants.premiumStatus);
      final data = response.data;
      if (mounted && data is Map) {
        final isActive = data['isActive'] == true;
        final planId = data['planId']?.toString();
        final expiresAtRaw = data['expiresAt']?.toString();
        final expiresAt = expiresAtRaw == null || expiresAtRaw.isEmpty
            ? null
            : DateTime.tryParse(expiresAtRaw);
        final canCancel = data['canCancel'] == true;
        final cancelAtPeriodEnd = data['cancelAtPeriodEnd'] == true;
        final canceledAtRaw = data['canceledAt']?.toString();
        final canceledAt = canceledAtRaw == null || canceledAtRaw.isEmpty
            ? null
            : DateTime.tryParse(canceledAtRaw);

        context.read<AuthProvider>().setPremiumActive(
          isActive,
          premiumPlan: planId,
          premiumExpiresAt: expiresAt,
          premiumCancelAtPeriodEnd: cancelAtPeriodEnd,
          premiumCanceledAt: canceledAt,
        );
        setState(() {
          _isPremiumActive = isActive;
          _activePlanId = planId;
          _premiumExpiresAt = expiresAt;
          _canCancel = canCancel;
          _cancelAtPeriodEnd = cancelAtPeriodEnd;
        });
      }
    } catch (e) {
      debugPrint('PremiumScreen: durum kontrol hatası: $e');
    }
  }

  Future<void> _startIapPurchase() async {
    setState(() => _purchasing = true);

    final iap = IapService.instance;

    // Callback: mağaza işlemi tamamlandığında çağrılır
    iap.onPurchaseComplete = (IapPurchaseResult result) async {
      if (!mounted) return;

      if (!result.success) {
        // Kullanıcı kendisi iptal etti — sessizce geç
        if (result.errorMessage == 'canceled') {
          setState(() => _purchasing = false);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Satın alma başarısız oldu.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _purchasing = false);
        return;
      }

      // Başarılı → backend'e token gönder, premium aktifleştir
      try {
        await ApiClient().post(
          ApiConstants.verifyIapPurchase,
          data: {
            'planId': result.planId,
            'purchaseToken': result.purchaseToken, // Android
            'receiptData': result.receiptData,     // iOS
            'transactionId': result.transactionId,
            'platform': Platform.isAndroid ? 'android' : 'ios',
          },
        );
        if (!mounted) return;
        await _checkStatus();
        if (!mounted) return;
        await _showSuccessSheet();
      } catch (e) {
        debugPrint('PremiumScreen: backend doğrulama hatası: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Satın alma alındı fakat doğrulanamadı. '
                'Birkaç dakika sonra tekrar kontrol et.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _purchasing = false);
      }
    };

    // Native ödeme sayfasını aç
    final started = await iap.purchase(_selectedPlan.id);
    if (!started && mounted) {
      setState(() => _purchasing = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _purchasing = true);

    final iap = IapService.instance;

    iap.onPurchaseComplete = (IapPurchaseResult result) async {
      if (!mounted) return;
      if (result.success) {
        // Geri yüklenen satın almayı backend'e bildir
        try {
          await ApiClient().post(
            ApiConstants.verifyIapPurchase,
            data: {
              'planId': result.planId,
              'purchaseToken': result.purchaseToken,
              'receiptData': result.receiptData,
              'transactionId': result.transactionId,
              'platform': Platform.isAndroid ? 'android' : 'ios',
            },
          );
        } catch (e) {
          debugPrint('PremiumScreen: restore backend hatası: $e');
        }
        if (mounted) await _checkStatus();
      }
      if (mounted) setState(() => _purchasing = false);
    };

    try {
      await iap.restorePurchases();
      // Geri yükleme yoksa stream tetiklenmez; state'i sıfırla
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() => _purchasing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satın alma geçmişi kontrol edildi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('PremiumScreen: restore error: $e');
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _cancelPremium() async {
    if (_cancelling) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Üyeliği İptal Et',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Premium üyeliğini iptal etmek istediğine emin misin? '
          'Otomatik yenileme kapanacak. Premium erişimin mevcut dönemin sonuna kadar devam edecek.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Vazgeç',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'İptal Et',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await ApiClient().post(ApiConstants.downgradePremium);
      if (mounted) {
        await _checkStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'İptal planlandı. Premium dönem sonuna kadar aktif kalacak.',
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('İptal işlemi başarısız oldu. Lütfen tekrar dene.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  // ignore: unused_element
  Future<void> _showSuccessSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF101115),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _premiumGold.withValues(alpha: 0.32)),
          boxShadow: [
            BoxShadow(
              color: _premiumGold.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _premiumGold.withValues(alpha: 0.12),
                  border: Border.all(
                    color: _premiumGold.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: _premiumLightGold,
                  size: 42,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(child: PremiumStateBadge(active: true)),
            const SizedBox(height: 16),
            const Text(
              'Premium aktif edildi!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Artık tüm AI araçları ve gelişmiş analiz özellikleri hesabında açık.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.68),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            const _UnlockLine(
              icon: Icons.smart_toy_rounded,
              text: 'AI Koç — Claude ile sınırsız kullanım',
            ),
            const _UnlockLine(
              icon: Icons.camera_alt_rounded,
              text: 'Besin etiketi ve yemek fotoğrafı analizi',
            ),
            const _UnlockLine(
              icon: Icons.insights_rounded,
              text: 'Gelişmiş trend ve analiz araçları',
            ),
            const _UnlockLine(
              icon: Icons.restaurant_menu_rounded,
              text: 'Akıllı tarif ve alışveriş listesi',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context)
                  ..pop()
                  ..pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF20160B),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Harika, kullanmaya başla!',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Animated top-right glow
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Positioned(
              top: -140,
              right: -100,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _premiumGold.withValues(
                    alpha: 0.13 * _pulseAnimation.value,
                  ),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 110, sigmaY: 110),
                  child: const SizedBox(),
                ),
              ),
            ),
          ),
          // Bottom-left secondary glow
          Positioned(
            bottom: -100,
            left: -140,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _premiumAmber.withValues(alpha: 0.06),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: const SizedBox(),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroSection(),
                      _buildKeyFeaturesSection(),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildIncludedSection(),
                      ),
                      const SizedBox(height: 28),
                      if (!_isPremiumActive) ...[
                        _buildPlanSection(),
                        const SizedBox(height: 12),
                        _buildTrustRow(),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildActiveCard(),
                        ),
                      ],
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        children: [
          // Icon with layered glow rings
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) => Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _premiumGold.withValues(
                        alpha: 0.12 * _pulseAnimation.value,
                      ),
                      width: 1.5,
                    ),
                  ),
                ),
                // Inner glow
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _premiumGold.withValues(alpha: 0.1),
                    border: Border.all(
                      color: _premiumGold.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _premiumGold.withValues(
                          alpha: 0.25 * _pulseAnimation.value,
                        ),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: child,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 36,
              color: _premiumLightGold,
            ),
          ),
          const SizedBox(height: 22),
          // PRO title with gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFF0A0), _premiumLightGold, _premiumGold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            child: const Text(
              'PRO ÜYELİK',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'AI destekli araçların tüm gücünü aç.',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Temel takip araçları ücretsiz kalır. Premium, analiz,\notomasyon ve AI özelliklerini açar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.42),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Value pills
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _ValuePill(icon: Icons.smart_toy_rounded, label: 'AI Koç'),
              _ValuePill(icon: Icons.camera_alt_rounded, label: 'Besin Tarama'),
              _ValuePill(icon: Icons.insights_rounded, label: 'Derin Analiz'),
              _ValuePill(
                icon: Icons.restaurant_menu_rounded,
                label: 'Akıllı Tarif',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Key Features ─────────────────────────────────────────────────────────

  Widget _buildKeyFeaturesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Premium ile açılanlar'),
          const SizedBox(height: 14),
          ..._featureCards.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildFeatureCard(f),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(_FeatureData f) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            f.accent.withValues(alpha: 0.10),
            Colors.white.withValues(alpha: 0.025),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: f.accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: f.accent.withValues(alpha: 0.16),
              border: Border.all(color: f.accent.withValues(alpha: 0.28)),
              boxShadow: [
                BoxShadow(
                  color: f.accent.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(f.icon, color: f.accent, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  f.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: f.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: f.accent.withValues(alpha: 0.24)),
            ),
            child: Text(
              f.tag,
              style: TextStyle(
                color: f.accent,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Free included ────────────────────────────────────────────────────────

  Widget _buildIncludedSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 6),
              Text(
                'Her zaman ücretsiz',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FreePill('Manuel yemek ekleme'),
              _FreePill('Barkod tarama'),
              _FreePill('Kalori & makro takibi'),
              _FreePill('Su & kilo takibi'),
              _FreePill('Workout kaydı'),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Plan selection ───────────────────────────────────────────────────────

  Widget _buildPlanSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: 'Plan seç'),
          const SizedBox(height: 14),
          // Yearly plan (highlighted)
          _buildPlanCard(_plans[1]),
          const SizedBox(height: 10),
          // Monthly plan
          _buildPlanCard(_plans[0]),
          const SizedBox(height: 20),
          _buildPaymentButton(),
        ],
      ),
    );
  }

  Widget _buildPlanCard(_Plan plan) {
    final selected = _selectedPlan.id == plan.id;
    final isYearly = plan.id == 'yearly';

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: selected && isYearly
              ? LinearGradient(
                  colors: [
                    _premiumGold.withValues(alpha: 0.2),
                    _premiumGold.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : selected
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.07),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? _premiumGold.withValues(alpha: isYearly ? 0.55 : 0.3)
                : Colors.white.withValues(alpha: 0.08),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected && isYearly
              ? [
                  BoxShadow(
                    color: _premiumGold.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? _premiumGold
                      : Colors.white.withValues(alpha: 0.22),
                  width: 2,
                ),
                color: selected
                    ? _premiumGold.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _premiumLightGold,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        plan.title,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (plan.badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _premiumGold.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: _premiumGold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            plan.badge!,
                            style: const TextStyle(
                              color: _premiumLightGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    plan.priceLabel,
                    style: TextStyle(
                      color: selected
                          ? _premiumLightGold.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isYearly) ...[
                    const SizedBox(height: 2),
                    Text(
                      '99₺/ay olarak hesaplanır',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isYearly)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_premiumGold, _premiumAmber],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'TAVSİYE\nEDİLEN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton() {
    final priceLabel = '${_selectedPlan.price}₺';
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: _purchasing
                ? null
                : const LinearGradient(
                    colors: [_premiumLightGold, _premiumGold, _premiumAmber],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _purchasing ? Colors.white24 : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: _purchasing
                ? null
                : [
                    BoxShadow(
                      color: _premiumGold.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _purchasing ? null : _startIapPurchase,
              borderRadius: BorderRadius.circular(18),
              child: Center(
                child: _purchasing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_open_rounded,
                            size: 18,
                            color: Color(0xFF20160B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Premium'u Aç — $priceLabel",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A0F00),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _purchasing ? null : _restorePurchases,
          child: Text(
            'Satın alımları geri yükle',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TrustItem(icon: Icons.lock_rounded, label: 'Güvenli ödeme'),
          _trustDot(),
          _TrustItem(
            icon: Icons.cancel_outlined,
            label: 'İstediğin zaman iptal',
          ),
          _trustDot(),
          _TrustItem(icon: Icons.store_rounded, label: 'App Store / Play'),
        ],
      ),
    );
  }

  Widget _trustDot() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Container(
      width: 3,
      height: 3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.2),
      ),
    ),
  );

  Widget _buildActiveCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _premiumGold.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _premiumGold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _premiumGold.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PremiumStateBadge(active: true, compact: true),
              const SizedBox(width: 10),
              const Text(
                'Premium aktif',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _premiumGold.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: _premiumGold.withValues(alpha: 0.28),
                  ),
                ),
                child: Text(
                  _activePlanId == 'yearly' ? 'Yıllık' : 'Aylık',
                  style: const TextStyle(
                    color: _premiumLightGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _buildActiveSubscriptionText(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton(
              onPressed: _canCancel
                  ? (_cancelling ? null : _cancelPremium)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _canCancel ? Colors.redAccent : Colors.white38,
                side: BorderSide(
                  color: _canCancel
                      ? Colors.redAccent.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _cancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.redAccent,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _cancelAtPeriodEnd
                          ? 'İptal Planlandı'
                          : (_canCancel
                              ? 'Üyeliği İptal Et'
                              : 'Yıllık Plan Kilitli'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildActiveSubscriptionText() {
    final planLabel = switch (_activePlanId) {
      'monthly' => 'Aylık plan aktif.',
      'yearly' => 'Yıllık plan aktif.',
      _ => 'Premium plan aktif.',
    };

    final expiryText = _premiumExpiresAt == null
        ? ''
        : ' Bitiş: ${_premiumExpiresAt!.day.toString().padLeft(2, '0')}/${_premiumExpiresAt!.month.toString().padLeft(2, '0')}/${_premiumExpiresAt!.year}.';

    if (_cancelAtPeriodEnd) {
      return '$planLabel Otomatik yenileme kapatıldı. Premium erişimin dönem sonuna kadar devam edecek.$expiryText';
    }

    if (_canCancel) {
      return '$planLabel Dilersen otomatik yenilemeyi kapatabilirsin; premium erişimin dönem sonuna kadar sürer.$expiryText';
    }

    if (_activePlanId == 'yearly') {
      return '$planLabel Bu plan satın alındıktan sonra iptal edilemez.$expiryText';
    }

    return '$planLabel$expiryText';
  }
}

// ─── Static data ──────────────────────────────────────────────────────────────

class _FeatureData {
  final IconData icon;
  final String title;
  final String description;
  final Color accent;
  final String tag;

  const _FeatureData({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
    required this.tag,
  });
}

const _featureCards = [
  _FeatureData(
    icon: Icons.smart_toy_rounded,
    title: 'AI Koç — Claude ile',
    description: 'Kişiselleştirilmiş koçluk, sınırsız soru ve derin analiz.',
    accent: Color(0xFFFFB74D),
    tag: 'KİŞİSEL',
  ),
  _FeatureData(
    icon: Icons.camera_alt_rounded,
    title: 'Kamera ile Besin Analizi',
    description: 'Etiket tara veya yemek fotoğrafını analiz et.',
    accent: Color(0xFFB388FF),
    tag: 'HIZLI',
  ),
  _FeatureData(
    icon: Icons.insights_rounded,
    title: 'Beslenme Trendleri',
    description: 'Kalori ve makro trendlerini grafiklerle derinlemesine incele.',
    accent: Color(0xFF64B5F6),
    tag: 'ANALİZ',
  ),
  _FeatureData(
    icon: Icons.restaurant_menu_rounded,
    title: 'Akıllı Tarif ve Alışveriş',
    description: 'AI destekli tarif önerileri ve planına uygun alışveriş.',
    accent: Color(0xFF81C784),
    tag: 'PLANLAMA',
  ),
];

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              colors: [_premiumLightGold, _premiumGold],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: _premiumGold.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _premiumLightGold),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreePill extends StatelessWidget {
  const _FreePill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 12,
            color: Colors.white.withValues(alpha: 0.4),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.25)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _UnlockLine extends StatelessWidget {
  const _UnlockLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _premiumLightGold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
