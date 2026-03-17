import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_gradient_background.dart';
import '../../../core/utils/app_snack.dart';
import '../../../core/theme/app_theme.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../widgets/premium_summary_card.dart';
import '../widgets/stats_grid.dart';
import '../widgets/neon_line_chart.dart';
import '../widgets/history_list.dart';
import '../widgets/weight_ruler_picker.dart';
import '../widgets/consistency_heatmap.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/tracking_provider.dart';
import '../widgets/measurements_view.dart';
import '../widgets/body_composition_card.dart';
import '../widgets/add_measurement_sheet.dart';
import '../widgets/ai_coach_insight_sheet.dart';
import '../widgets/measurement_trend_chart.dart';
import '../../../core/models/body_measurement.dart';

/// Takip sayfası: kilo girişi, özet, grafik, ısı haritası, geçmiş. Baştan tasarlandı.
class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final ValueNotifier<int> _chartRangeIndex = ValueNotifier<int>(1);
  final ValueNotifier<int> _selectedTabIndex = ValueNotifier<int>(0);
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _showAdvancedTracking = false;

  @override
  void dispose() {
    _chartRangeIndex.dispose();
    _selectedTabIndex.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
      } else {
        context.read<TrackingProvider>().reset();
      }
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
          onPressed: () => _showAddWeightSheet(context),
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
              await context.read<TrackingProvider>().loadBodyMeasurements(
                authId,
              );
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
                      builder: (context, tracking, diet, _) => BodyCompositionCard(
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

        return Consumer<WeightProvider>(
          builder: (context, provider, _) {
            final isEmpty = provider.entries.isEmpty;
            if (provider.isLoading && isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Yükleniyor...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }
            if (isEmpty) return _buildEmptyState(context, provider);
            return _buildMainContent(context, provider);
          },
        );
      },
    );
  }

  Widget _buildMainContent(BuildContext context, WeightProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.loadEntries,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: RepaintBoundary(
                child: PremiumSummaryCard(
                  provider: provider,
                  screenshotController: _screenshotController,
                  onShare: () => _shareProgress(context),
                  onSettingsTap: () {},
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildQuickSummaryCard(context, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildChartCard(provider)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _buildAdvancedSection(context, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildHistoryHeader(context)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          HistoryList(
            provider: provider,
            onDelete: (entry) => _confirmDelete(context, provider, entry),
            onEdit: (entry) => _showEditWeightSheet(context, entry),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildQuickSummaryCard(BuildContext context, WeightProvider provider) {
    final diet = context.read<DietProvider>();
    final target = diet.profile?.targetWeight;
    final current = provider.latestEntry?.weightKg;
    final weekly = provider.weeklyChange;
    final streak = provider.currentStreak;
    final goalDate = target != null
        ? provider.calculateEstimatedGoalDate(target)
        : null;

    String headline = 'Bugün kayıt düzenini koru';
    IconData headlineIcon = Icons.insights_rounded;
    Color headlineColor = AppColors.primaryLight;

    if (current != null && target != null && (current - target).abs() > 0.1) {
      final diff = current - target;
      if (diff > 0) {
        headline = 'Hedefe ${diff.toStringAsFixed(1)} kg kaldı';
        headlineIcon = Icons.flag_rounded;
        headlineColor = AppColors.primaryLight;
      } else {
        headline = 'Hedefinin ${(-diff).toStringAsFixed(1)} kg altındasın';
        headlineIcon = Icons.celebration_rounded;
        headlineColor = AppColors.success;
      }
    } else if (weekly.abs() >= 0.05) {
      if (weekly < 0) {
        headline = 'Son 7 günde ${(-weekly).toStringAsFixed(1)} kg verdin';
        headlineIcon = Icons.trending_down_rounded;
        headlineColor = AppColors.success;
      } else {
        headline = 'Son 7 günde +${weekly.toStringAsFixed(1)} kg';
        headlineIcon = Icons.trending_up_rounded;
        headlineColor = AppColors.warning;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: headlineColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: headlineColor.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Top accent bar
              Positioned(
                top: 0, left: 0, right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        headlineColor,
                        headlineColor.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: headlineColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: headlineColor.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Icon(headlineIcon, color: headlineColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GÜNCEL DURUM',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                headline,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCompactMetric(
                            Icons.local_fire_department_rounded,
                            'Seri',
                            streak > 0 ? '$streak gün' : 'Yok',
                            streak >= 3 ? const Color(0xFFFFB300) : Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCompactMetric(
                            Icons.show_chart_rounded,
                            '7 Gün',
                            '${weekly >= 0 ? '+' : ''}${weekly.toStringAsFixed(1)} kg',
                            weekly <= 0 ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildCompactMetric(
                            Icons.flag_rounded,
                            'Hedef',
                            goalDate != null
                                ? DateFormat('d MMM', 'tr_TR').format(goalDate)
                                : 'Belirsiz',
                            goalDate != null ? AppColors.primaryLight : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildAiAnalysisButton(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMetric(IconData icon, String label, String value, Color valueColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: valueColor.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSection(BuildContext context, WeightProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() => _showAdvancedTracking = !_showAdvancedTracking);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _showAdvancedTracking
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _showAdvancedTracking ? Icons.keyboard_arrow_up_rounded : Icons.tune_rounded,
                      color: AppColors.primaryLight,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _showAdvancedTracking
                          ? 'Gelişmiş detayları gizle'
                          : 'Gelişmiş detayları göster',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (!_showAdvancedTracking)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '4 analiz',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white38, size: 20),
                ],
              ),
            ),
          ),
          if (_showAdvancedTracking) ...[
            const SizedBox(height: 16),
            StatsGrid(provider: provider),
            const SizedBox(height: 16),
            _buildPaceCoachCard(context, provider),
            const SizedBox(height: 12),
            _buildConsistencyCoachCard(provider),
            const SizedBox(height: 16),
            ConsistencyHeatmap(provider: provider),
          ],
        ],
      ),
    );
  }

  Widget _buildPaceCoachCard(BuildContext context, WeightProvider provider) {
    final target = context.read<DietProvider>().profile?.targetWeight;
    final current = provider.latestEntry?.weightKg;
    final weeklyChange = provider.weeklyChange;
    if (target == null || current == null) return const SizedBox.shrink();

    final remaining = (target - current).abs();
    final needsLoss = current > target;
    final recommendedMin = remaining < 2.0 ? 0.15 : 0.25;
    final recommendedMax = remaining < 2.0 ? 0.40 : 0.75;
    final actualRate = weeklyChange.abs();

    String status;
    Color statusColor;
    bool showEta = true;

    if (remaining < 0.10) {
      status = 'Hedefe ulaştın, hızın ideal.';
      statusColor = AppColors.success;
    } else if ((needsLoss && weeklyChange > 0.05) ||
        (!needsLoss && weeklyChange < -0.05)) {
      status = 'Hedefin ters yönünde gidiyorsun.';
      statusColor = AppColors.error;
      showEta = false;
    } else if (actualRate < recommendedMin) {
      status = 'Hız düşük. Haftalık tempoyu biraz artırabilirsin.';
      statusColor = AppColors.warning;
    } else if (actualRate > recommendedMax) {
      status = 'Hız yüksek. Daha dengeli ilerlemek daha güvenli.';
      statusColor = const Color(0xFFFFA726);
    } else {
      status = 'Hızın önerilen aralıkta, iyi gidiyorsun.';
      statusColor = AppColors.success;
    }

    String etaText = '—';
    if (showEta) {
      final effectiveRate = actualRate >= 0.05 ? actualRate : recommendedMin;
      final weeksLeft = remaining / effectiveRate;
      etaText = remaining < 0.10
          ? 'Hedefte'
          : weeksLeft <= 1
          ? '1 haftadan az'
          : '${weeksLeft.ceil()} hafta';
    }

    final shortLabel = remaining < 0.10 ? 'İdeal'
        : ((needsLoss && weeklyChange > 0.05) || (!needsLoss && weeklyChange < -0.05)) ? 'Dikkat'
        : actualRate < recommendedMin ? 'Yavaş'
        : actualRate > recommendedMax ? 'Hızlı' : 'İyi';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: statusColor),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.05),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.speed_rounded, size: 16, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Hız Koçu',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            shortLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Önerilen: ${recommendedMin.toStringAsFixed(2)} – ${recommendedMax.toStringAsFixed(2)} kg/hafta',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Mevcut: ${actualRate.toStringAsFixed(2)} kg/hafta${showEta ? '  •  Kalan: $etaText' : ''}',
                      style: TextStyle(color: statusColor.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      status,
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsistencyCoachCard(WeightProvider provider) {
    final now = DateTime.now();
    String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

    final last14Days = <String>{};
    final last7Days = <String>{};
    for (final e in provider.entries) {
      final d = DateTime(e.date.year, e.date.month, e.date.day);
      final diff = now.difference(d).inDays;
      if (diff >= 0 && diff < 14) {
        last14Days.add(dayKey(d));
      }
      if (diff >= 0 && diff < 7) {
        last7Days.add(dayKey(d));
      }
    }

    final count14 = last14Days.length;
    final count7 = last7Days.length;
    final score = ((count14 / 14) * 100).round().clamp(0, 100);
    const weeklyGoal = 3;
    final weeklyProgress = (count7 / weeklyGoal).clamp(0.0, 1.0);

    String feedback;
    Color color;
    if (score >= 70) {
      feedback = 'Kayıt düzenin güçlü. Bu tempoyu koru.';
      color = AppColors.success;
    } else if (score >= 40) {
      feedback = 'Orta seviyede. Düzenli kayıtla tahminler daha net olur.';
      color = AppColors.warning;
    } else {
      feedback = 'Kayıt sıklığı düşük. Haftada en az 3 kayıt hedefle.';
      color = AppColors.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: color),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.verified_rounded, size: 16, color: AppColors.primaryLight),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Kayıt Kalitesi',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        // Score badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '$score/100',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Son 14 gün: $count14/14 gün kayıt',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              minHeight: 10,
                              value: weeklyProgress,
                              backgroundColor: Colors.white.withValues(alpha: 0.08),
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$count7/$weeklyGoal',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Haftalık hedef: $weeklyGoal kayıt',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      feedback,
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(WeightProvider provider) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'İlerleme',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              _buildRangeChips(),
            ],
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<int>(
            valueListenable: _chartRangeIndex,
            builder: (_, index, child) =>
                NeonLineChart(provider: provider, selectedFilterIndex: index),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLegendDot(AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Günlük',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 14),
              _buildLegendDot(const Color(0xFFFFC107)),
              const SizedBox(width: 6),
              Text(
                '7 Gün Ort.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildRangeChips() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _rangeChip('1H', 0),
        const SizedBox(width: 4),
        _rangeChip('1A', 1),
        const SizedBox(width: 4),
        _rangeChip('3A', 2),
        const SizedBox(width: 4),
        _rangeChip('Tümü', 3),
      ],
    );
  }

  Widget _rangeChip(String label, int index) {
    return ValueListenableBuilder<int>(
      valueListenable: _chartRangeIndex,
      builder: (_, selected, child) {
        final isSelected = selected == index;
        return GestureDetector(
          onTap: () => _chartRangeIndex.value = index,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.primaryLight : Colors.white70,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryHeader(BuildContext context) {
    final count = context.read<WeightProvider>().entries.length;
    return Row(
      children: [
        Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text(
          'Geçmiş Kayıtlar',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '$count kayıt',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () => _showAddWeightSheet(context),
          icon: const Icon(
            Icons.add_rounded,
            size: 18,
            color: AppColors.primaryLight,
          ),
          label: const Text(
            'Ekle',
            style: TextStyle(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

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

  Widget _buildEmptyState(BuildContext context, WeightProvider provider) {
    final diet = context.read<DietProvider>();
    final profile = diet.profile;
    final profileWeight = profile?.weightKg;
    final healthyRange = profile?.healthyWeightRange;

    final bool hasProfile = profile != null;

    return Container(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  Icons.monitor_weight_rounded,
                  size: 48,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Kilo takibine başla',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'İlk kilonuzu ekleyerek yolculuğunuzu görselleştirin ve hedefinize ne kadar yaklaştığınızı görün.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              if (hasProfile) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildMiniInfoBox(
                            'Başlangıç',
                            '${profileWeight?.toStringAsFixed(1) ?? "--"} kg',
                          ),
                          const SizedBox(width: 12),
                          _buildMiniInfoBox(
                            'Hedef',
                            '${profile.targetWeight?.toStringAsFixed(1) ?? "--"} kg',
                            color: const Color(0xFF00F5A0),
                          ),
                        ],
                      ),
                      if (healthyRange != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Sağlıklı aralık: ${healthyRange.min.toStringAsFixed(1)} - ${healthyRange.max.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Beslenme profilinizi doldurarak kişisel hedeflerinizi ve ideal kilonuzu görebilirsiniz.',
                          style: TextStyle(
                            color: AppColors.warning.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: AppButton.primary(
                  text: 'İlk Kilomu Kaydet',
                  onPressed: () => _showAddWeightSheet(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniInfoBox(String label, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: (color ?? Colors.white),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
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
              onPressed: () => _showAddWeightSheet(context),
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

  Widget _buildAiAnalysisButton(BuildContext context) {
    return InkWell(
      onTap: () {
        final profile = context.read<DietProvider>().profile;
        final wp = context.read<WeightProvider>();
        final targetStr = profile?.targetWeight != null
            ? '${profile!.targetWeight} kg'
            : 'Bilinmiyor';

        // Build weight context for AI
        final current = wp.latestEntry;
        final first = wp.firstEntry;
        final weeklyChange = wp.weeklyChange;
        final recentEntries = wp.entries
            .take(5)
            .map(
              (e) =>
                  '${e.date.day}.${e.date.month}: ${e.weightKg.toStringAsFixed(1)} kg',
            )
            .join(', ');

        final weightContext = StringBuffer();
        if (current != null) {
          weightContext.write(
            'Güncel kilo: ${current.weightKg.toStringAsFixed(1)} kg. ',
          );
        }
        if (first != null) {
          weightContext.write(
            'İlk kayıt: ${first.weightKg.toStringAsFixed(1)} kg. ',
          );
        }
        if (weeklyChange.abs() >= 0.05) {
          weightContext.write(
            'Haftalık değişim: ${weeklyChange > 0 ? "+" : ""}${weeklyChange.toStringAsFixed(1)} kg. ',
          );
        }
        if (recentEntries.isNotEmpty) {
          weightContext.write('Son kayıtlar: $recentEntries. ');
        }

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => AiCoachInsightSheet(
            goal: 'Hedef Kilo: $targetStr',
            question:
                '${weightContext}Son zamanlardaki vücut değişimlerim ve kilo takibim doğrultusunda gidişatımı puanlayıp, bugüne dair odaklanmam gereken kritik 3 maddeyi söyler misin?',
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E2DE2).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Kilo Gidişatımı Yapay Zekaya Sor',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.3,
              ),
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

        // Build context from the last 2 measurements if available
        final contextBuffer = StringBuffer();
        if (measurements.length >= 2) {
          final m1 = measurements[0]; // Newest
          final m2 = measurements[1]; // Older
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
              'Ölçüm Değişimlerimi Yapay Zekaya Sor',
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

  Widget _buildTabButton(String title, int tabIndex, int currentIndex) {
    final isSelected = tabIndex == currentIndex;
    return GestureDetector(
      onTap: () => _selectedTabIndex.value = tabIndex,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _showAddWeightSheet(BuildContext context) {
    final dateController = TextEditingController(
      text: DateFormat('d.MM.yyyy').format(DateTime.now()),
    );
    DateTime selectedDate = DateTime.now();
    final lastWeight = context.read<WeightProvider>().latestEntry?.weightKg;
    final profileWeight = context.read<DietProvider>().profile?.weightKg;
    double currentWeight = lastWeight ?? profileWeight ?? 70.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Kilo ekle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) =>
                            Theme(data: AppTheme.darkTheme, child: child!),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          selectedDate = picked;
                          dateController.text = DateFormat(
                            'd.MM.yyyy',
                          ).format(picked);
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currentWeight.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'kg',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: WeightRulerPicker(
                      initialValue: currentWeight,
                      minValue: 30,
                      maxValue: 250,
                      onChanged: (v) => setSheetState(() => currentWeight = v),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      text: 'Kaydet',
                      onPressed: () async {
                        if (currentWeight <= 0) {
                          AppSnack.showError(
                            context,
                            'Geçerli bir değer girin',
                          );
                          return;
                        }
                        final entry = WeightEntry(
                          id: const Uuid().v4(),
                          date: selectedDate,
                          weightKg: currentWeight,
                        );
                        final currentContext = context;
                        final wp = currentContext.read<WeightProvider>();
                        final dp = currentContext.read<DietProvider>();
                        final success = await wp.addEntry(entry);
                        if (!success) {
                          if (!currentContext.mounted) return;
                          AppSnack.showError(
                            currentContext,
                            wp.error ?? 'Kilo kaydı eklenemedi',
                          );
                          return;
                        }
                        await dp.updateProfileWeightFromTracking(
                          entry.weightKg,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!currentContext.mounted) return;
                        AppSnack.showSuccess(currentContext, 'Kaydedildi');
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditWeightSheet(BuildContext context, WeightEntry entry) {
    final dateController = TextEditingController(
      text: DateFormat('d.MM.yyyy').format(entry.date),
    );
    DateTime selectedDate = entry.date;
    double currentWeight = entry.weightKg;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                top: 12,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Kilo düzenle',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) =>
                            Theme(data: AppTheme.darkTheme, child: child!),
                      );
                      if (picked != null) {
                        setSheetState(() {
                          selectedDate = picked;
                          dateController.text = DateFormat(
                            'd.MM.yyyy',
                          ).format(picked);
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            dateController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        currentWeight.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'kg',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: WeightRulerPicker(
                      initialValue: currentWeight,
                      minValue: 30,
                      maxValue: 250,
                      onChanged: (v) => setSheetState(() => currentWeight = v),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton.primary(
                      text: 'Güncelle',
                      onPressed: () async {
                        if (currentWeight <= 0) {
                          AppSnack.showError(
                            context,
                            'Geçerli bir değer girin',
                          );
                          return;
                        }
                        final updatedEntry = WeightEntry(
                          id: entry.id,
                          date: selectedDate,
                          weightKg: currentWeight,
                          note: entry.note,
                        );
                        final currentContext = context;
                        final wp = currentContext.read<WeightProvider>();
                        final dp = currentContext.read<DietProvider>();
                        final success = await wp.updateEntry(updatedEntry);
                        if (!success) {
                          if (!currentContext.mounted) return;
                          AppSnack.showError(
                            currentContext,
                            wp.error ?? 'Kilo kaydı güncellenemedi',
                          );
                          return;
                        }
                        await dp.updateProfileWeightFromTracking(
                          updatedEntry.weightKg,
                        );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        if (!currentContext.mounted) return;
                        AppSnack.showSuccess(currentContext, 'Güncellendi');
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _shareProgress(BuildContext context) async {
    final currentContext = context;
    try {
      final image = await _screenshotController.capture(
        delay: const Duration(milliseconds: 100),
      );
      if (image == null || !currentContext.mounted) return;
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/tracking_share.png');
      await file.writeAsBytes(image);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Kilo takibim 🎯 #Fitness',
        ),
      );
    } catch (e) {
      debugPrint('Share error: $e');
      if (currentContext.mounted) {
        AppSnack.showError(currentContext, 'Paylaşım hatası');
      }
    }
  }

  void _confirmDelete(
    BuildContext context,
    WeightProvider provider,
    WeightEntry entry,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kaydı sil?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${entry.weightKg.toStringAsFixed(1)} kg silinecek.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final currentContext = context;
              final success = await provider.deleteEntry(entry.id);
              if (!ctx.mounted) return;
              if (!success) {
                if (!currentContext.mounted) return;
                AppSnack.showError(
                  currentContext,
                  provider.error ?? 'Kilo kaydı silinemedi',
                );
                return;
              }

              // Eğer silinen kayıt en güncel kayıt id'si ile eşleşiyorsa profili güncelle
              final dietProvider = currentContext.read<DietProvider>();
              final newLatest = provider.latestEntry;
              if (newLatest != null) {
                await dietProvider.updateProfileWeightFromTracking(
                  newLatest.weightKg,
                );
              }

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!currentContext.mounted) return;
              AppSnack.showSuccess(currentContext, 'Silindi');
            },
            child: const Text(
              'Sil',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
