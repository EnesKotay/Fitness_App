import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_gradient_background.dart';
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
import '../widgets/progress_photo_card.dart';
import '../widgets/weekly_summary_card.dart';
import '../widgets/workout_history_card.dart';
import '../widgets/body_silhouette_card.dart';
import '../widgets/recovery_score_card.dart';

import '../widgets/measurement_comparison_sheet.dart';
import '../widgets/muscle_radar_chart.dart';
import '../widgets/volume_trend_chart.dart';
import '../widgets/difficulty_pie_chart.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/models/body_measurement.dart';
import '../../../core/models/workout.dart';
import '../../../core/services/page_guide_service.dart';
import '../../../core/widgets/page_guide_overlay.dart';
import '../../../core/widgets/page_guide_button.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  /// Dışarıdan (örn. Dashboard) belirli bir sub-tab'a atlamak için kullanılır.
  /// Değer set edildiğinde TrackingScreen o tab'a geçer ve değeri sıfırlar.
  static final pendingTab = ValueNotifier<int?>(null);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final ValueNotifier<int> _selectedTabIndex = ValueNotifier<int>(0);
  late final PageController _pageController;

  void _onPendingTab() {
    final tab = TrackingScreen.pendingTab.value;
    if (tab == null) return;
    TrackingScreen.pendingTab.value = null;
    if (!mounted) return;
    _selectedTabIndex.value = tab;
    _pageController.jumpToPage(tab);
  }

  @override
  void dispose() {
    TrackingScreen.pendingTab.removeListener(_onPendingTab);
    _pageController.dispose();
    _selectedTabIndex.dispose();
    super.dispose();
  }

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '📊',
      title: '3 Sekme, 3 Boyut',
      description:
          'İlerleme Takibi sayfasında üstteki sekme menüsüyle üç farklı bakış açısına geçebilirsin:\n\n'
          '• Kilo — grafik, AI analizi ve toparlanma skoru\n'
          '• Ölçüler — santimetre bazlı vücut haritası\n'
          '• Performans — antrenman güç ve hacim grafikleri',
      tip:
          'Sadece tartı rakamına bağımlı kalma. Üç sekmeyi birlikte okumak gerçek değişimi gösterir.',
    ),
    GuideStep(
      emoji: '❤️',
      title: 'Toparlanma Skoru',
      description:
          'Kilo sekmesinde aşağı kaydırınca Toparlanma Skoru kartını görürsün. Bu skor 3 faktörü birleştirir:\n\n'
          '• 💪 Kas toparlanması — son antrenmanlarına göre\n'
          '• 🌙 Uyku süresi — dün gece uyuduğun saat\n'
          '• 💧 Su tüketimi — gün içinde içtiğin miktar\n\n'
          'Karta dokunarak her faktörün skoru ne kadar etkilediğini görebilirsin.',
      tip:
          'Uyku girilmemişse kart bunu turuncu uyarı ile belirtir. Dün gecenin uyku süresini slider\'dan gir, skoru anında güncellenir.',
    ),
    GuideStep(
      emoji: '📈',
      title: 'Kilo Gelişim Grafiği',
      description:
          'Merkezdeki grafik kilonun zaman içindeki değişimini gösterir:\n\n'
          '• 7 Gün / 1 Ay / 3 Ay / Tümü butonlarıyla filtrele\n'
          '• Grafikteki noktalara dokunarak o günkü kilonu gör\n'
          '• Hedef kilon kesik çizgi ile işaretlenir',
      tip:
          'Çizgi düz gidiyorsa istikrar, aşağıya iniyorsa yağ kaybı, yukarı çıkıyorsa hacim dönemi anlamına gelir.',
    ),
    GuideStep(
      emoji: '🤖',
      title: 'AI Kilo Analizi',
      description:
          '"Kilo Yorumu Al" butonuna dokunarak kişisel analiz alabilirsin:\n\n'
          '• Hız Koçu: Verme/alma hızının sağlıklı aralıkta mı olduğunu söyler\n'
          '• Hedef Tahmini: Mevcut hızınla hedefe ne zaman ulaşacağını hesaplar\n'
          '• Haftalık Değişim: Son 7 günlük net değişim (kg)',
      tip:
          'Hız Koçu kırmızı veya sarı uyarı veriyorsa diyetini biraz daha sürdürülebilir hale getir.',
    ),
    GuideStep(
      emoji: '📏',
      title: 'Ölçüler Sekmesi',
      description:
          '"Ölçüler" sekmesine geçerek vücut haritanı oluşturabilirsin:\n\n'
          '• Bel, kalça, göğüs, omuz ve kol ölçülerini kaydet\n'
          '• Her bölge için trend grafiği\n'
          '• "Görsel analizler" kartını aç: ilerleme fotoğrafı, vücut silüeti ve yağ oranı tahmini',
      tip:
          'Ağırlık antrenmanı yapıyorsan kilon aynı kalırken belin incilebilir. Gerçek değişimi görmek için her ay ölçü al.',
    ),
    GuideStep(
      emoji: '⚡',
      title: 'Performans Sekmesi',
      description:
          '"Performans" sekmesinde antrenmanlarının istatistiksel analizi görünür:\n\n'
          '• Kas Radar Grafiği: Hangi kas gruplarını ne kadar çalıştırdığını gösterir\n'
          '• Hacim Trendi: Haftalık toplam kaldırılan ağırlık değişimi\n'
          '• Zorluk Dağılımı: Hafif/orta/ağır antrenman oranın',
      tip:
          'Radar grafik belirli bir kas grubunu çok az gösteriyorsa antrenman programında dengesizlik var demektir.',
    ),
    GuideStep(
      emoji: '🔥',
      title: 'İstikrar Haritası',
      description:
          'Sayfanın altındaki yeşil kareler tutarlılığını gösterir. Her kilo kaydı, antrenman ve başarılı öğün takibi o günü yeşile boyar.\n\n'
          'Ne kadar koyu yeşil, o kadar istikrarlı bir gün demektir.',
      tip:
          'Haftada en az 4 koyu yeşil kare hedefle. Bu haritayı dolu tutmak en büyük motivasyon kaynağındır!',
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
    _pageController = PageController(initialPage: _selectedTabIndex.value);
    TrackingScreen.pendingTab.addListener(_onPendingTab);
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
                Expanded(child: _buildTabButton('Kilo', 0, index)),
                Expanded(child: _buildTabButton('Ölçüler', 1, index)),
                Expanded(child: _buildTabButton('Performans', 2, index)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return PageView(
      controller: _pageController,
      onPageChanged: (pageIndex) {
        _selectedTabIndex.value = pageIndex;
      },
      physics: const BouncingScrollPhysics(),
      children: [
        const WeightTrackingView(),
        _buildMeasurementsTabBody(context),
        const _PerformanceTab(),
      ],
    );
  }

  Widget _buildMeasurementsTabBody(BuildContext context) {
    final p = context.watch<TrackingProvider>();
    if (p.isLoading && p.bodyMeasurements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (p.bodyMeasurements.isEmpty) {
      return _buildMeasurementsEmptyState(context);
    }

    // Ölçüm hatırlatıcı banner
    final lastMeasurementDate = p.bodyMeasurements
        .map((m) => m.date)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final daysSinceMeasurement = DateTime.now()
        .difference(lastMeasurementDate)
        .inDays;
    final showReminderBanner = daysSinceMeasurement >= 14;

    return RefreshIndicator(
      onRefresh: () async {
        final authId = context.read<AuthProvider>().user?.id;
        if (authId == null || authId <= 0) {
          context.read<TrackingProvider>().reset();
          return;
        }
        await context.read<TrackingProvider>().loadBodyMeasurements(authId);
      },
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // Ölçüm hatırlatıcı banner
          if (showReminderBanner)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: _MeasurementReminderBanner(
                  daysSince: daysSinceMeasurement,
                ),
              ),
            ),
          if (showReminderBanner)
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(child: _buildMeasurementsSummaryCard(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(child: _buildMeasurementsAiAnalysisButton(context)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCompareButton(context)),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: MeasurementTrendChart()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          const SliverToBoxAdapter(child: MeasurementsView()),
          SliverToBoxAdapter(child: _buildMeasurementDetailsPanel(context)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _selectedTabIndex,
      builder: (context, index, child) {
        if (index == 1) {
          return FloatingActionButton.extended(
            heroTag: 'tracking_fab_measurement',
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

        if (index == 2) return const SizedBox.shrink();

        return Selector<WeightProvider, bool>(
          selector: (_, p) => p.entries.isEmpty,
          builder: (_, isEmpty, child) {
            if (isEmpty) return const SizedBox.shrink();
            return FloatingActionButton.extended(
              heroTag: 'tracking_fab_weight',
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

  Widget _buildMeasurementDetailsPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showVisualAnalysisSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_rounded,
                    color: AppColors.primaryLight,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Görsel analizler',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Fotoğraf, silüet ve vücut kompozisyonu',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.42),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primaryLight,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVisualAnalysisSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.94,
        builder: (sheetContext, controller) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Görsel analizler',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              const ProgressPhotoCard(),
              const SizedBox(height: 14),
              Consumer<TrackingProvider>(
                builder: (context, tracking, _) => BodySilhouetteCard(
                  measurement: tracking.bodyMeasurements.isNotEmpty
                      ? tracking.bodyMeasurements.first
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              Consumer2<TrackingProvider, DietProvider>(
                builder: (context, tracking, diet, _) => BodyCompositionCard(
                  profile: diet.profile,
                  measurements: tracking.bodyMeasurements,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tab button ─────────────────────────────────────────────────────────────

  Widget _buildTabButton(String title, int tabIndex, int currentIndex) {
    final isSelected = tabIndex == currentIndex;
    return GestureDetector(
      onTap: () {
        _selectedTabIndex.value = tabIndex;
        _pageController.animateToPage(
          tabIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
        );
      },
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
        padding: const EdgeInsets.fromLTRB(20, 40, 20, 120),
        child: Column(
          children: [
            // ── Hero icon with pulsing rings ────────────────────────────
            _PulsingHeroIcon(),
            const SizedBox(height: 28),

            const Text(
              'Vücut ölçülerini kaydet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Sadece tartıdaki rakama bağımlı kalma.\nGöğüs, bel, kalça ve kol ölçülerini kaydet,\ngercek değişimi görmek için.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 14.5,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 32),

            // ── Feature cards ────────────────────────────────────────────
            _FeatureRow(
              icon: Icons.trending_down_rounded,
              color: const Color(0xFF48BB78),
              title: 'Bölgesel İncelme',
              subtitle: 'Kilo aynı kalırken belin incelebilir',
            ),
            const SizedBox(height: 10),
            _FeatureRow(
              icon: Icons.fitness_center_rounded,
              color: const Color(0xFF64D2FF),
              title: 'Kas Gelişimi',
              subtitle: 'Haftalık takip ile ilerlemeyi gözlemle',
            ),
            const SizedBox(height: 10),
            _FeatureRow(
              icon: Icons.show_chart_rounded,
              color: const Color(0xFFFFA56E),
              title: 'Trend Grafiği',
              subtitle: 'Her bölge için görsel zaman serisi',
            ),
            const SizedBox(height: 32),

            // ── CTA button ───────────────────────────────────────────────
            GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const AddMeasurementSheet(),
              ),
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.40),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'İlk Ölçülerimi Ekle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            BodyCompositionCard(
              profile: diet.profile,
              measurements: tracking.bodyMeasurements,
            ),
          ],
        ),
      ),
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
        final sorted = [...measurements]
          ..sort((a, b) => b.date.compareTo(a.date));
        final latest = sorted.first;
        final previous = sorted.length > 1 ? sorted[1] : null;
        final deltas = previous == null
            ? const <_MeasurementDelta>[]
            : [
                _MeasurementDelta.from('Bel', latest.waist, previous.waist),
                _MeasurementDelta.from('Göğüs', latest.chest, previous.chest),
                _MeasurementDelta.from('Kalça', latest.hips, previous.hips),
                _MeasurementDelta.from(
                  'Kol',
                  _avgNullable(latest.leftArm, latest.rightArm),
                  _avgNullable(previous.leftArm, previous.rightArm),
                ),
              ].whereType<_MeasurementDelta>().toList(growable: false);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                if (deltas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: deltas
                        .map((delta) => _MeasurementDeltaChip(delta: delta))
                        .toList(),
                  ),
                ],
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
          builder: (_) {
            const suffix =
                'Mezura değişimlerime göre kas gelişimi ve incelme için 3 kritik madde söyle.';
            final ctx = contextBuffer.toString();
            final maxCtx = 480 - suffix.length;
            final safeCtx = ctx.length > maxCtx
                ? ctx.substring(0, maxCtx)
                : ctx;
            return AiCoachInsightSheet(
              goal: 'Kas gelişimi ve bölgesel incelme',
              question: '$safeCtx$suffix',
            );
          },
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
              'Yorum Al',
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

  static double? _avgNullable(double? a, double? b) {
    final values = [a, b].whereType<double>().toList();
    if (values.isEmpty) return null;
    return values.reduce((x, y) => x + y) / values.length;
  }

  Widget _buildCompareButton(BuildContext context) {
    return InkWell(
      onTap: () => showMeasurementComparisonSheet(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.compare_arrows_rounded,
              color: AppColors.primaryLight,
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Karşılaştır',
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

class _MeasurementDelta {
  final String label;
  final double value;

  const _MeasurementDelta({required this.label, required this.value});

  static _MeasurementDelta? from(
    String label,
    double? latest,
    double? previous,
  ) {
    if (latest == null || previous == null) return null;
    final diff = latest - previous;
    if (diff.abs() < 0.05) return null;
    return _MeasurementDelta(label: label, value: diff);
  }
}

class _MeasurementDeltaChip extends StatelessWidget {
  final _MeasurementDelta delta;

  const _MeasurementDeltaChip({required this.delta});

  @override
  Widget build(BuildContext context) {
    final isUp = delta.value > 0;
    final color = isUp ? const Color(0xFFFFA56E) : AppColors.primaryLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 5),
          Text(
            '${delta.label} ${isUp ? '+' : ''}${delta.value.toStringAsFixed(1)} cm',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Performans Sekmesi ───────────────────────────────────────────────────────

// ── Pulsing Hero Icon ────────────────────────────────────────────────────────

class _PulsingHeroIcon extends StatefulWidget {
  const _PulsingHeroIcon();

  @override
  State<_PulsingHeroIcon> createState() => _PulsingHeroIconState();
}

class _PulsingHeroIconState extends State<_PulsingHeroIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.15,
      end: 0.35,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, _) => Transform.scale(
              scale: _scale.value,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: _opacity.value),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          // Inner container
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.25),
                  AppColors.primary.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.40),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.straighten_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature Row ───────────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.08), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
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
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: color.withValues(alpha: 0.4),
            size: 13,
          ),
        ],
      ),
    );
  }
}

// ─── Performans Sekmesi ───────────────────────────────────────────────────────

class _PerformanceTab extends StatefulWidget {
  const _PerformanceTab();

  @override
  State<_PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<_PerformanceTab> {
  int _selectedSection = 0;

  static const _accentBlue = Color(0xFF64D2FF);
  static const _accentOrange = Color(0xFFFFA56E);
  static const _accentGreen = Color(0xFF30D158);

  double _workoutVolume(Workout workout) {
    final details = workout.setDetails;
    if (details != null && details.isNotEmpty) {
      return details.fold<double>(0, (sum, set) {
        final reps = set.reps ?? workout.reps ?? 0;
        final weight = set.weight ?? workout.weight ?? 0;
        return sum + (reps * weight);
      });
    }
    return (workout.weight ?? 0) * (workout.sets ?? 1) * (workout.reps ?? 1);
  }

  double _weeklyVolume(List<Workout> workouts) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return workouts
        .where((w) => w.workoutDate.isAfter(cutoff))
        .fold(0.0, (sum, w) => sum + _workoutVolume(w));
  }

  double _previousWeekVolume(List<Workout> workouts) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 14));
    final end = now.subtract(const Duration(days: 7));
    return workouts
        .where(
          (w) => w.workoutDate.isAfter(start) && w.workoutDate.isBefore(end),
        )
        .fold(0.0, (sum, w) => sum + _workoutVolume(w));
  }

  int _weeklyWorkoutCount(List<Workout> workouts) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    return workouts.where((w) => w.workoutDate.isAfter(cutoff)).length;
  }

  double _monthlyCaloriesBurned(List<Workout> workouts) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return workouts
        .where((w) => w.workoutDate.isAfter(cutoff))
        .fold(0.0, (sum, w) => sum + (w.caloriesBurned ?? 0));
  }

  int _monthlyWorkoutCount(List<Workout> workouts) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return workouts.where((w) => w.workoutDate.isAfter(cutoff)).length;
  }

  int _previousWeekWorkoutCount(List<Workout> workouts) {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 14));
    final end = now.subtract(const Duration(days: 7));
    return workouts
        .where(
          (w) => w.workoutDate.isAfter(start) && w.workoutDate.isBefore(end),
        )
        .length;
  }

  // Haftanın hangi günlerinde (Pzt=0 ... Paz=6) antrenman var
  Set<int> _activeWeekdays(List<Workout> workouts) {
    final monday = DateTime.now().subtract(
      Duration(days: DateTime.now().weekday - 1),
    );
    final start = DateTime(monday.year, monday.month, monday.day);
    return workouts
        .where((w) => !w.workoutDate.isBefore(start))
        .map((w) => w.workoutDate.weekday - 1)
        .toSet();
  }

  int _prTrend(String exerciseName, List<Workout> workouts) {
    final all =
        workouts
            .where((w) => w.name.toLowerCase() == exerciseName.toLowerCase())
            .toList()
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    if (all.length < 2) return 0;
    final latest = _maxWeightInWorkout(all.first);
    // Compare against first workout that is at least 7 days older to avoid
    // same-day warm-up vs main session noise.
    final cutoff = all.first.workoutDate.subtract(const Duration(days: 7));
    final reference = all
        .skip(1)
        .firstWhere(
          (w) => w.workoutDate.isBefore(cutoff),
          orElse: () => all[1],
        );
    final previous = _maxWeightInWorkout(reference);
    if (latest > previous) return 1;
    if (latest < previous) return -1;
    return 0;
  }

  double _maxWeightInWorkout(Workout workout) {
    final details = workout.setDetails;
    if (details != null && details.isNotEmpty) {
      final setMax = details
          .map((set) => set.weight ?? 0)
          .fold<double>(0, (a, b) => a > b ? a : b);
      if (setMax > 0) return setMax;
    }
    return workout.weight ?? 0;
  }

  int _risingPrCount(
    List<MapEntry<String, double>> prs,
    List<Workout> workouts,
  ) {
    return prs.where((entry) => _prTrend(entry.key, workouts) > 0).length;
  }

  ({String title, String message, IconData icon, Color color})
  _performanceRead({
    required int weeklyCount,
    required double weeklyVolume,
    required double previousVolume,
    required int risingPrs,
  }) {
    if (weeklyCount == 0) {
      return (
        title: 'Bu hafta sinyal yok',
        message:
            'Performans analizi için en az bir antrenman kaydı gir. Kısa bir full-body seans bile trendi başlatır.',
        icon: Icons.play_arrow_rounded,
        color: _accentOrange,
      );
    }
    if (previousVolume > 0 && weeklyVolume > previousVolume * 1.35) {
      return (
        title: 'Yük hızlı artmış',
        message:
            'Hacim geçen haftaya göre belirgin yüksek. Aynı tempoyu sürdürmeden önce uyku, ağrı ve toparlanmayı kontrol et.',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFFD60A),
      );
    }
    if (risingPrs >= 2) {
      return (
        title: 'Güç trendi yukarı',
        message:
            '$risingPrs harekette son kayıt önceki kayıttan iyi. Bir sonraki seans küçük artış veya ekstra tekrar için uygun.',
        icon: Icons.trending_up_rounded,
        color: _accentGreen,
      );
    }
    if (weeklyCount >= 3 && weeklyVolume > 0) {
      return (
        title: 'Ritim iyi, yükü kontrollü büyüt',
        message:
            'Haftalık seans sayın yeterli. Sıradaki adım her harekette tek değişkeni artırmak: ağırlık, tekrar veya set.',
        icon: Icons.speed_rounded,
        color: _accentBlue,
      );
    }
    return (
      title: 'Önce tutarlılık',
      message:
          'Performans artışı için bu hafta 2-3 kayıt hedefle. Aynı hareketleri tekrarlamak trendi okunur hale getirir.',
      icon: Icons.repeat_rounded,
      color: _accentBlue,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, wp, _) {
        final workouts = wp.workouts;
        final prs = wp.personalRecords;
        final weeklyVol = _weeklyVolume(workouts);
        final previousWeeklyVol = _previousWeekVolume(workouts);
        final weeklyCount = _weeklyWorkoutCount(workouts);
        final monthlyKcal = _monthlyCaloriesBurned(workouts);

        final topPRs = prs.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final displayPRs = topPRs.take(8).toList();
        final performanceRead = _performanceRead(
          weeklyCount: weeklyCount,
          weeklyVolume: weeklyVol,
          previousVolume: previousWeeklyVol,
          risingPrs: _risingPrCount(displayPRs, workouts),
        );
        final monthlyCount = _monthlyWorkoutCount(workouts);
        final prevWeekCount = _previousWeekWorkoutCount(workouts);
        final activeWeekdays = _activeWeekdays(workouts);
        final risingPrs = _risingPrCount(displayPRs, workouts);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(child: _buildSectionSwitcher()),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            if (_selectedSection == 0) ...[
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: WeeklySummaryCard()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _PerformanceReadCard(read: performanceRead),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _PerformanceAiButton(
                    weeklyCount: weeklyCount,
                    weeklyVol: weeklyVol,
                    monthlyKcal: monthlyKcal,
                    risingPrs: risingPrs,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _buildStatsOverview(
                    activeWeekdays: activeWeekdays,
                    weeklyCount: weeklyCount,
                    prevWeekCount: prevWeekCount,
                    weeklyVol: weeklyVol,
                    previousWeeklyVol: previousWeeklyVol,
                    monthlyKcal: monthlyKcal,
                    monthlyCount: monthlyCount,
                  ),
                ),
              ),
              Consumer2<WorkoutProvider, DietProvider>(
                builder: (context, wprov, diet, _) {
                  final waterLiters = diet.waterLiters;
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: RecoveryScoreCard(
                        workoutProvider: wprov,
                        waterLiters: waterLiters,
                      ),
                    ),
                  );
                },
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _PeriodizationCard(workouts: workouts),
                ),
              ),
            ] else if (_selectedSection == 1) ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: MuscleRadarChart(workouts: workouts),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: VolumeTrendChart(workouts: workouts),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: DifficultyPieChart(workouts: workouts),
                ),
              ),
            ] else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(
                        'Kişisel Rekorlar',
                        Icons.emoji_events_rounded,
                        _accentOrange,
                      ),
                      const SizedBox(height: 10),
                      if (displayPRs.isEmpty)
                        _emptyState(
                          'Henüz antrenman kaydı yok.\nPR\'ların burada görünecek.',
                        )
                      else
                        ...displayPRs.asMap().entries.map(
                          (e) => _PRRow(
                            rank: e.key + 1,
                            exerciseName: e.value.key,
                            weight: e.value.value,
                            trend: _prTrend(e.value.key, workouts),
                            history: wp.maxWeightsFor(e.value.key),
                            allWorkouts: workouts,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(child: WorkoutHistoryCard()),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Widget _buildSectionSwitcher() {
    const labels = ['Özet', 'Grafikler', 'Geçmiş'];
    final icons = [
      Icons.dashboard_rounded,
      Icons.insights_rounded,
      Icons.history_rounded,
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = _selectedSection == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedSection = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.42)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icons[index],
                      color: selected ? AppColors.primaryLight : Colors.white38,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labels[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.48),
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatsOverview({
    required Set<int> activeWeekdays,
    required int weeklyCount,
    required int prevWeekCount,
    required double weeklyVol,
    required double previousWeeklyVol,
    required double monthlyKcal,
    required int monthlyCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _sectionTitle(
                'Bu Hafta',
                Icons.bar_chart_rounded,
                _accentBlue,
              ),
            ),
            _WeekDots(activeWeekdays: activeWeekdays),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statChip(
              icon: Icons.fitness_center_rounded,
              label: 'Seans',
              value: weeklyCount.toDouble(),
              suffix: ' antrenman',
              color: _accentOrange,
              trend: prevWeekCount == 0 ? null : weeklyCount - prevWeekCount,
              trendLabel: 'geçen haftadan',
            ),
            const SizedBox(width: 8),
            _statChip(
              icon: Icons.scale_rounded,
              label: 'Hacim',
              value: weeklyVol > 0 ? (weeklyVol / 1000) : 0,
              suffix: ' ton',
              isDecimal: true,
              color: _accentBlue,
              trend: previousWeeklyVol == 0
                  ? null
                  : (weeklyVol - previousWeeklyVol > 0
                        ? 1
                        : weeklyVol - previousWeeklyVol < 0
                        ? -1
                        : 0),
              trendLabel: 'geçen haftaya göre',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _sectionTitle(
          'Son 30 Gün',
          Icons.local_fire_department_rounded,
          _accentGreen,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statChip(
              icon: Icons.local_fire_department_rounded,
              label: 'Yakılan Kalori',
              value: monthlyKcal > 0 ? monthlyKcal : 0,
              suffix: ' kcal',
              color: _accentGreen,
            ),
            const SizedBox(width: 8),
            _statChip(
              icon: Icons.fitness_center_rounded,
              label: 'Antrenman',
              value: monthlyCount.toDouble(),
              suffix: ' seans',
              color: _accentOrange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _statChip({
    required IconData icon,
    required String label,
    required double value,
    required String suffix,
    required Color color,
    bool isDecimal = false,
    int? trend,
    String? trendLabel,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color.withValues(alpha: 0.9)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: value),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutExpo,
              builder: (context, val, child) {
                final displayStr = val == 0
                    ? '—'
                    : (isDecimal
                              ? val.toStringAsFixed(1)
                              : val.round().toString()) +
                          suffix;
                return Text(
                  displayStr,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
            if (trend != null && trend != 0 && trendLabel != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    trend > 0
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 9,
                    color: trend > 0
                        ? _accentGreen.withValues(alpha: 0.8)
                        : Colors.redAccent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      trendLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 9,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 13,
          height: 1.5,
        ),
      ),
    );
  }
}

// ── Haftalık aktivite nokta takvimi ─────────────────────────────────────────
class _WeekDots extends StatelessWidget {
  final Set<int> activeWeekdays; // 0=Pzt … 6=Paz

  const _WeekDots({required this.activeWeekdays});

  static const _labels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final active = activeWeekdays.contains(i);
        return Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? const Color(0xFF64D2FF)
                      : Colors.white.withValues(alpha: 0.12),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF64D2FF,
                            ).withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _labels[i],
                style: TextStyle(
                  color: active
                      ? const Color(0xFF64D2FF)
                      : Colors.white.withValues(alpha: 0.2),
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PerformanceReadCard extends StatelessWidget {
  final ({String title, String message, IconData icon, Color color}) read;

  const _PerformanceReadCard({required this.read});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: read.color.withValues(alpha: 0.26)),
        boxShadow: [
          BoxShadow(
            color: read.color.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: read.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: read.color.withValues(alpha: 0.28)),
            ),
            child: Icon(read.icon, color: read.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Performans Okuması',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  read.title,
                  style: TextStyle(
                    color: read.color,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  read.message,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.42,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── PR Detay Modal ────────────────────────────────────────────────────────────

class _PRDetailSheet extends StatelessWidget {
  final String exerciseName;
  final List<({DateTime date, double weight, int sets, int reps})> records;
  final double currentPR;

  const _PRDetailSheet({
    required this.exerciseName,
    required this.records,
    required this.currentPR,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.90,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A1A2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD60A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFFFD60A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exerciseName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'PR: ${currentPR.truncateToDouble() == currentPR ? currentPR.toInt() : currentPR.toStringAsFixed(1)} kg  •  ${records.length} kayıt',
                            style: TextStyle(
                              color: const Color(
                                0xFFFFD60A,
                              ).withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Text(
                          'Bu egzersiz için kayıt bulunamadı.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.40),
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: controller,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: records.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final r = records[i];
                          final isPR = r.weight == currentPR;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isPR
                                  ? const Color(
                                      0xFFFFD60A,
                                    ).withValues(alpha: 0.07)
                                  : Colors.white.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPR
                                    ? const Color(
                                        0xFFFFD60A,
                                      ).withValues(alpha: 0.25)
                                    : Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  DateFormat(
                                    'd MMM yyyy',
                                    'tr_TR',
                                  ).format(r.date),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${r.sets}×${r.reps}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.55,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (isPR) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFFFFD60A,
                                      ).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PR 🏆',
                                      style: TextStyle(
                                        color: Color(0xFFFFD60A),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  '${r.weight.truncateToDouble() == r.weight ? r.weight.toInt() : r.weight.toStringAsFixed(1)} kg',
                                  style: TextStyle(
                                    color: isPR
                                        ? const Color(0xFFFFD60A)
                                        : Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Ölçüm Hatırlatıcı Banner ─────────────────────────────────────────────────

class _MeasurementReminderBanner extends StatelessWidget {
  final int daysSince;
  const _MeasurementReminderBanner({required this.daysSince});

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFB300);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            amber.withValues(alpha: 0.15),
            amber.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.straighten_rounded, color: amber, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ölçüm Zamanı! 📏',
                  style: TextStyle(
                    color: amber,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  'Son ölçümünden $daysSince gün geçti. Vücut ölçülerini güncelle.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddMeasurementSheet(),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: amber.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: amber.withValues(alpha: 0.45)),
              ),
              child: const Text(
                'Ekle',
                style: TextStyle(
                  color: amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Performans AI Butonu ─────────────────────────────────────────────────────

class _PerformanceAiButton extends StatelessWidget {
  final int weeklyCount;
  final double weeklyVol;
  final double monthlyKcal;
  final int risingPrs;

  const _PerformanceAiButton({
    required this.weeklyCount,
    required this.weeklyVol,
    required this.monthlyKcal,
    required this.risingPrs,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openAiAnalysis(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primaryLight,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Performans Analizi Al',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAiAnalysis(BuildContext context) {
    final ctx = StringBuffer();
    ctx.write('Bu hafta $weeklyCount antrenman yaptım. ');
    if (weeklyVol > 0) {
      ctx.write(
        'Haftalık toplam hacim: ${(weeklyVol / 1000).toStringAsFixed(1)} ton. ',
      );
    }
    if (monthlyKcal > 0) {
      ctx.write(
        'Bu ay yakılan toplam kalori: ${monthlyKcal.toStringAsFixed(0)} kcal. ',
      );
    }
    if (risingPrs > 0) {
      ctx.write('$risingPrs egzersizde kişisel rekor artışı var. ');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        const suffix =
            'Performansımı değerlendir, önümüzdeki 7 gün için 3 kritik nokta söyle.';
        final ctxStr = ctx.toString();
        final maxCtx = 480 - suffix.length;
        final safeCtx = ctxStr.length > maxCtx
            ? ctxStr.substring(0, maxCtx)
            : ctxStr;
        return AiCoachInsightSheet(
          goal: 'Performans Gelişimi',
          question: '$safeCtx$suffix',
        );
      },
    );
  }
}
// ── PR Satırı ─────────────────────────────────────────────────────────────────

class _PRRow extends StatelessWidget {
  final int rank;
  final String exerciseName;
  final double weight;
  final int trend;
  final List<double> history;
  final List<Workout> allWorkouts;

  const _PRRow({
    required this.rank,
    required this.exerciseName,
    required this.weight,
    required this.trend,
    required this.history,
    required this.allWorkouts,
  });

  void _showDetail(BuildContext context) {
    // Bu egzersiz için tüm tarih+ağırlık geçmişi
    final records =
        allWorkouts
            .where((w) => w.name == exerciseName && (w.weight ?? 0) > 0)
            .map(
              (w) => (
                date: w.workoutDate,
                weight: w.weight ?? 0.0,
                sets: w.sets ?? 1,
                reps: w.reps ?? 1,
              ),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PRDetailSheet(
        exerciseName: exerciseName,
        records: records,
        currentPR: weight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFFA56E);
    const rankColors = [
      Color(0xFFFFD60A),
      Color(0xFFADB5BD),
      Color(0xFFCD7F32),
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : Colors.white24;

    final trendIcon = switch (trend) {
      1 => Icons.trending_up_rounded,
      -1 => Icons.trending_down_rounded,
      _ => Icons.trending_flat_rounded,
    };
    final trendColor = switch (trend) {
      1 => const Color(0xFF30D158),
      -1 => const Color(0xFFFF6B6B),
      _ => Colors.white24,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetail(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: rankColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  exerciseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (history.length >= 2) ...[
                _buildSparkline(trendColor),
                const SizedBox(width: 12),
              ],
              Icon(trendIcon, size: 16, color: trendColor),
              const SizedBox(width: 8),
              Text(
                '${weight.truncateToDouble() == weight ? weight.toInt() : weight.toStringAsFixed(1)} kg',
                style: const TextStyle(
                  color: orange,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 15,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSparkline(Color lineColor) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i]));
    }

    final minVol = history.reduce((a, b) => a < b ? a : b);
    final maxVol = history.reduce((a, b) => a > b ? a : b);
    // Edge case: minVol ø olabilir — sabit offset kullan
    final range = (maxVol - minVol);
    final offset = range < 5 ? 5.0 : range * 0.15;

    return SizedBox(
      width: 40,
      height: 20,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (history.length - 1).toDouble(),
          minY: minVol - offset,
          maxY: maxVol + offset,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: lineColor,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          lineTouchData: LineTouchData(enabled: false),
        ),
      ),
    );
  }
}

// ── Periodizasyon Kartı ───────────────────────────────────────────────────────

class _PeriodizationCard extends StatelessWidget {
  final List<Workout> workouts;

  const _PeriodizationCard({required this.workouts});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          children: [
            const Icon(Icons.loop_rounded, color: Colors.white38, size: 28),
            const SizedBox(height: 8),
            Text(
              'Antrenman Döngüsü',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'İlk antrenmanını kaydettiğinde\ndöngün buradan takip edilecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.30),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = [...workouts]
      ..sort((a, b) => a.workoutDate.compareTo(b.workoutDate));
    final firstDate = sorted.first.workoutDate;

    final daysSince = DateTime.now().difference(firstDate).inDays;
    final cycleWeek = ((daysSince ~/ 7) % 4) + 1;

    final phases = [
      (
        week: 1,
        name: 'Güç Fazı',
        desc: '5×5 ağır · Düşük tekrar, maksimum yük',
        focus: 'Maksimum güç ve sinir-kas adaptasyonu',
        icon: Icons.bolt_rounded,
        color: const Color(0xFFFF6B6B),
      ),
      (
        week: 2,
        name: 'Hipertrofi Fazı',
        desc: '4×8-10 orta · Kas kütlesi odaklı',
        focus: 'Kas büyümesi ve hacim artışı',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFFFFA56E),
      ),
      (
        week: 3,
        name: 'Yüksek Hacim',
        desc: '3×12-15 hafif · Metabolik stres yüksek',
        focus: 'Dayanıklılık ve yağ yakımı kapasitesi',
        icon: Icons.whatshot_rounded,
        color: const Color(0xFF64D2FF),
      ),
      (
        week: 4,
        name: 'Deload',
        desc: '3×8 çok hafif · Toparlanma öncelikli',
        focus: 'Eklem ve kas toparlanması — süper kompanzasyon',
        icon: Icons.self_improvement_rounded,
        color: const Color(0xFF30D158),
      ),
    ];

    final current = phases[cycleWeek - 1];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: current.color.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: current.color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  current.color.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: current.color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current.color.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(current.icon, color: current.color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Antrenman Döngüsü',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.40),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        current.name,
                        style: TextStyle(
                          color: current.color,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: current.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: current.color.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Text(
                    'Hafta $cycleWeek/4',
                    style: TextStyle(
                      color: current.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.desc,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  current.focus,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: List.generate(4, (i) {
                    final isActive = i + 1 == cycleWeek;
                    final isPast = i + 1 < cycleWeek;
                    final ph = phases[i];
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive
                              ? ph.color
                              : isPast
                              ? ph.color.withValues(alpha: 0.35)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: phases.map((ph) {
                    final isActive = ph.week == cycleWeek;
                    return Text(
                      ph.week == 4 ? 'Deload' : 'H${ph.week}',
                      style: TextStyle(
                        color: isActive
                            ? ph.color
                            : Colors.white.withValues(alpha: 0.25),
                        fontSize: 9.5,
                        fontWeight: isActive
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
