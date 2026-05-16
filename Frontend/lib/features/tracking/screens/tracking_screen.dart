import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tracking_provider.dart';
import '../widgets/measurements_view.dart';
import '../widgets/body_composition_card.dart';
import '../widgets/add_measurement_sheet.dart';
import '../widgets/ai_coach_insight_sheet.dart';
import '../widgets/measurement_trend_chart.dart';
import '../widgets/weight_tracking_view.dart';
import '../../../core/models/body_measurement.dart';
import '../../../core/services/page_guide_service.dart';
import '../../../core/widgets/page_guide_overlay.dart';
import '../../../core/widgets/page_guide_button.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final ValueNotifier<int> _selectedTabIndex = ValueNotifier<int>(0);

  @override
  void dispose() {
    _selectedTabIndex.dispose();
    super.dispose();
  }

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '📊',
      title: 'Kilo Gelişim Grafiği',
      description:
          'Merkezdeki parlak grafik kilonun zaman içindeki değişimini gösterir:\n\n'
          '• Üstteki butonlarla grafiği 7 Gün, 1 Ay, 3 Ay veya Tümü olarak filtrele\n'
          '• Grafikteki noktalara dokunarak o günkü spesifik kilonu gör\n'
          '• Hedef kilon grafikte kesik çizgi ile gösterilir',
      tip:
          'Grafik çizgisi düz gidiyorsa istikrarı, aşağı iniyorsa yağ kaybını, çıkıyorsa hacim/bulk dönemini ifade eder.',
    ),
    GuideStep(
      emoji: '➕',
      title: 'Kilo Kaydı Ekleme',
      description:
          'Sağ üstteki "+" butonuna dokunarak güncel kilonu sisteme girebilirsin. Kaydettiğin değer grafiğe yansır ve analizlerin güncellenir.',
      tip:
          'Kilo için günlük baskı yok; 3-4 haftada bir, benzer saat ve koşulda tartılmak daha sakin takip sağlar.',
    ),
    GuideStep(
      emoji: '🤖',
      title: 'Gelişmiş AI Analizleri',
      description:
          'AI tabanlı kilo analizi için "Kilo Yorumu Al" butonuna dokunabilirsin:\n\n'
          '• Hız Koçu: Kilo verme/alma hızının sağlıklı aralıkta olup olmadığını söyler\n'
          '• Hedef Tahmini: Mevcut hızınla hedefine ne zaman ulaşacağını hesaplar\n'
          '• Haftalık Değişim: Son 7 gündeki net değişimini (kg) gösterir',
      tip:
          'Eğer Hız Koçu kırmızı veya sarı uyarı veriyorsa, diyetini hedefine göre biraz daha yavaş ve sürdürülebilir hale getir.',
    ),
    GuideStep(
      emoji: '🔥',
      title: 'İstikrar (Consistency) Haritası',
      description:
          'Sayfanın altındaki yeşil kareler senin istikrarını gösterir. Girdiğin her kilo kaydı, antrenman veya başarılı öğün takibi o günün karesini yeşile boyar.\n\n'
          'Ne kadar koyu yeşil, o kadar istikrarlı bir gün demektir.',
      tip:
          'Haftada en az 4 koyu yeşil kare elde etmeyi hedefle. Bu haritayı dolu tutmak en büyük motivasyon kaynağındır!',
    ),
    GuideStep(
      emoji: '📏',
      title: 'Vücut Ölçüleri Sekmesi',
      description:
          'Sayfanın en üstündeki menüden "Vücut Ölçüleri" sekmesine geçebilirsin:\n\n'
          '• Bel, kalça, göğüs, omuz ve kol ölçülerini mezura ile ölçüp kaydet\n'
          '• Yağ oranındaki (Vücut Kompozisyonu) değişimi tahmini olarak takip et\n'
          '• Sadece tartıdaki rakama bağımlı kalma',
      tip:
          'Özellikle ağırlık antrenmanı yapıyorsan kilon aynı kalırken belin incelebilir. Gerçek değişimi görmek için her ay ölçü al.',
    ),
    GuideStep(
      emoji: '📸',
      title: 'Gelişimini Paylaş',
      description:
          'Kilo grafiğinin yanındaki Paylaş butonuna basarak, mevcut kilonu ve hedefe ne kadar yaklaştığını gösteren özel tasarım bir "İlerleme Kartı" oluşturup arkadaşlarınla paylaşabilirsin.',
      tip: 'Başarılarını sosyal medyada paylaşmak motivasyonunu canlı tutar!',
    ),
  ];

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('tracking')) return;
    await PageGuideService.markGuideSeen('tracking');
    if (mounted) await _showGuide();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final dietProvider = Provider.of<DietProvider>(context, listen: false);
      final weightProvider = Provider.of<WeightProvider>(
        context,
        listen: false,
      );
      if (dietProvider.profile == null && !dietProvider.loading) {
        dietProvider.init();
      }
      if (weightProvider.entries.isEmpty && !weightProvider.isLoading) {
        weightProvider.loadEntries();
      }
      final authId = context.read<AuthProvider>().user?.id;
      if (authId != null && authId > 0) {
        final trackingProvider = context.read<TrackingProvider>();
        if (trackingProvider.bodyMeasurements.isEmpty &&
            !trackingProvider.isLoading) {
          trackingProvider.loadBodyMeasurements(authId);
        }
        final workoutProvider = context.read<WorkoutProvider>();
        if (workoutProvider.workouts.isEmpty && !workoutProvider.isLoading) {
          unawaited(workoutProvider.loadWorkouts(authId));
        }
      } else {
        context.read<TrackingProvider>().reset();
      }
      await _checkFirstVisitGuide();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: AppGradientBackground(
        imagePath: 'assets/images/tracking_bg_v2.jpg',
        lightOverlay: true,
        child: _buildBody(context),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text(
        'İlerleme Takibi',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Center(child: PageGuideButton(onTap: _showGuide)),
        ),
        Selector<WeightProvider, WeightEntry?>(
          selector: (_, p) => p.latestEntry,
          builder: (_, latest, child) {
            if (latest == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${latest.weightKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        IconButton(
          onPressed: () => WeightTrackingView.showEntrySheet(context),
          icon: const Icon(
            Icons.add_rounded,
            color: AppColors.primaryLight,
            size: 26,
          ),
          tooltip: 'Kilo ekle',
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: _selectedTabIndex,
            builder: (context, index, child) => Row(
              children: [
                Expanded(child: _buildTabButton('Kilo Takibi', 0, index)),
                Expanded(child: _buildTabButton('Vücut Ölçüleri', 1, index)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedTabIndex,
      builder: (context, index, child) {
        if (index == 1) {
          final p = context.watch<TrackingProvider>();
          if (p.isLoading && p.bodyMeasurements.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (p.bodyMeasurements.isEmpty) {
            return _buildMeasurementsEmptyState(context);
          }
          return RefreshIndicator(
            onRefresh: () async {
              final authId = context.read<AuthProvider>().user?.id;
              if (authId == null || authId <= 0) {
                context.read<TrackingProvider>().reset();
                return;
              }
              await context
                  .read<TrackingProvider>()
                  .loadBodyMeasurements(authId);
            },
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(child: MeasurementTrendChart()),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _buildMeasurementsAiAnalysisButton(context),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: _buildMeasurementsSummaryCard(context),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                const SliverToBoxAdapter(child: MeasurementsView()),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Consumer2<TrackingProvider, DietProvider>(
                      builder: (context, tracking, diet, _) =>
                          BodyCompositionCard(
                            profile: diet.profile,
                            measurements: tracking.bodyMeasurements,
                          ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          );
        }

        return const WeightTrackingView();
      },
    );
  }

  Widget _buildFAB(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedTabIndex,
      builder: (context, index, child) {
        if (index == 1) {
          return FloatingActionButton.extended(
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddMeasurementSheet(),
            ),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: const Text(
              'Ölçü Ekle',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return Selector<WeightProvider, bool>(
          selector: (_, p) => p.entries.isEmpty,
          builder: (_, isEmpty, child) {
            if (isEmpty) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              onPressed: () => WeightTrackingView.showEntrySheet(context),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Kilo Ekle',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Tab button ─────────────────────────────────────────────────────────────

  Widget _buildTabButton(String title, int tabIndex, int currentIndex) {
    final isSelected = tabIndex == currentIndex;
    return GestureDetector(
      onTap: () => _selectedTabIndex.value = tabIndex,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.80),
                  ],
                )
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
            letterSpacing: isSelected ? -0.2 : 0,
          ),
        ),
      ),
    );
  }

  // ── Measurements tab UI ───────────────────────────────────────────────────

  Widget _buildMeasurementsEmptyState(BuildContext context) {
    final diet = context.read<DietProvider>();
    final tracking = context.read<TrackingProvider>();

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.straighten_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Vücut ölçülerini kaydet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Göğüs, bel, kalça ve kol ölçülerini düzenli kaydetmek faydalı. Ama yağ oranı tahmini için önce ölçü girmen artık gerekmiyor.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 28),
            _buildMeasurementHint(
              Icons.trending_down_rounded,
              'Bölgesel incelmeyi takip et',
            ),
            const SizedBox(height: 10),
            _buildMeasurementHint(
              Icons.fitness_center_rounded,
              'Kas gelişimini haftalık izle',
            ),
            const SizedBox(height: 10),
            _buildMeasurementHint(
              Icons.monitor_weight_rounded,
              'Yağ oranını kilo, boy ve yaş ile hemen hesapla',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton.primary(
                text: 'İlk Ölçülerimi Ekle',
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddMeasurementSheet(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            BodyCompositionCard(
              profile: diet.profile,
              measurements: tracking.bodyMeasurements,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementHint(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryLight, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMeasurementsSummaryCard(BuildContext context) {
    return Selector<TrackingProvider, List<BodyMeasurement>>(
      selector: (_, p) => p.bodyMeasurements,
      builder: (context, measurements, _) {
        final count = measurements.length;
        if (count == 0) return const SizedBox.shrink();
        final lastDate = measurements
            .map((m) => m.date)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        final lastStr = DateFormat('d MMMM yyyy', 'tr_TR').format(lastDate);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.straighten_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$count ölçüm kaydı',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Son güncelleme: $lastStr',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMeasurementsAiAnalysisButton(BuildContext context) {
    return InkWell(
      onTap: () {
        final tp = context.read<TrackingProvider>();
        final measurements = tp.bodyMeasurements;

        final contextBuffer = StringBuffer();
        if (measurements.length >= 2) {
          final m1 = measurements[0];
          final m2 = measurements[1];
          contextBuffer.write('Son ölçümüme göre değişimlerim: ');
          if (m1.waist != null && m2.waist != null) {
            final diff = m1.waist! - m2.waist!;
            contextBuffer.write(
              'Bel: ${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)} cm. ',
            );
          }
          if (m1.chest != null && m2.chest != null) {
            final diff = m1.chest! - m2.chest!;
            contextBuffer.write(
              'Göğüs: ${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)} cm. ',
            );
          }
          if (m1.hips != null && m2.hips != null) {
            final diff = m1.hips! - m2.hips!;
            contextBuffer.write(
              'Kalça: ${diff > 0 ? "+" : ""}${diff.toStringAsFixed(1)} cm. ',
            );
          }
        } else if (measurements.isNotEmpty) {
          final m = measurements.first;
          contextBuffer.write('Güncel ölçülerim: ');
          if (m.waist != null) contextBuffer.write('Bel: ${m.waist} cm. ');
          if (m.chest != null) contextBuffer.write('Göğüs: ${m.chest} cm. ');
        }

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AiCoachInsightSheet(
            goal: 'Kas gelişimi ve bölgesel incelme',
            question:
                '${contextBuffer}Bu mezura değişimlerime göre gidişatımı puanlayıp bana kas gelişimi/incelme hakkında odaklanmam gereken kritik 3 maddeyi söyler misin?',
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primaryDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 20),
            SizedBox(width: 8),
            Text(
              'Ölçüm Yorumu Al',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
