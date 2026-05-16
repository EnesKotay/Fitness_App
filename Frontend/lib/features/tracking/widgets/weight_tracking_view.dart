import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_snack.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../nutrition/domain/repositories/diary_repository.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/tracking_provider.dart';
import 'neon_line_chart.dart';
import 'history_list.dart';
import 'weight_ruler_picker.dart';
import 'ai_coach_insight_sheet.dart';

class WeightTrackingView extends StatefulWidget {
  const WeightTrackingView({super.key});

  static void showEntrySheet(BuildContext context, {WeightEntry? existing}) {
    final isEdit = existing != null;
    final initialDate = existing?.date ?? DateTime.now();
    final dateController = TextEditingController(
      text: DateFormat('d.MM.yyyy').format(initialDate),
    );
    DateTime selectedDate = initialDate;
    final fallbackWeight =
        existing?.weightKg ??
        context.read<WeightProvider>().latestEntry?.weightKg ??
        context.read<DietProvider>().profile?.weightKg ??
        70.0;
    double currentWeight = fallbackWeight;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Text(
                isEdit ? 'Kilo düzenle' : 'Kilo ekle',
                style: const TextStyle(
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
                      dateController.text =
                          DateFormat('d.MM.yyyy').format(picked);
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
                      const Icon(
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
                  const Text(
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
                  text: isEdit ? 'Güncelle' : 'Kaydet',
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (currentWeight <= 0) {
                            AppSnack.showError(
                              context,
                              'Geçerli bir değer girin',
                            );
                            return;
                          }
                          setSheetState(() => isSaving = true);
                          final currentContext = context;
                          final wp = currentContext.read<WeightProvider>();
                          final dp = currentContext.read<DietProvider>();

                          bool success;
                          if (isEdit) {
                            success = await wp.updateEntry(
                              WeightEntry(
                                id: existing.id,
                                date: selectedDate,
                                weightKg: currentWeight,
                                note: existing.note,
                              ),
                            );
                          } else {
                            success = await wp.addEntry(
                              WeightEntry(
                                id: const Uuid().v4(),
                                date: selectedDate,
                                weightKg: currentWeight,
                              ),
                            );
                          }

                          if (!success) {
                            if (ctx.mounted) {
                              setSheetState(() => isSaving = false);
                            }
                            if (!currentContext.mounted) return;
                            AppSnack.showError(
                              currentContext,
                              wp.error ??
                                  (isEdit
                                      ? 'Kilo kaydı güncellenemedi'
                                      : 'Kilo kaydı eklenemedi'),
                            );
                            return;
                          }
                          await dp.updateProfileWeightFromTracking(
                            currentWeight,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!currentContext.mounted) return;
                          AppSnack.showSuccess(
                            currentContext,
                            isEdit ? 'Güncellendi' : 'Kaydedildi',
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  State<WeightTrackingView> createState() => _WeightTrackingViewState();
}

class _WeightTrackingViewState extends State<WeightTrackingView> {
  final ValueNotifier<int> _chartRangeIndex = ValueNotifier<int>(1);
  final ValueNotifier<HistoryFilter> _historyFilter =
      ValueNotifier<HistoryFilter>(HistoryFilter.all);
  Map<String, DiaryTotals> _chartNutritionTotals = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadChartNutritionTotals();
    });
  }

  @override
  void dispose() {
    _chartRangeIndex.dispose();
    _historyFilter.dispose();
    super.dispose();
  }

  Future<void> _loadChartNutritionTotals() async {
    final totals = await context.read<DietProvider>().getSummaryForRange(90);
    if (!mounted) return;
    setState(() => _chartNutritionTotals = totals);
  }

  @override
  Widget build(BuildContext context) {
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
  }

  // ── Ana içerik: Kilo Kartı → Hero → Grafik → Geçmiş ──────────────────────

  Widget _buildMainContent(BuildContext context, WeightProvider provider) {
    return RefreshIndicator(
      onRefresh: provider.loadEntries,
      color: AppColors.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: _buildWeightGoalCard(context, provider),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverToBoxAdapter(
            child: _buildHeroCard(context, provider),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: _buildSectionHeader('Grafik', icon: Icons.show_chart_rounded),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildChartCard(context, provider),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: _buildSectionHeader('Geçmiş', icon: Icons.history_rounded),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(child: _buildHistoryHeader(context)),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          HistoryList(
            provider: provider,
            onDelete: (entry) => _confirmDelete(context, provider, entry),
            onEdit: (entry) =>
                WeightTrackingView.showEntrySheet(context, existing: entry),
            filter: _historyFilter.value,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.primaryLight),
            const SizedBox(width: 6),
          ],
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.38),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }

  // ── Kilo + Hedef Özet Kartı ────────────────────────────────────────────────

  Widget _buildWeightGoalCard(BuildContext context, WeightProvider provider) {
    final diet = context.watch<DietProvider>();
    final current = provider.latestEntry?.weightKg;
    final startWeight =
        provider.firstEntry?.weightKg ?? diet.profile?.weightKg;
    final goal = diet.profile?.targetWeight;

    double progress = 0.0;
    if (current != null && goal != null && startWeight != null) {
      final total = (startWeight - goal).abs();
      final done = (startWeight - current).abs();
      progress = total > 0.0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    }

    final bool goalReached =
        current != null && goal != null && (current - goal).abs() < 0.1;
    final Color progressColor =
        goalReached ? AppColors.success : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Üst satır: Kilo (sol) + Hedef kutusu (sağ) ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sol: Mevcut kilo
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Güncel Kilo',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            current != null
                                ? current.toStringAsFixed(1)
                                : '--.-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              height: 1.0,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'kg',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Sağ: Hedef kutusu
                  if (goal != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: goalReached
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: goalReached
                              ? AppColors.success.withValues(alpha: 0.25)
                              : AppColors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                goalReached
                                    ? Icons.emoji_events_rounded
                                    : Icons.flag_rounded,
                                size: 11,
                                color: goalReached
                                    ? AppColors.success
                                    : AppColors.primaryLight,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                goalReached ? 'Ulaştın!' : 'Hedef',
                                style: TextStyle(
                                  color: goalReached
                                      ? AppColors.success
                                      : Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${goal.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              color: goalReached
                                  ? AppColors.success
                                  : AppColors.primaryLight,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (current != null && !goalReached) ...[
                            const SizedBox(height: 1),
                            Text(
                              '${(current - goal).abs().toStringAsFixed(1)} kg kaldı',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.07)),
                      ),
                      child: Text(
                        'Hedef yok',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),

              if (goal != null && startWeight != null) ...[
                const SizedBox(height: 16),
                // ── İlerleme çubuğu (gradient) ──
                LayoutBuilder(
                  builder: (context, constraints) {
                    final barWidth = constraints.maxWidth;
                    return Stack(
                      children: [
                        Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        Container(
                          height: 5,
                          width: barWidth * progress,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: goalReached
                                  ? [AppColors.success, AppColors.success]
                                  : [AppColors.primary, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: progressColor.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Başlangıç: ${startWeight.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '%${(progress * 100).toStringAsFixed(0)} tamamlandı',
                      style: TextStyle(
                        color: progressColor.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoalStat(
      String label, String value, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: color.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ── Hero kartı ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard(BuildContext context, WeightProvider provider) {
    final diet = context.watch<DietProvider>();
    final target = diet.profile?.targetWeight;
    final current = provider.latestEntry?.weightKg;
    final weekly = provider.weeklyChange;
    final streak = provider.currentStreak;
    final goalDate =
        target != null ? provider.calculateEstimatedGoalDate(target) : null;

    String headline = 'Bugün kayıt düzenini koru';
    IconData headlineIcon = Icons.insights_rounded;
    Color accentColor = AppColors.primaryLight;

    if (current != null && target != null && (current - target).abs() > 0.1) {
      final diff = current - target;
      if (diff > 0) {
        headline = 'Hedefe ${diff.toStringAsFixed(1)} kg kaldı';
        headlineIcon = Icons.flag_rounded;
      } else {
        headline = 'Hedefinin ${(-diff).toStringAsFixed(1)} kg altındasın';
        headlineIcon = Icons.celebration_rounded;
        accentColor = AppColors.success;
      }
    } else if (weekly.abs() >= 0.05) {
      if (weekly < 0) {
        headline = 'Son 7 günde ${(-weekly).toStringAsFixed(1)} kg verdin';
        headlineIcon = Icons.trending_down_rounded;
        accentColor = AppColors.success;
      } else {
        headline = 'Son 7 günde +${weekly.toStringAsFixed(1)} kg';
        headlineIcon = Icons.trending_up_rounded;
        accentColor = AppColors.warning;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accentColor, accentColor.withValues(alpha: 0.2)],
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
                            color: accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Icon(headlineIcon, color: accentColor, size: 22),
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
                          child: _buildMetric(
                            Icons.local_fire_department_rounded,
                            'Seri',
                            streak > 0 ? '$streak gün' : 'Yok',
                            streak >= 3
                                ? const Color(0xFFFFB300)
                                : Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetric(
                            Icons.show_chart_rounded,
                            '7 Gün',
                            '${weekly >= 0 ? '+' : ''}${weekly.toStringAsFixed(1)} kg',
                            weekly <= 0 ? AppColors.success : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetric(
                            Icons.flag_rounded,
                            'Hedef',
                            goalDate != null
                                ? DateFormat('d MMM', 'tr_TR').format(goalDate)
                                : 'Belirsiz',
                            goalDate != null
                                ? AppColors.primaryLight
                                : Colors.white60,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildAiButton(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
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

  Widget _buildAiButton(BuildContext context) {
    return InkWell(
      onTap: () => _openAiAnalysis(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8E2DE2).withValues(alpha: 0.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Kilo Yorumu Al',
              style: TextStyle(
                color: Colors.white,
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
    final profile = context.read<DietProvider>().profile;
    final wp = context.read<WeightProvider>();
    final targetStr = profile?.targetWeight != null
        ? '${profile!.targetWeight} kg'
        : 'Bilinmiyor';

    final weightCtx = StringBuffer();
    final current = wp.latestEntry;
    final first = wp.firstEntry;
    final weekly = wp.weeklyChange;
    final recent = wp.entries
        .take(5)
        .map((e) =>
            '${e.date.day}.${e.date.month}: ${e.weightKg.toStringAsFixed(1)} kg')
        .join(', ');

    if (current != null) {
      weightCtx.write('Güncel kilo: ${current.weightKg.toStringAsFixed(1)} kg. ');
    }
    if (first != null) {
      weightCtx.write('İlk kayıt: ${first.weightKg.toStringAsFixed(1)} kg. ');
    }
    if (weekly.abs() >= 0.05) {
      weightCtx.write(
        'Haftalık değişim: ${weekly > 0 ? "+" : ""}${weekly.toStringAsFixed(1)} kg. ',
      );
    }
    if (recent.isNotEmpty) weightCtx.write('Son kayıtlar: $recent. ');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AiCoachInsightSheet(
        goal: 'Hedef Kilo: $targetStr',
        question:
            '${weightCtx}Son zamanlardaki vücut değişimlerim ve kilo takibim doğrultusunda gidişatımı puanlayıp, bugüne dair odaklanmam gereken kritik 3 maddeyi söyler misin?',
      ),
    );
  }

  // ── Grafik ─────────────────────────────────────────────────────────────────

  Widget _buildChartCard(BuildContext context, WeightProvider provider) {
    final events = _buildChartEvents(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, Color(0xFF7BCBFF)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.show_chart_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'İlerleme',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
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
                    builder: (_, index, _) => NeonLineChart(
                      provider: provider,
                      selectedFilterIndex: index,
                      events: events,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _legendDot(AppColors.primary),
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
                      _legendDot(const Color(0xFFFFC107)),
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
                  if (events.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildEventLegend(events),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<TrackingChartEvent> _buildChartEvents(BuildContext context) {
    final workouts = context.watch<WorkoutProvider>().workouts;
    final measurements = context.watch<TrackingProvider>().bodyMeasurements;
    final diet = context.watch<DietProvider>();
    final byKey = <String, TrackingChartEvent>{};

    void add(TrackingChartEvent e) =>
        byKey['${_dateKey(e.date)}-${e.label}'] = e;

    for (final w in workouts) {
      add(TrackingChartEvent(
        date: w.workoutDate,
        label: 'Antrenman',
        color: const Color(0xFF64B5F6),
        icon: Icons.fitness_center_rounded,
      ));
    }
    for (final m in measurements) {
      add(TrackingChartEvent(
        date: m.date,
        label: 'Ölçü',
        color: const Color(0xFFAB47BC),
        icon: Icons.straighten_rounded,
      ));
    }

    final calorieTarget = diet.effectiveTargetKcal;
    if (calorieTarget > 0) {
      for (final item in _chartNutritionTotals.entries) {
        final t = item.value;
        if (t.totalKcal >= calorieTarget * 1.12 &&
            t.totalKcal >= calorieTarget + 150) {
          add(TrackingChartEvent(
            date: DateTime.tryParse(item.key) ?? DateTime.now(),
            label: 'Yüksek kalori',
            color: AppColors.warning,
            icon: Icons.local_fire_department_rounded,
          ));
        }
      }
    }

    return byKey.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Widget _buildEventLegend(List<TrackingChartEvent> events) {
    final unique = <String, TrackingChartEvent>{};
    for (final e in events) { unique.putIfAbsent(e.label, () => e); }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: unique.values.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: e.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: e.color.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e.icon, color: e.color, size: 13),
              const SizedBox(width: 5),
              Text(
                e.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _legendDot(Color color) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

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
      builder: (_, selected, _) {
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

  // ── Geçmiş ─────────────────────────────────────────────────────────────────

  Widget _buildHistoryHeader(BuildContext context) {
    final count = context.read<WeightProvider>().entries.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 20,
              color: AppColors.primary,
            ),
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
              onPressed: () => WeightTrackingView.showEntrySheet(context),
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
        ),
        const SizedBox(height: 8),
        _buildHistoryFilters(),
      ],
    );
  }

  Widget _buildHistoryFilters() {
    return ValueListenableBuilder<HistoryFilter>(
      valueListenable: _historyFilter,
      builder: (context, selected, _) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _filterChip('Tüm kayıtlar', HistoryFilter.all, selected),
              const SizedBox(width: 8),
              _filterChip(
                'Sadece değişimler',
                HistoryFilter.changesOnly,
                selected,
              ),
              const SizedBox(width: 8),
              _filterChip('Manuel kayıtlar', HistoryFilter.manualOnly, selected),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, HistoryFilter filter, HistoryFilter selected) {
    final isSelected = filter == selected;
    return GestureDetector(
      onTap: () {
        _historyFilter.value = filter;
        setState(() {});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryLight : Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ── Boş durum ──────────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, WeightProvider provider) {
    final diet = context.read<DietProvider>();
    final profile = diet.profile;
    final healthyRange = profile?.healthyWeightRange;

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
              if (profile != null) ...[
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
                          _infoBox(
                            'Başlangıç',
                            '${profile.weightKg.toStringAsFixed(1)} kg',
                          ),
                          const SizedBox(width: 12),
                          _infoBox(
                            'Hedef',
                            '${profile.targetWeight?.toStringAsFixed(1) ?? "--"} kg',
                            color: const Color(0xFF00F5A0),
                          ),
                        ],
                      ),
                      if (healthyRange != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Sağlıklı aralık: ${healthyRange.min.toStringAsFixed(1)} – ${healthyRange.max.toStringAsFixed(1)} kg',
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
                  onPressed: () => WeightTrackingView.showEntrySheet(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value, {Color? color}) {
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
              color: color ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── Silme onayı ────────────────────────────────────────────────────────────

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
              final dp = currentContext.read<DietProvider>();
              final newLatest = provider.latestEntry;
              if (newLatest != null) {
                await dp.updateProfileWeightFromTracking(newLatest.weightKg);
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

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
