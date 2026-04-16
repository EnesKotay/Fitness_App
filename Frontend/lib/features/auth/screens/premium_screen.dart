import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:ui';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/premium_features.dart';
import '../../../../core/services/iap_service.dart';
import '../../../core/widgets/premium_state_badge.dart';
import '../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'legal_screen.dart';

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
    id: IapProductIds.monthly,
    title: 'Aylık',
    subtitle: '149₺ / ay',
    price: '149',
    priceLabel: '149₺ / ay',
    months: 1,
  ),
  _Plan(
    id: IapProductIds.yearly,
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
        // Ebeveyn / aile paylaşımı onayı bekleniyor
        if (result.errorMessage == 'pending') {
          setState(() => _purchasing = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Ödeme onay bekliyor (ebeveyn / aile paylaşımı). '
                  'Onaylandıktan sonra premium otomatik aktif olacak.',
                ),
                backgroundColor: Color(0xFF1A3A5C),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 6),
              ),
            );
          }
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
            'receiptData': result.receiptData, // iOS
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

  /// App Store / Play Store abonelik yönetim sayfasını açar.
  /// Apple IAP abonelikleri yalnızca mağaza üzerinden iptal edilebilir —
  /// uygulama içi backend çağrısıyla iptal etmek mümkün değildir.
  Future<void> _openManageSubscriptions() async {
    if (!mounted) return;
    final isIos = Platform.isIOS;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Aboneliği Yönet',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          isIos
              ? 'Aboneliğini iptal etmek veya değiştirmek için iOS Ayarlar → Apple ID → Abonelikler sayfasını kullan. Abonelik iptal edilene kadar dönem sonunda otomatik yenilenir.'
              : 'Aboneliğini iptal etmek veya değiştirmek için Google Play → Abonelikler sayfasını kullan. Abonelik iptal edilene kadar dönem sonunda otomatik yenilenir.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kapat', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _premiumGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isIos ? 'App Store\'u Aç' : 'Play Store\'u Aç'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    final url = isIos
        ? 'https://apps.apple.com/account/subscriptions'
        : 'https://play.google.com/store/account/subscriptions';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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
              text: 'AI Koç ve adaptif planlar',
            ),
            const _UnlockLine(
              icon: Icons.insights_rounded,
              text: 'Gelişmiş analiz, grafikler ve raporlar',
            ),
            const _UnlockLine(
              icon: Icons.restaurant_menu_rounded,
              text: 'Haftalık öğün planı ve akıllı alışveriş',
            ),
            const _UnlockLine(
              icon: Icons.fitness_center_rounded,
              text: 'Hazır antrenman programları',
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
              _ValuePill(icon: Icons.insights_rounded, label: 'Derin Analiz'),
              _ValuePill(
                icon: Icons.restaurant_menu_rounded,
                label: 'Öğün Planı',
              ),
              _ValuePill(
                icon: Icons.fitness_center_rounded,
                label: 'Programlar',
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
          ...premiumFeatures.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildFeatureCard(f),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(PremiumFeature f) {
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
    final isYearly = plan.months == 12;

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
                    IapService.instance.priceFor(plan.id) ?? plan.priceLabel,
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
    final storePrice = IapService.instance.priceFor(_selectedPlan.id);
    final priceLabel = storePrice ?? _selectedPlan.priceLabel;
    final priceReady = storePrice != null;
    final canBuy = !_purchasing && priceReady;

    return Column(
      children: [
        // ── Satın Alma Butonu ──────────────────────────────────────────────────
        Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            gradient: canBuy
                ? const LinearGradient(
                    colors: [_premiumLightGold, _premiumGold, _premiumAmber],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: canBuy ? null : Colors.white24,
            borderRadius: BorderRadius.circular(18),
            boxShadow: canBuy
                ? [
                    BoxShadow(
                      color: _premiumGold.withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canBuy ? _startIapPurchase : null,
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
                    : !priceReady
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Fiyat yükleniyor...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
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
        // ── Satın Alımları Geri Yükle ─────────────────────────────────────────
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
        const SizedBox(height: 14),
        // ── Ödeme ve Otomatik Yenileme Açıklaması (App Store zorunluluğu) ──────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Ödeme, satın alma onayında Apple ID / Google hesabınıza yapılır. '
            'Abonelik, mevcut dönem bitmeden en az 24 saat önce iptal edilmediği takdirde '
            'otomatik olarak yenilenir ve aynı ücret tekrar tahsil edilir. '
            'Aboneliğinizi istediğiniz zaman ${Platform.isIOS ? 'iOS Ayarlar → Apple ID → Abonelikler' : 'Google Play → Abonelikler'} '
            'üzerinden yönetebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 10.5,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── Kullanım Şartları & Gizlilik Politikası ───────────────────────────
        _buildLegalRow(),
      ],
    );
  }

  Widget _buildLegalRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _LegalLink(
          label: 'Kullanım Şartları',
          isPrivacy: false,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            '•',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 11,
            ),
          ),
        ),
        const _LegalLink(
          label: 'Gizlilik Politikası',
          isPrivacy: true,
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
            child: OutlinedButton.icon(
              onPressed: _openManageSubscriptions,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: Text(
                _cancelAtPeriodEnd
                    ? 'İptal Planlandı — Aboneliği Yönet'
                    : 'Aboneliği Yönet',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _cancelAtPeriodEnd
                    ? Colors.white38
                    : _premiumLightGold,
                side: BorderSide(
                  color: _cancelAtPeriodEnd
                      ? Colors.white.withValues(alpha: 0.1)
                      : _premiumGold.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
      return '$planLabel Aboneliğini ${Platform.isIOS ? 'iOS Ayarlar → Apple ID → Abonelikler' : 'Google Play → Abonelikler'} üzerinden yönetebilirsin.$expiryText';
    }

    return '$planLabel$expiryText';
  }
}

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
        border: Border.all(color: _premiumGold.withValues(alpha: 0.15)),
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

class _LegalLink extends StatelessWidget {
  const _LegalLink({required this.label, required this.isPrivacy});
  final String label;
  final bool isPrivacy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LegalScreen(
              initialTab: isPrivacy ? LegalTab.privacy : LegalTab.terms,
            ),
          ),
        );
      },
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.38),
          fontSize: 11,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white.withValues(alpha: 0.2),
        ),
      ),
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
