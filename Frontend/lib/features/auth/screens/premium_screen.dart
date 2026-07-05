import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/premium_features.dart';
import '../../../../core/services/iap_service.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../core/widgets/premium_state_badge.dart';
import '../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'legal_screen.dart';

const Color _premiumGold = Color(0xFFD97706);
const Color _premiumLightGold = Color(0xFFFBBF24);

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
    subtitle: '₺799,99 / yıl',
    price: '799.99',
    priceLabel: '₺799,99 / yıl',
    badge: '%55 tasarruf',
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
  final IapService _iap = IapService.instance;
  bool _isPremiumActive = false;
  bool _isCheckingPremiumStatus = true;
  bool _canCancel = false;
  bool _cancelAtPeriodEnd = false;
  String? _activePlanId;
  DateTime? _premiumExpiresAt;
  _Plan _selectedPlan = _plans[1];
  bool _purchasing = false;
  bool _showPurchaseHelp = false;
  StreamSubscription<IapPurchaseResult>? _iapSubscription;
  Timer? _purchasingTimeoutTimer;
  Timer? _purchaseHelpTimer;

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
    _iap.addListener(_onIapChanged);
    _iapSubscription = _iap.purchaseResultStream.listen(_handlePurchaseResult);
    _syncPremiumStateFromAuth();
    _checkStatus();
  }

  @override
  void dispose() {
    _purchasingTimeoutTimer?.cancel();
    _purchaseHelpTimer?.cancel();
    _iapSubscription?.cancel();
    _iap.removeListener(_onIapChanged);
    _pulseController.dispose();
    super.dispose();
  }

  void _onIapChanged() {
    if (mounted) setState(() {});
  }

  bool _isActivePremiumTier(String? tier, DateTime? expiresAt) {
    return isPremiumTier(tier, expiresAt: expiresAt);
  }

  void _syncPremiumStateFromAuth() {
    final user = context.read<AuthProvider>().user;
    final isActive = _isActivePremiumTier(
      user?.premiumTier,
      user?.premiumExpiresAt,
    );
    if (!isActive) return;
    _isPremiumActive = true;
    _activePlanId = user?.premiumPlan;
    _premiumExpiresAt = user?.premiumExpiresAt;
    _cancelAtPeriodEnd = user?.premiumCancelAtPeriodEnd == true;
  }

  Future<void> _checkStatus() async {
    if (mounted) {
      setState(() => _isCheckingPremiumStatus = true);
    }

    try {
      final response = await ApiClient().get(ApiConstants.premiumStatus);
      final data = response.data;
      if (mounted && data is Map) {
        final isActive = data['isActive'] == true;
        final planId = normalizePremiumPlanId(data['planId']?.toString());
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

        if (!isActive) {
          unawaited(_iap.refreshProducts());
        }
      }
    } catch (e) {
      debugPrint('PremiumScreen: durum kontrol hatası: $e');
      if (!_isPremiumActive) {
        unawaited(_iap.refreshProducts());
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingPremiumStatus = false);
      }
    }
  }

  void _startPurchasingGuard() {
    setState(() {
      _purchasing = true;
      _showPurchaseHelp = false;
    });
    _purchasingTimeoutTimer?.cancel();
    _purchaseHelpTimer?.cancel();
    _purchaseHelpTimer = Timer(const Duration(seconds: 10), () {
      if (mounted && _purchasing) {
        setState(() => _showPurchaseHelp = true);
      }
    });
    _purchasingTimeoutTimer = Timer(const Duration(seconds: 25), () {
      if (mounted && _purchasing) {
        setState(() {
          _purchasing = false;
          _showPurchaseHelp = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'App Store yanıt vermedi. Ödeme penceresi açılmadıysa tekrar deneyebilirsin.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 6),
          ),
        );
      }
    });
  }

  Future<void> _handlePurchaseResult(IapPurchaseResult result) async {
    if (!mounted) return;
    _purchasingTimeoutTimer?.cancel();
    _purchaseHelpTimer?.cancel();

    if (!result.success) {
      if (result.errorMessage == 'canceled') {
        setState(() {
          _purchasing = false;
          _showPurchaseHelp = false;
        });
        return;
      }
      if (result.errorMessage == 'pending') {
        setState(() {
          _purchasing = false;
          _showPurchaseHelp = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ödemen onay bekliyor — bu genellikle aile paylaşımı veya '
              'ebeveyn denetimi olduğunda olur. '
              'Onay verildiğinde premium üyeliğin otomatik aktif olacak.',
            ),
            backgroundColor: Color(0xFF1A3A5C),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 7),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorMessage ??
                'Satın alma tamamlanamadı. Lütfen tekrar dene.',
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
      setState(() {
        _purchasing = false;
        _showPurchaseHelp = true;
      });
      return;
    }

    try {
      final optimisticPlan = normalizePremiumPlanId(result.planId);
      final optimisticExpiresAt =
          result.expiresAt ??
          DateTime.now().add(
            optimisticPlan == 'yearly'
                ? const Duration(days: 365)
                : const Duration(days: 30),
          );
      context.read<AuthProvider>().setPremiumActive(
        true,
        premiumPlan: optimisticPlan,
        premiumExpiresAt: optimisticExpiresAt,
        premiumCancelAtPeriodEnd: false,
      );
      setState(() {
        _isPremiumActive = true;
        _activePlanId = optimisticPlan;
        _premiumExpiresAt = optimisticExpiresAt;
        _cancelAtPeriodEnd = false;
      });

      // Satın alma RevenueCat'e işlendi; backend RevenueCat REST API'sinden
      // abonelik durumunu çekip kullanıcının premium alanlarını günceller.
      await ApiClient()
          .post(
            ApiConstants.premiumSync,
            data: {
              'planId': result.planId,
              'transactionId': result.transactionId,
              'platform': Platform.isAndroid ? 'android' : 'ios',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      await _checkStatus().timeout(const Duration(seconds: 12));
      if (!mounted) return;

      if (_isPremiumActive ||
          isPremiumTier(
            context.read<AuthProvider>().user?.premiumTier,
            expiresAt: context.read<AuthProvider>().user?.premiumExpiresAt,
          )) {
        await _showSuccessSheet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Satın alım doğrulandı ancak aktif bir abonelik bulunamadı. '
              'Uygulamayı kapatıp açarsan premium aktif olmalı.',
            ),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('PremiumScreen: backend doğrulama hatası: $e');
      if (mounted) {
        final backendMessage = e is ApiException && e.statusCode != null
            ? e.message
            : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              backendMessage ??
                  'Ödemen alındı fakat sistemimizle doğrulama şu an tamamlanamadı. '
                      'Uygulamayı kapatıp açarsan premium genellikle birkaç dakika içinde aktif olur.',
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 7),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _purchasing = false;
          _showPurchaseHelp = false;
        });
      }
    }
  }

  String _yearlyBadge() {
    try {
      final products = _iap.products;
      final monthly = products.firstWhere((p) => p.id == IapProductIds.monthly);
      final yearly = products.firstWhere((p) => p.id == IapProductIds.yearly);
      final annualizedMonthly = monthly.rawPrice * 12;
      if (annualizedMonthly > yearly.rawPrice) {
        final pct =
            ((annualizedMonthly - yearly.rawPrice) / annualizedMonthly * 100)
                .round();
        return '%$pct indirim';
      }
    } catch (_) {}
    return '%33 indirim';
  }

  Future<bool> _ensurePaymentTransferConsent() async {
    if (StorageHelper.getPrivacyPaymentTransferConsent()) {
      return true;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Ödeme Aktarımı Rızası Gerekli',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Premium satın alma ve geri yükleme için abonelik verisinin '
          'Apple veya Google ile doğrulanmasına izin vermen gerekiyor. '
          'Ayarlar > Gizlilik bölümünden bu izni açabilirsin.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.74),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Gizlilik Ayarlarına Git'),
          ),
        ],
      ),
    );

    if (approved == true && mounted) {
      Navigator.of(context).pushNamed('/settings-privacy');
    }
    return false;
  }

  Future<void> _startIapPurchase() async {
    if (!await _ensurePaymentTransferConsent()) {
      return;
    }
    _startPurchasingGuard();
    final started = await _iap.purchase(_selectedPlan.id);
    if (!started && mounted) {
      _purchasingTimeoutTimer?.cancel();
      _purchaseHelpTimer?.cancel();
      setState(() {
        _purchasing = false;
        _showPurchaseHelp = true;
      });
    }
  }

  Future<void> _restorePurchases() async {
    if (!await _ensurePaymentTransferConsent()) {
      return;
    }
    _startPurchasingGuard();
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('PremiumScreen: restore error: $e');
      if (mounted) {
        _purchasingTimeoutTimer?.cancel();
        _purchaseHelpTimer?.cancel();
        setState(() {
          _purchasing = false;
          _showPurchaseHelp = true;
        });
      }
    }
  }

  void _resetPurchaseState({bool showHelp = false}) {
    _purchasingTimeoutTimer?.cancel();
    _purchaseHelpTimer?.cancel();
    if (mounted) {
      setState(() {
        _purchasing = false;
        _showPurchaseHelp = showHelp;
      });
    }
  }

  Future<void> _retryPurchase() async {
    _resetPurchaseState();
    await _iap.refreshProducts();
    await _checkStatus();
    if (!mounted || _isPremiumActive) return;
    await _startIapPurchase();
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

  // ══════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.of(context).padding;
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        children: [
          // ── Scrollable body ──
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: safe.top + 56),
                _buildLightHero(),
                const SizedBox(height: 28),
                if (_isCheckingPremiumStatus && !_isPremiumActive) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildStatusLoadingCard(),
                  ),
                  const SizedBox(height: 40),
                ] else if (!_isPremiumActive) ...[
                  _buildHighlightScroll(),
                  const SizedBox(height: 28),
                  _buildLightFeatures(),
                  const SizedBox(height: 280),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildActiveCard(),
                  ),
                  const SizedBox(height: 40),
                ],
              ],
            ),
          ),
          // ── Close button ──
          Positioned(
            top: safe.top + 10,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: Color(0xFF27272A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: Color(0xFFA1A1AA),
                ),
              ),
            ),
          ),
          // ── Sticky bottom CTA ──
          if (!_isPremiumActive && !_isCheckingPremiumStatus)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildStickyBottomCta(safe.bottom),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFFFF7B3E),
              strokeWidth: 2.5,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Premium durumun kontrol ediliyor...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Light Hero ───────────────────────────────────────────────────────────────

  Widget _buildLightHero() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          // Icon + laurel row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _LaurelBranch(flipped: false),
              const SizedBox(width: 16),
              // App icon card
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) => Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(
                        0xFFFF7B3E,
                      ).withValues(alpha: 0.4 * _pulseAnimation.value),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(
                          0xFFFF7B3E,
                        ).withValues(alpha: 0.35 * _pulseAnimation.value),
                        blurRadius: 36,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF9F5C), Color(0xFFFF6B3E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.local_fire_department_rounded,
                      size: 52,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const _LaurelBranch(flipped: true),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'PusulaFit Premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'AI destekli antrenman ve beslenme koçun.\nHedeflerine daha akıllı, daha hızlı ulaş.',
            style: TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 14.5,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Highlight Cards (horizontal scroll) ─────────────────────────────────────

  Widget _buildHighlightScroll() {
    // 2x2 grid yerine tam genişlik iki kart + alt satır
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildHighlightCard(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A3EAA), Color(0xFF3B5BDB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  icon: Icons.smart_toy_rounded,
                  title: 'AI Koç',
                  subtitle: 'Kişisel Asistan',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHighlightCard(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E7A4A), Color(0xFF40B488)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  icon: Icons.camera_alt_rounded,
                  title: 'Foto Analiz',
                  subtitle: 'Kalori Tahmini',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHighlightCard(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6B2D8B), Color(0xFFA848C8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  icon: Icons.insights_rounded,
                  title: 'Trendler',
                  subtitle: 'Haftalık Analiz',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHighlightCard(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFB84800), Color(0xFFFF7B3E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  icon: Icons.restaurant_menu_rounded,
                  title: 'Öğün Planı',
                  subtitle: 'Makro Takibi',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard({
    required LinearGradient gradient,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Feature rows ─────────────────────────────────────────────────────────────

  Widget _buildLightFeatures() {
    const features = [
      _FeatureRow(
        icon: Icons.smart_toy_rounded,
        iconColor: Color(0xFF3B5BDB),
        title: 'AI Koç ile Birebir Rehberlik',
        subtitle: 'Hedefine özel adaptif programlar ve günlük motivasyon.',
      ),
      _FeatureRow(
        icon: Icons.camera_alt_rounded,
        iconColor: Color(0xFF27A06A),
        title: 'Fotoğrafla Kalori Analizi',
        subtitle: 'Yemeğini fotoğrafla — anında besin değerlerini öğren.',
      ),
      _FeatureRow(
        icon: Icons.insights_rounded,
        iconColor: Color(0xFF9B38B4),
        title: 'Gelişmiş Trendler & Raporlar',
        subtitle: 'Haftalık beslenme ve antrenman trendlerini izle.',
      ),
      _FeatureRow(
        icon: Icons.restaurant_menu_rounded,
        iconColor: Color(0xFFE05A1A),
        title: 'Kişisel Öğün Planı',
        subtitle: 'Makro hedefine uygun haftalık menü ve liste.',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          children: features.asMap().entries.map((entry) {
            final i = entry.key;
            final f = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: f,
                ),
                if (i < features.length - 1)
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFF27272A),
                    indent: 70,
                    endIndent: 16,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Sticky bottom CTA ────────────────────────────────────────────────────────

  Widget _buildStickyBottomCta(double bottomPadding) {
    final storePrice = _iap.priceFor(_selectedPlan.id);
    final priceLabel = storePrice ?? _selectedPlan.priceLabel;
    final isLoadingProducts = _iap.isLoadingProducts;
    final selectedProductLoaded = storePrice != null;
    final canBuy = !_purchasing && !isLoadingProducts && selectedProductLoaded;
    final productError = _iap.productLoadError;
    final buttonLabel = selectedProductLoaded
        ? 'Başla — $priceLabel'
        : 'Paketler yüklenemedi';
    final buttonTextColor = canBuy ? Colors.white : const Color(0xFF52525B);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: const Border(top: BorderSide(color: Color(0xFF27272A))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Plan toggle ──
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFF27272A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: _plans.map((plan) {
                final selected = _selectedPlan.id == plan.id;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPlan = plan),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF3F3F46)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            plan.title,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFFA1A1AA),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (plan.badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF7B3E),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                plan.id == IapProductIds.yearly
                                    ? _yearlyBadge()
                                    : plan.badge!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // ── Price hint ──
          Text(
            priceLabel,
            style: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // ── CTA Button ──
          GestureDetector(
            onTap: canBuy ? _startIapPurchase : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: canBuy
                    ? const LinearGradient(
                        colors: [Color(0xFFFF9F5C), Color(0xFFFF6B3E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: canBuy ? null : const Color(0xFFE5E5EA),
                borderRadius: BorderRadius.circular(14),
                boxShadow: canBuy
                    ? [
                        BoxShadow(
                          color: const Color(
                            0xFFFF7B3E,
                          ).withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: _purchasing || isLoadingProducts
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF7B3E),
                          strokeWidth: 2.5,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            buttonLabel,
                            style: TextStyle(
                              color: buttonTextColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (productError != null && productError.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              productError,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFFFB86B),
                fontSize: 11.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_purchasing || _showPurchaseHelp) ...[
            const SizedBox(height: 8),
            Text(
              _purchasing
                  ? 'Apple ödeme penceresi bekleniyor...'
                  : 'İşlem başlamadıysa tekrar deneyebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ],
          if (_showPurchaseHelp) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _retryPurchase,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7B3E),
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    'Tekrar Dene',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: _restorePurchases,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  child: const Text(
                    'Geri Yükle',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          // ── More options / restore ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _purchasing ? null : _restorePurchases,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7B3E),
                ),
                child: const Text(
                  'Satın Alımı Geri Yükle',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              const Text('·', style: TextStyle(color: Color(0xFF52525B))),
              const SizedBox(width: 4),
              _LightLegalLink(label: 'Gizlilik', isPrivacy: true),
            ],
          ),
          // ── Legal disclaimer ──
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              'Ödeme Apple ID / Google hesabına yapılır. Abonelik dönem bitmeden '
              '24 saat önce iptal edilmezse otomatik yenilenir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Active user card ─────────────────────────────────────────────────────────

  Widget _buildActiveCard() {
    final activePlan = normalizePremiumPlanId(_activePlanId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7B3E).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFF7B3E).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7B3E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFFFF7B3E),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Premium Aktif',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7B3E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: const Color(0xFFFF7B3E).withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  activePlan == 'yearly' ? 'Yıllık' : 'Aylık',
                  style: const TextStyle(
                    color: Color(0xFFFF7B3E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _buildActiveSubscriptionText(),
            style: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
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
                foregroundColor: const Color(0xFFFF7B3E),
                side: const BorderSide(color: Color(0xFFFF7B3E), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buildActiveSubscriptionText() {
    final planLabel = switch (normalizePremiumPlanId(_activePlanId)) {
      'monthly' => 'Aylık plan aktif.',
      'yearly' => 'Yıllık plan aktif.',
      _ => 'Premium plan aktif.',
    };
    final expiryText = _premiumExpiresAt == null
        ? ''
        : ' Bitiş: ${_premiumExpiresAt!.day.toString().padLeft(2, '0')}/'
              '${_premiumExpiresAt!.month.toString().padLeft(2, '0')}/'
              '${_premiumExpiresAt!.year}.';
    if (_cancelAtPeriodEnd) {
      return '$planLabel Otomatik yenileme kapatıldı. '
          'Premium erişimin dönem sonuna kadar devam edecek.$expiryText';
    }
    if (_canCancel) {
      return '$planLabel Dilersen otomatik yenilemeyi kapatabilirsin; '
          'premium erişimin dönem sonuna kadar sürer.$expiryText';
    }
    return '$planLabel$expiryText';
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

/// Zafer dalı (laurel branch) dekorasyon widget'ı
class _LaurelBranch extends StatelessWidget {
  const _LaurelBranch({required this.flipped});
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    // Yaprak: oval, açılı konumlandırılmış
    Widget leaf(
      double x,
      double y,
      double angleDeg,
      double width,
      double height,
    ) {
      return Positioned(
        left: x,
        top: y,
        child: Transform.rotate(
          angle: angleDeg * 3.14159 / 180,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: const Color(0xFFFF7B3E).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      );
    }

    // Sol dal (flipped=false): yapraklar soldan sağa açılır
    // Sağ dal (flipped=true): ayna görüntüsü
    final branch = SizedBox(
      width: 48,
      height: 88,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          leaf(18, 2, -55, 22, 9),
          leaf(10, 18, -38, 24, 9),
          leaf(6, 36, -20, 26, 9),
          leaf(8, 54, -4, 24, 9),
          leaf(14, 70, 12, 22, 9),
        ],
      ),
    );

    if (!flipped) return branch;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
      child: branch,
    );
  }
}

/// Highlight card data model

/// Feature row (icon + title + subtitle)
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFFA1A1AA),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Legal link (light theme)
class _LightLegalLink extends StatelessWidget {
  const _LightLegalLink({required this.label, required this.isPrivacy});
  final String label;
  final bool isPrivacy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LegalScreen(
            initialTab: isPrivacy ? LegalTab.privacy : LegalTab.terms,
          ),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFA1A1AA),
          fontSize: 13,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: Color(0xFF52525B),
        ),
      ),
    );
  }
}

/// Success sheet (premium activated) — unchanged logic, new visual style
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
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFF7B3E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFFFF7B3E)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
