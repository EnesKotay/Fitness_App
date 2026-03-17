import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../features/nutrition/ai_scan/presentation/pages/meal_vision_scan_page.dart';
import '../../../features/nutrition/domain/entities/meal_type.dart' show MealType;
import '../../../features/nutrition/presentation/pages/nutrition_trends_page.dart';
import '../../../features/nutrition/presentation/pages/smart_grocery_list_page.dart';
import '../providers/auth_provider.dart';
import 'premium_screen.dart';

// ─── Renkler ──────────────────────────────────────────────────────────────────
const Color _gold = Color(0xFFD97706);
const Color _goldLight = Color(0xFFFBBF24);
const Color _bg = Color(0xFF07080B);

// ─── Ana Ekran ────────────────────────────────────────────────────────────────

class PremiumHubScreen extends StatefulWidget {
  const PremiumHubScreen({super.key});

  @override
  State<PremiumHubScreen> createState() => _PremiumHubScreenState();
}

class _PremiumHubScreenState extends State<PremiumHubScreen> {
  bool _cancelLoading = false;

  Future<void> _cancelMembership() async {
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
          'Otomatik yenileme kapatılacak. Premium erişimin mevcut dönem sonuna kadar devam eder.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Evet, İptal Et',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _cancelLoading = true);
    try {
      await ApiClient().post(ApiConstants.downgradePremium);
      if (mounted) {
        // AuthProvider'ı güncelle
        await context.read<AuthProvider>().checkAuthStatus();
        _showSnack('Üyelik iptali planlandı. Dönem sonuna kadar erişimin devam eder.', isError: false);
      }
    } catch (_) {
      if (mounted) _showSnack('İptal işlemi başarısız oldu. Lütfen tekrar dene.', isError: true);
    } finally {
      if (mounted) setState(() => _cancelLoading = false);
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF2D6A4F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isPremium = user?.premiumTier == 'premium';
    final expiresAt = user?.premiumExpiresAt;
    final plan = user?.premiumPlan;
    final cancelAtEnd = user?.premiumCancelAtPeriodEnd == true;
    final isMonthly = plan == 'monthly';

    final planTotalDays = plan == 'yearly' ? 365 : 30;
    final daysLeft = expiresAt != null
        ? expiresAt.difference(DateTime.now()).inDays.clamp(0, planTotalDays)
        : 0;

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.workspace_premium_rounded, color: _goldLight, size: 18),
            const SizedBox(width: 6),
            const Text(
              'PRO Menü',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Positioned(
            top: -80, left: -60,
            child: _GlowOrb(color: _gold.withValues(alpha: 0.18), size: 280),
          ),
          Positioned(
            bottom: 80, right: -80,
            child: _GlowOrb(color: const Color(0xFF7C3AED).withValues(alpha: 0.13), size: 240),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Üyelik Kartı (Yönet) ───────────────────────────
                        if (isPremium) ...[
                          _MembershipCard(
                            plan: plan,
                            expiresAt: expiresAt,
                            daysLeft: daysLeft,
                            cancelAtEnd: cancelAtEnd,
                            isMonthly: isMonthly,
                            cancelLoading: _cancelLoading,
                            onCancel: _cancelMembership,
                            onUpgrade: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const PremiumScreen()),
                              );
                            },
                          ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.04),
                          const SizedBox(height: 28),
                        ] else ...[
                          _buildFreeHeader(context),
                          const SizedBox(height: 24),
                        ],

                        // ── AI Araçları ────────────────────────────────────
                        _SectionTitle(
                          label: 'AI Araçları',
                          icon: Icons.auto_awesome_rounded,
                          color: const Color(0xFFFFB74D),
                        ),
                        const SizedBox(height: 12),
                        _AiCard(
                          icon: Icons.smart_toy_rounded,
                          label: 'AI Koç',
                          sublabel: 'Claude ile kişisel koçluk',
                          description: 'Antrenman, beslenme ve motivasyon hakkında sınırsız soru sor.',
                          accentColor: const Color(0xFFFFB74D),
                          tag: 'CLAUDE',
                          locked: !isPremium,
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.pushNamed(context, AppRoutes.aiCoach);
                          },
                        ).animate().fadeIn(delay: 60.ms).slideY(begin: 0.08),
                        const SizedBox(height: 12),
                        _AiCard(
                          icon: Icons.camera_alt_rounded,
                          label: 'Yemek Fotoğrafı Analizi',
                          sublabel: 'Fotoğraftan kalori & makro',
                          description: 'Yemeğin fotoğrafını çek, AI anında besin değerlerini tespit etsin.',
                          accentColor: const Color(0xFFB388FF),
                          tag: 'VİZYON AI',
                          locked: !isPremium,
                          onTap: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MealVisionScanPage(initialMealType: MealType.lunch),
                              ),
                            );
                          },
                        ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.08),
                        const SizedBox(height: 24),

                        // ── Analiz & Planlama ──────────────────────────────
                        _SectionTitle(
                          label: 'Analiz & Planlama',
                          icon: Icons.insights_rounded,
                          color: const Color(0xFF4FC3F7),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SmallCard(
                                icon: Icons.show_chart_rounded,
                                label: 'Beslenme\nTrendleri',
                                accentColor: const Color(0xFF4FC3F7),
                                locked: !isPremium,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const NutritionTrendsPage()),
                                  );
                                },
                              ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.08),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _SmallCard(
                                icon: Icons.shopping_cart_rounded,
                                label: 'Akıllı Alışveriş\nListesi',
                                accentColor: const Color(0xFF69F0AE),
                                locked: !isPremium,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const SmartGroceryListPage()),
                                  );
                                },
                              ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // ── Avantajlar / Upgrade ───────────────────────────
                        if (!isPremium) ...[
                          _SectionTitle(
                            label: 'Premium Avantajlar',
                            icon: Icons.workspace_premium_rounded,
                            color: const Color(0xFFFFD54F),
                          ),
                          const SizedBox(height: 12),
                          _BenefitRow(icon: Icons.bolt_rounded, color: const Color(0xFFFFD54F), title: 'Sınırsız AI Sorgusu', sub: 'Günde 75 Claude isteği'),
                          _BenefitRow(icon: Icons.bar_chart_rounded, color: const Color(0xFF4FC3F7), title: 'Derinlemesine Trend Analizi', sub: 'Haftalık & aylık raporlar'),
                          _BenefitRow(icon: Icons.restaurant_menu_rounded, color: const Color(0xFF69F0AE), title: 'Tarif Önerileri', sub: 'Hedefine göre kişisel menü'),
                          _BenefitRow(icon: Icons.camera_rounded, color: const Color(0xFFB388FF), title: 'Görüntü ile Besin Tarama', sub: 'Etiket, barkod, yemek fotoğrafı'),
                          const SizedBox(height: 20),
                          _UpgradeBanner(
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const PremiumScreen()),
                              );
                            },
                          ).animate().fadeIn(delay: 320.ms),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeHeader(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.name;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gold.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withValues(alpha: 0.1),
                  border: Border.all(color: _gold.withValues(alpha: 0.22)),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: _goldLight, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name != null ? 'Merhaba, $name 👋' : 'PRO Özellikleri Keşfet',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Ücretsiz planda devam ediyorsun.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _FreeStatPill(icon: Icons.smart_toy_rounded, label: 'AI Koç', color: const Color(0xFFFFB74D)),
              const SizedBox(width: 8),
              _FreeStatPill(icon: Icons.camera_alt_rounded, label: 'Besin Tarama', color: const Color(0xFFB388FF)),
              const SizedBox(width: 8),
              _FreeStatPill(icon: Icons.insights_rounded, label: 'Trendler', color: const Color(0xFF4FC3F7)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Bunların hepsi seni bekliyor. Premium\'a geç ve kilidi aç.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

// ─── Üyelik Yönetim Kartı ─────────────────────────────────────────────────────

class _MembershipCard extends StatelessWidget {
  const _MembershipCard({
    required this.plan,
    required this.expiresAt,
    required this.daysLeft,
    required this.cancelAtEnd,
    required this.isMonthly,
    required this.cancelLoading,
    required this.onCancel,
    required this.onUpgrade,
  });

  final String? plan;
  final DateTime? expiresAt;
  final int daysLeft;
  final bool cancelAtEnd;
  final bool isMonthly;
  final bool cancelLoading;
  final VoidCallback onCancel;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final planLabel = plan == 'yearly' ? 'Yıllık Plan' : 'Aylık Plan';
    final planPrice = plan == 'yearly' ? '1.199₺ / yıl' : '149₺ / ay';
    final statusColor = cancelAtEnd ? Colors.orangeAccent : const Color(0xFF69F0AE);
    final statusLabel = cancelAtEnd ? 'İptal Planlandı' : 'Aktif';
    final totalDays = plan == 'yearly' ? 365 : 30;
    final progress = (daysLeft / totalDays).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _gold.withValues(alpha: 0.18),
            const Color(0xFF0E0A04).withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: _gold.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: -5,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık satırı ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_gold.withValues(alpha: 0.45), _gold.withValues(alpha: 0.15)],
                    ),
                    border: Border.all(color: _gold.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.workspace_premium_rounded, color: _goldLight, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Üyeliği Yönet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        '$planLabel · $planPrice',
                        style: TextStyle(
                          color: _goldLight.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Durum chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Ayıraç ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
          ),

          // ── Kalan süre ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kalan Süre',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$daysLeft',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const TextSpan(
                              text: ' gün',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (expiresAt != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${cancelAtEnd ? 'Bitiş' : 'Yenileme'}: ${_fmtDate(expiresAt!)}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Daire grafik
                _DaysArc(progress: progress, daysLeft: daysLeft),
              ],
            ),
          ),

          // ── İlerleme çubuğu ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).round()}% kaldı',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    ),
                    Text(
                      plan == 'yearly' ? '365 günlük dönem' : '30 günlük dönem',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(
                      cancelAtEnd ? Colors.orangeAccent : _goldLight,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── İptal edildi bilgisi ────────────────────────────────────────
          if (cancelAtEnd && expiresAt != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Otomatik yenileme kapalı. Erişimin ${_fmtDate(expiresAt!)} tarihine kadar devam eder.',
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Aksiyon Butonları ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Row(
              children: [
                if (isMonthly && !cancelAtEnd) ...[
                  Expanded(
                    child: _ActionButton(
                      label: 'Yıllıya Geç',
                      icon: Icons.trending_up_rounded,
                      color: _gold,
                      onTap: onUpgrade,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (!cancelAtEnd)
                  Expanded(
                    child: _ActionButton(
                      label: 'İptal Et',
                      icon: Icons.cancel_outlined,
                      color: Colors.redAccent,
                      outlined: true,
                      loading: cancelLoading,
                      enabled: isMonthly,
                      disabledLabel: isMonthly ? null : 'Yıllık kilitli',
                      onTap: isMonthly ? onCancel : null,
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.white38, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'İptal Planlandı',
                            style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ─── Günler Dairesi ───────────────────────────────────────────────────────────

class _DaysArc extends StatelessWidget {
  const _DaysArc({required this.progress, required this.daysLeft});

  final double progress;
  final int daysLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: CustomPaint(
        painter: _ArcPainter(progress: progress),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$daysLeft',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text(
                'gün',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const strokeWidth = 5.0;

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = _goldLight
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => old.progress != progress;
}

// ─── Aksiyon Butonu ───────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.outlined = false,
    this.loading = false,
    this.enabled = true,
    this.disabledLabel,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final bool loading;
  final bool enabled;
  final String? disabledLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = (!enabled && disabledLabel != null) ? disabledLabel! : label;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: outlined
                ? null
                : LinearGradient(
                    colors: [color.withValues(alpha: 0.9), color.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: outlined ? Colors.transparent : null,
            borderRadius: BorderRadius.circular(14),
            border: outlined
                ? Border.all(color: color.withValues(alpha: 0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: outlined ? color : Colors.white,
                  ),
                )
              else
                Icon(icon, size: 16, color: outlined ? color : Colors.white),
              const SizedBox(width: 6),
              Text(
                effectiveLabel,
                style: TextStyle(
                  color: outlined ? color : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Free Stat Pill ───────────────────────────────────────────────────────────

class _FreeStatPill extends StatelessWidget {
  const _FreeStatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.withValues(alpha: 0.85)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Title ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

// ─── AI Feature Card ──────────────────────────────────────────────────────────

class _AiCard extends StatelessWidget {
  const _AiCard({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.description,
    required this.accentColor,
    required this.tag,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final String description;
  final Color accentColor;
  final String tag;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked
          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()))
          : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: locked ? 0.05 : 0.13),
              Colors.white.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withValues(alpha: locked ? 0.08 : 0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: locked ? 0.08 : 0.28),
                    accentColor.withValues(alpha: locked ? 0.03 : 0.08),
                  ],
                ),
                border: Border.all(color: accentColor.withValues(alpha: locked ? 0.1 : 0.32)),
              ),
              child: Icon(icon, color: locked ? Colors.white24 : Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: locked ? Colors.white38 : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: locked ? 0.05 : 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: accentColor.withValues(alpha: locked ? 0.08 : 0.28)),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            color: locked ? Colors.white24 : accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      color: locked ? Colors.white24 : accentColor.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: locked ? 0.18 : 0.55),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              locked ? Icons.lock_rounded : Icons.chevron_right_rounded,
              color: locked ? Colors.white.withValues(alpha: 0.18) : accentColor.withValues(alpha: 0.65),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Small Feature Card ───────────────────────────────────────────────────────

class _SmallCard extends StatelessWidget {
  const _SmallCard({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accentColor;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: locked
          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PremiumScreen()))
          : onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accentColor.withValues(alpha: locked ? 0.04 : 0.11),
              Colors.white.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: locked ? 0.07 : 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(11),
                    color: accentColor.withValues(alpha: locked ? 0.05 : 0.18),
                    border: Border.all(color: accentColor.withValues(alpha: locked ? 0.07 : 0.25)),
                  ),
                  child: Icon(icon, color: locked ? Colors.white24 : Colors.white, size: 18),
                ),
                Icon(
                  locked ? Icons.lock_rounded : Icons.arrow_forward_rounded,
                  color: locked ? Colors.white.withValues(alpha: 0.15) : accentColor.withValues(alpha: 0.65),
                  size: 15,
                ),
              ],
            ),
            const SizedBox(height: 11),
            Text(
              label,
              style: TextStyle(
                color: locked ? Colors.white38 : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Benefit Row ─────────────────────────────────────────────────────────────

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.icon, required this.color, required this.title, required this.sub});

  final IconData icon;
  final Color color;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 13),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.42), fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Upgrade Banner ───────────────────────────────────────────────────────────

class _UpgradeBanner extends StatelessWidget {
  const _UpgradeBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFBBF24), Color(0xFFD97706), Color(0xFFFF8F00)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.38),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_open_rounded, color: Color(0xFF1A0F00), size: 20),
            SizedBox(width: 10),
            Text(
              "Premium'u Aç — 149₺ / ay",
              style: TextStyle(
                color: Color(0xFF1A0F00),
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glow Orb ─────────────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: const SizedBox(),
      ),
    );
  }
}
