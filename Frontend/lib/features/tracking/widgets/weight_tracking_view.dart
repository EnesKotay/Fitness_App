import 'dart:ui' as ui;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/preferences/app_preferences.dart';
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
import 'goal_timeline_card.dart';
import 'consistency_heatmap.dart';

class _GoalStatusLine extends StatelessWidget {
  final Color color;
  final String label;
  final String hint;

  const _GoalStatusLine({
    required this.color,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            '$label · $hint',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalProgressTrack extends StatelessWidget {
  final double progress;
  final Color color;
  final String startLabel;
  final String centerLabel;
  final String endLabel;

  const _GoalProgressTrack({
    required this.progress,
    required this.color,
    required this.startLabel,
    required this.centerLabel,
    required this.endLabel,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return Column(
      children: [
        SizedBox(
          height: 12,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: safeProgress),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => FractionallySizedBox(
                  widthFactor: value,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: safeProgress),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Align(
                  alignment: Alignment((value * 2) - 1, 0),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                startLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.34),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                centerLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                endLabel,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.34),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class WeightTrackingView extends StatefulWidget {
  const WeightTrackingView({super.key});

  static void showEntrySheet(BuildContext context, {WeightEntry? existing}) {
    final appPrefs = context.read<AppPreferences>();
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
    final unit = AppUnits.weightUnitFor(appPrefs);
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
                    AppUnits.kgToDisplay(
                      currentWeight,
                      appPrefs,
                    ).toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    unit,
                    style: const TextStyle(
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
                  initialValue: AppUnits.kgToDisplay(currentWeight, appPrefs),
                  minValue: appPrefs.usesImperial ? 66 : 30,
                  maxValue: appPrefs.usesImperial ? 550 : 250,
                  onChanged: (v) => setSheetState(
                    () => currentWeight = AppUnits.kgFromDisplay(v, appPrefs),
                  ),
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
  final GlobalKey _chartKey = GlobalKey();
  final ValueNotifier<int> _chartRangeIndex = ValueNotifier<int>(1);
  final ValueNotifier<HistoryFilter> _historyFilter =
      ValueNotifier<HistoryFilter>(HistoryFilter.all);
  Map<String, DiaryTotals> _chartNutritionTotals = const {};

  late ConfettiController _confettiController;
  double? _lastKnownWeight;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadChartNutritionTotals();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
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

        final current = provider.latestEntry?.weightKg;
        final goal = context.read<DietProvider>().profile?.targetWeight;
        if (current != null && goal != null && (current - goal).abs() < 0.1) {
          if (_lastKnownWeight != current) {
            _lastKnownWeight = current;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _confettiController.play();
            });
          }
        } else {
          _lastKnownWeight = current;
        }

        return Stack(
          alignment: Alignment.topCenter,
          children: [
            _buildMainContent(context, provider),
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2,
              maxBlastForce: 5,
              minBlastForce: 2,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.1,
            ),
          ],
        );
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
          SliverToBoxAdapter(child: _buildStreakBanner(context, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverToBoxAdapter(child: _buildWeightGoalCard(context, provider)),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: _buildSectionHeader(
              'Grafik',
              icon: Icons.show_chart_rounded,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: _buildChartCard(context, provider),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          SliverToBoxAdapter(
            child: _buildTrackingDetailsPanel(context, provider),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
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

  // ── Streak Banner ──────────────────────────────────────────────────────────

  Widget _buildStreakBanner(BuildContext context, WeightProvider provider) {
    final streak = provider.currentStreak;
    if (streak == 0) return const SizedBox.shrink();

    final color = streak >= 7
        ? const Color(0xFFFFB300)
        : streak >= 3
        ? const Color(0xFFFF9F43)
        : const Color(0xFF48BB78);

    final emoji = streak >= 14
        ? '🔥🔥'
        : streak >= 7
        ? '🔥'
        : '✅';
    final msg = streak >= 14
        ? '$streak günlük dev seri! Efsane!'
        : streak >= 7
        ? '$streak gün! Harika gidiyorsun'
        : '$streak gün kilo takibi serisi';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  // Bugün kayıt girilmişse farklı mesaj göster
                  Builder(
                    builder: (context) {
                      final today = DateTime.now();
                      final todayEntry = provider.entries.firstWhere(
                        (e) =>
                            e.date.year == today.year &&
                            e.date.month == today.month &&
                            e.date.day == today.day,
                        orElse: () => provider.entries.last,
                      );
                      final hasEntryToday =
                          provider.entries.isNotEmpty &&
                          todayEntry.date.year == today.year &&
                          todayEntry.date.month == today.month &&
                          todayEntry.date.day == today.day;

                      return Text(
                        hasEntryToday
                            ? '✓ Bugün kilo kaydın tamam!'
                            : 'Serini kırmamak için bugün de kilo gir',
                        style: TextStyle(
                          color: hasEntryToday
                              ? color.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.40),
                          fontSize: 11,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(
                '$streak 🔥',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Kilo + Hedef Özet Kartı ───────────────────────────────────────────────

  Widget _buildWeightGoalCard(BuildContext context, WeightProvider provider) {
    final diet = context.watch<DietProvider>();
    final appPrefs = context.watch<AppPreferences>();
    final current = provider.latestEntry?.weightKg;
    final startWeight = provider.firstEntry?.weightKg ?? diet.profile?.weightKg;
    final goal = diet.profile?.targetWeight;
    final weekly = provider.weeklyChange;
    final total = provider.totalChange;

    final bool goalReached =
        current != null && goal != null && (current - goal).abs() < 0.1;
    final hasGoalProgress =
        goal != null && current != null && startWeight != null;

    double progress = 0.0;
    double remainingToGoal = 0.0;
    double directionalChange = 0.0;
    bool movedAwayFromGoal = false;
    if (hasGoalProgress) {
      final totalDiff = (goal - startWeight).abs();
      directionalChange = goal > startWeight
          ? current - startWeight
          : startWeight - current;
      progress = totalDiff > 0
          ? (directionalChange / totalDiff).clamp(0.0, 1.0)
          : 0.0;
      remainingToGoal = (current - goal).abs();
      movedAwayFromGoal = directionalChange < -0.05 && !goalReached;
    }

    final accentColor = goalReached
        ? AppColors.success.withValues(alpha: 0.82)
        : const Color(0xFF9AA4B2);
    final goalStatusText = goalReached
        ? 'Hedef tamam'
        : movedAwayFromGoal
        ? 'Rotayı düzelt'
        : '${(progress * 100).round()}% tamam';
    final goalHint = goal == null || current == null
        ? 'Hedef belirleyince ilerleme burada görünür'
        : goalReached
        ? 'Bu hedefi koruma zamanı'
        : '${AppUnits.formatWeight(remainingToGoal, appPrefs)} kaldı';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF13131F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GÜNCEL KİLO',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.40),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: (current ?? 0) - 1,
                                end: current ?? 0,
                              ),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (_, val, _) => Text(
                                current != null
                                    ? AppUnits.kgToDisplay(
                                        val,
                                        appPrefs,
                                      ).toStringAsFixed(1)
                                    : '--.-',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 46,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                AppUnits.weightUnitFor(appPrefs),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 7),
                        _GoalStatusLine(
                          color: accentColor,
                          label: goalStatusText,
                          hint: goalHint,
                        ),
                      ],
                    ),
                  ),

                  if (goal != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'HEDEF',
                            style: TextStyle(
                              color: accentColor.withValues(alpha: 0.72),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            goalReached
                                ? 'Ulaştın'
                                : AppUnits.formatWeight(goal, appPrefs),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.86),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),

              if (hasGoalProgress && !goalReached) ...[
                const SizedBox(height: 16),
                _GoalProgressTrack(
                  progress: progress,
                  color: accentColor,
                  startLabel: AppUnits.formatWeight(startWeight, appPrefs),
                  centerLabel: movedAwayFromGoal
                      ? 'Hedeften uzaklaşıyor'
                      : '${(progress * 100).round()}%',
                  endLabel: AppUnits.formatWeight(goal, appPrefs),
                ),
              ],

              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
              const SizedBox(height: 8),

              IntrinsicHeight(
                child: Row(
                  children: [
                    _statItem(
                      label: '7 Gün',
                      value: weekly == 0
                          ? '±0'
                          : '${weekly > 0 ? "+" : "-"}${AppUnits.formatWeight(weekly.abs(), appPrefs)}',
                      icon: weekly <= 0
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      color: weekly == 0
                          ? Colors.white.withValues(alpha: 0.42)
                          : weekly < 0
                          ? Colors.white.withValues(alpha: 0.62)
                          : Colors.white.withValues(alpha: 0.62),
                    ),
                    _verticalDivider(),
                    _statItem(
                      label: 'Toplam',
                      value: total == 0
                          ? '±0'
                          : '${total > 0 ? "+" : "-"}${AppUnits.formatWeight(total.abs(), appPrefs)}',
                      icon: Icons.show_chart_rounded,
                      color: total == 0
                          ? Colors.white.withValues(alpha: 0.42)
                          : total < 0
                          ? Colors.white.withValues(alpha: 0.62)
                          : Colors.white.withValues(alpha: 0.62),
                    ),
                    if (goal != null && current != null && !goalReached) ...[
                      _verticalDivider(),
                      _statItem(
                        label: 'Hedefe',
                        value: AppUnits.formatWeight(remainingToGoal, appPrefs),
                        icon: Icons.flag_rounded,
                        color: accentColor,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildAiButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color.withValues(alpha: 0.72)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verticalDivider() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    color: Colors.white.withValues(alpha: 0.06),
  );

  Widget _buildAiButton(BuildContext context) {
    return InkWell(
      onTap: () => _openAiAnalysis(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.26)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 17),
            SizedBox(width: 8),
            Text(
              'Kilo Yorumu Al',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w700,
                fontSize: 13,
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
    final appPrefs = context.read<AppPreferences>();
    final targetStr = profile?.targetWeight != null
        ? AppUnits.formatWeight(profile!.targetWeight!, appPrefs)
        : 'Bilinmiyor';

    final weightCtx = StringBuffer();
    final current = wp.latestEntry;
    final first = wp.firstEntry;
    final weekly = wp.weeklyChange;
    final recent = wp.entries
        .take(5)
        .map(
          (e) =>
              '${e.date.day}.${e.date.month}: ${AppUnits.formatWeight(e.weightKg, appPrefs)}',
        )
        .join(', ');

    if (current != null) {
      weightCtx.write(
        'Güncel kilo: ${AppUnits.formatWeight(current.weightKg, appPrefs)}. ',
      );
    }
    if (first != null) {
      weightCtx.write(
        'İlk kayıt: ${AppUnits.formatWeight(first.weightKg, appPrefs)}. ',
      );
    }
    if (weekly.abs() >= 0.05) {
      weightCtx.write(
        'Haftalık değişim: ${weekly > 0 ? "+" : ""}${AppUnits.formatWeight(weekly.abs(), appPrefs)}. ',
      );
    }
    if (recent.isNotEmpty) weightCtx.write('Son kayıtlar: $recent. ');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        const suffix = 'Kilo gidişatımı değerlendir, bugün için 3 kritik öneri ver.';
        final ctxStr = weightCtx.toString();
        final maxCtx = 480 - suffix.length;
        final safeCtx = ctxStr.length > maxCtx ? ctxStr.substring(0, maxCtx) : ctxStr;
        return AiCoachInsightSheet(
          goal: 'Hedef Kilo: $targetStr',
          question: '$safeCtx$suffix',
        );
      },
    );
  }

  // ── Grafik ─────────────────────────────────────────────────────────────────

  Widget _buildTrackingDetailsPanel(
    BuildContext context,
    WeightProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.10)),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.035),
          collapsedBackgroundColor: Colors.white.withValues(alpha: 0.035),
          iconColor: AppColors.primaryLight,
          collapsedIconColor: Colors.white54,
          leading: const Icon(
            Icons.tune_rounded,
            size: 18,
            color: AppColors.primaryLight,
          ),
          title: const Text(
            'Detaylar',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            'Hız koçu, hedef zaman çizelgesi ve istikrar haritası',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            _buildTrendInsightCard(context, provider),
            const SizedBox(height: 12),
            GoalTimelineCard(
              weightProvider: provider,
              dietProvider: context.watch<DietProvider>(),
              appPrefs: context.watch<AppPreferences>(),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConsistencyHeatmap(provider: provider),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context, WeightProvider provider) {
    final events = _buildChartEvents(context);
    return RepaintBoundary(
      key: _chartKey,
      child: ClipRRect(
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
                    SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: 12,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.show_chart_rounded,
                                size: 20,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'İlerleme',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton(
                                onPressed: () => _exportChart(context),
                                icon: const Icon(
                                  Icons.ios_share_rounded,
                                  size: 16,
                                  color: AppColors.primaryLight,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Grafiği Paylaş',
                              ),
                            ],
                          ),
                          _buildRangeChips(),
                        ],
                      ),
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
      add(
        TrackingChartEvent(
          date: w.workoutDate,
          label: 'Antrenman',
          color: const Color(0xFF64B5F6),
          icon: Icons.fitness_center_rounded,
        ),
      );
    }
    for (final m in measurements) {
      add(
        TrackingChartEvent(
          date: m.date,
          label: 'Ölçü',
          color: const Color(0xFFAB47BC),
          icon: Icons.straighten_rounded,
        ),
      );
    }

    final calorieTarget = diet.effectiveTargetKcal;
    if (calorieTarget > 0) {
      for (final item in _chartNutritionTotals.entries) {
        final t = item.value;
        if (t.totalKcal >= calorieTarget * 1.12 &&
            t.totalKcal >= calorieTarget + 150) {
          add(
            TrackingChartEvent(
              date: DateTime.tryParse(item.key) ?? DateTime.now(),
              label: 'Yüksek kalori',
              color: AppColors.warning,
              icon: Icons.local_fire_department_rounded,
            ),
          );
        }
      }
    }

    return byKey.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  Widget _buildEventLegend(List<TrackingChartEvent> events) {
    final unique = <String, TrackingChartEvent>{};
    for (final e in events) {
      unique.putIfAbsent(e.label, () => e);
    }
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
              _filterChip(
                'Manuel kayıtlar',
                HistoryFilter.manualOnly,
                selected,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(
    String label,
    HistoryFilter filter,
    HistoryFilter selected,
  ) {
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
    final appPrefs = context.read<AppPreferences>();
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
                            AppUnits.formatWeight(profile.weightKg, appPrefs),
                          ),
                          const SizedBox(width: 12),
                          _infoBox(
                            'Hedef',
                            profile.targetWeight != null
                                ? AppUnits.formatWeight(
                                    profile.targetWeight!,
                                    appPrefs,
                                  )
                                : '--',
                            color: const Color(0xFF00F5A0),
                          ),
                        ],
                      ),
                      if (healthyRange != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Sağlıklı aralık: ${AppUnits.formatWeight(healthyRange.min, appPrefs)} – ${AppUnits.formatWeight(healthyRange.max, appPrefs)}',
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
          '${AppUnits.formatWeight(entry.weightKg, context.read<AppPreferences>())} silinecek.',
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

  Future<void> _exportChart(BuildContext context) async {
    try {
      final boundary =
          _chartKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return;

      if (boundary.debugNeedsPaint) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grafik hazırlanıyor, lütfen tekrar deneyin.'),
          ),
        );
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/kilo_grafigi.png');
      await file.writeAsBytes(bytes);

      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'İşte kilo ilerleme grafiğim! 💪');
    } catch (e) {
      debugPrint('Grafik dışa aktarma hatası: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Grafik paylaşılamadı: $e')));
      }
    }
  }

  Widget _buildTrendInsightCard(BuildContext context, WeightProvider provider) {
    final weekly = provider.weeklyChange;
    if (provider.entries.length < 2) {
      return const SizedBox.shrink();
    }

    final absWeekly = weekly.abs();
    final isLosing = weekly < 0;
    final isStable = absWeekly < 0.1;

    String title = '';
    String description = '';
    Color statusColor = Colors.white;
    IconData icon = Icons.speed_rounded;

    if (isStable) {
      title = 'Denge Dönemi';
      description =
          'Kilonuz son bir haftada oldukça sabit seyrediyor. Kas kazanımı veya kilo koruma dönemi için mükemmel bir zemin!';
      statusColor = AppColors.primaryLight;
      icon = Icons.insights_rounded;
    } else if (isLosing) {
      if (absWeekly > 1.2) {
        title = 'Hızlı Düşüş';
        description =
            'Haftalık -${absWeekly.toStringAsFixed(1)} kg kaybettiniz. Bu tempo biraz hızlı olabilir, kas kütlenizi korumak için kalori açığını hafifçe azaltabilirsiniz.';
        statusColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
      } else if (absWeekly >= 0.3) {
        title = 'İdeal Kilo Kaybı';
        description =
            'Haftalık -${absWeekly.toStringAsFixed(1)} kg ile mükemmel bir hızdasınız! Sürdürülebilir yağ yakımı ve kas koruması için en sağlıklı tempo.';
        statusColor = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
      } else {
        title = 'Stabil Kademeli Düşüş';
        description =
            'Haftalık -${absWeekly.toStringAsFixed(1)} kg ile yavaş ama kararlı bir düşüş. Unutmayın, yavaş kayıplar en kalıcı olanlardır!';
        statusColor = const Color(0xFF64D2FF);
        icon = Icons.trending_down_rounded;
      }
    } else {
      if (absWeekly > 0.8) {
        title = 'Hızlı Kilo Artışı';
        description =
            'Haftalık +${absWeekly.toStringAsFixed(1)} kg artış var. Yağlanmayı azaltmak adına kalori fazlasını biraz kısmayı düşünebilirsiniz.';
        statusColor = AppColors.warning;
        icon = Icons.warning_amber_rounded;
      } else if (absWeekly >= 0.2) {
        title = 'İdeal Hacim Kazanımı';
        description =
            'Haftalık +${absWeekly.toStringAsFixed(1)} kg ile kas kütlesi kazanımı için ideal tempoda büyüyorsunuz. Harika!';
        statusColor = AppColors.success;
        icon = Icons.offline_bolt_rounded;
      } else {
        title = 'Hafif Kilo Artışı';
        description =
            'Haftalık +${absWeekly.toStringAsFixed(1)} kg ile yavaş ve kontrollü bir artış. Temiz büyüme (lean bulk) hedefleri için harika.';
        statusColor = const Color(0xFF64D2FF);
        icon = Icons.trending_up_rounded;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: statusColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Hız Koçu:',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
