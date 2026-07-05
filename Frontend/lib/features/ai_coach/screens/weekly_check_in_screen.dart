import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../../core/coaching/daily_focus_service.dart';
import '../../../core/constants/premium_features.dart';
import '../../../core/health/health_safety_service.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../nutrition/domain/repositories/diary_repository.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../workout/providers/streak_provider.dart';
import '../../workout/providers/workout_provider.dart';

class WeeklyCheckInScreen extends StatefulWidget {
  const WeeklyCheckInScreen({super.key});

  @override
  State<WeeklyCheckInScreen> createState() => _WeeklyCheckInScreenState();
}

class _WeeklyCheckInScreenState extends State<WeeklyCheckInScreen> {
  Map<String, DiaryTotals> _nutrition = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final diet = context.read<DietProvider>();
    final weight = context.read<WeightProvider>();
    final auth = context.read<AuthProvider>();
    final workout = context.read<WorkoutProvider>();

    await AppAnalytics.track('weekly_check_in_opened');
    final data = await diet.getSummaryForRange(7);
    await weight.loadEntries();
    final userId = auth.user?.id;
    if (userId != null && userId > 0 && workout.workouts.isEmpty) {
      await workout.loadWorkouts(userId);
    }

    if (!mounted) return;
    setState(() {
      _nutrition = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<AppPreferences>();
    final isEn = prefs.effectiveLanguageCode == 'en';
    final diet = context.watch<DietProvider>();
    final weight = context.watch<WeightProvider>();
    final streak = context.watch<StreakProvider>();
    final auth = context.watch<AuthProvider>();
    final isPremium = isPremiumTier(
      auth.user?.premiumTier,
      expiresAt: auth.user?.premiumExpiresAt,
    );

    final targetKcal = diet.effectiveTargetKcal;
    final avgKcal = _average((d) => d.totalKcal);
    final avgProtein = _average((d) => d.totalProtein);
    final loggedDays = _nutrition.values.where((d) => d.totalKcal > 0).length;
    final proteinGap = (diet.macroTargets.protein - diet.totals.totalProtein)
        .clamp(0.0, double.infinity);
    final focus = DailyFocusService.build(
      remainingKcal: diet.remainingKcal,
      proteinGap: proteinGap,
      waterLiters: diet.waterLiters,
      weeklyWorkoutCount: streak.weeklyWorkoutCount,
      weeklyWorkoutTarget: streak.weeklyWorkoutTarget,
      weeklyWeightChangeKg: weight.weeklyChange,
      isPremium: isPremium,
      isEn: isEn,
    );
    final warnings = HealthSafetyService.evaluateNutrition(
      targetKcal: targetKcal,
      consumedKcal: diet.totals.totalKcal,
      proteinTarget: diet.macroTargets.protein,
      proteinCurrent: diet.totals.totalProtein,
      waterLiters: diet.waterLiters,
      weeklyWeightChangeKg: weight.weeklyChange,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: Text(isEn ? 'Weekly Check-in' : 'Haftalık Check-in'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _FocusCard(
                    focus: focus,
                    isEn: isEn,
                    onTap: () {
                      AppAnalytics.track(
                        'daily_focus_tapped',
                        properties: {'pillar': focus.pillar},
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _ProgressGrid(
                    items: [
                      _ProgressItem(
                        label: isEn ? 'Nutrition logs' : 'Beslenme kaydı',
                        value: '$loggedDays/7',
                        progress: loggedDays / 7,
                        color: const Color(0xFF30D158),
                      ),
                      _ProgressItem(
                        label: isEn ? 'Workouts' : 'Antrenman',
                        value:
                            '${streak.weeklyWorkoutCount}/${streak.weeklyWorkoutTarget}',
                        progress: streak.weeklyChallengeProgress,
                        color: const Color(0xFFFF9F0A),
                      ),
                      _ProgressItem(
                        label: isEn ? 'Avg kcal' : 'Ort. kalori',
                        value: avgKcal <= 0 ? '-' : avgKcal.round().toString(),
                        progress: targetKcal <= 0
                            ? 0
                            : (avgKcal / targetKcal).clamp(0.0, 1.25),
                        color: AppColors.secondary,
                      ),
                      _ProgressItem(
                        label: isEn ? 'Avg protein' : 'Ort. protein',
                        value: avgProtein <= 0 ? '-' : '${avgProtein.round()}g',
                        progress: diet.macroTargets.protein <= 0
                            ? 0
                            : (avgProtein / diet.macroTargets.protein).clamp(
                                0.0,
                                1.25,
                              ),
                        color: const Color(0xFF64D2FF),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _TrendCard(
                    isEn: isEn,
                    weeklyChangeKg: weight.weeklyChange,
                    workoutsThisWeek: streak.weeklyWorkoutCount,
                    nutritionDays: loggedDays,
                  ),
                  const SizedBox(height: 14),
                  if (warnings.isNotEmpty) ...[
                    _SafetyPanel(warnings: warnings, isEn: isEn),
                    const SizedBox(height: 14),
                  ],
                  _PremiumValueCard(isPremium: isPremium, isEn: isEn),
                  const SizedBox(height: 14),
                  _AnalyticsFootnote(isEn: isEn),
                ],
              ),
            ),
    );
  }

  double _average(double Function(DiaryTotals totals) read) {
    final active = _nutrition.values.where((d) => read(d) > 0).toList();
    if (active.isEmpty) return 0;
    return active.fold<double>(0, (sum, item) => sum + read(item)) /
        active.length;
  }
}

class _FocusCard extends StatelessWidget {
  final DailyFocus focus;
  final bool isEn;
  final VoidCallback onTap;

  const _FocusCard({
    required this.focus,
    required this.isEn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      borderColor: AppColors.primary.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEn ? 'Best next move' : 'Bu haftanın en mantıklı hamlesi',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            focus.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            focus.message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(focus.actionLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressGrid extends StatelessWidget {
  final List<_ProgressItem> items;

  const _ProgressGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => _ProgressTile(item: items[index]),
    );
  }
}

class _ProgressTile extends StatelessWidget {
  final _ProgressItem item;

  const _ProgressTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final pct = item.progress.clamp(0.0, 1.0);
    return _Panel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.58),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            item.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: pct,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation(item.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final bool isEn;
  final double weeklyChangeKg;
  final int workoutsThisWeek;
  final int nutritionDays;

  const _TrendCard({
    required this.isEn,
    required this.weeklyChangeKg,
    required this.workoutsThisWeek,
    required this.nutritionDays,
  });

  @override
  Widget build(BuildContext context) {
    final changeText = weeklyChangeKg.abs() < 0.05
        ? (isEn ? 'stable' : 'stabil')
        : '${weeklyChangeKg > 0 ? '+' : ''}${weeklyChangeKg.toStringAsFixed(1)} kg';
    final insight = _insight();
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.timeline_rounded,
            title: isEn ? 'Weekly read' : 'Haftalık okuma',
            color: const Color(0xFF64D2FF),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: isEn ? 'Weight' : 'Kilo',
                  value: changeText,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: isEn ? 'Rhythm' : 'Ritim',
                  value: '$workoutsThisWeek + $nutritionDays',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  String _insight() {
    if (nutritionDays < 3 && workoutsThisWeek < 2) {
      return isEn
          ? 'The main gap is consistency. Start with logging 3 days and two short workouts.'
          : 'Ana eksik tutarlılık. Önce 3 gün beslenme kaydı ve iki kısa antrenman hedefle.';
    }
    if (weeklyChangeKg.abs() >= 1.5) {
      return isEn
          ? 'Weight moved fast this week. Read it with water, sodium and training load before changing calories.'
          : 'Kilo bu hafta hızlı oynamış. Kaloriyi değiştirmeden önce su, tuz ve antrenman yüküyle birlikte oku.';
    }
    if (workoutsThisWeek >= 3 && nutritionDays >= 5) {
      return isEn
          ? 'Great rhythm. The next upgrade is progressive overload and better meal timing.'
          : 'Ritim iyi. Sıradaki gelişim progressive overload ve öğün zamanlamasını netleştirmek.';
    }
    return isEn
        ? 'You have signal now. Keep the easiest habit stable before making the plan stricter.'
        : 'Artık sinyal var. Planı sertleştirmeden önce en kolay alışkanlığı sabitle.';
  }
}

class _SafetyPanel extends StatelessWidget {
  final List<NutritionSafetyWarning> warnings;
  final bool isEn;

  const _SafetyPanel({required this.warnings, required this.isEn});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      borderColor: const Color(0xFFFFD60A).withValues(alpha: 0.28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.health_and_safety_rounded,
            title: isEn ? 'Safety checks' : 'Güvenli plan kontrolü',
            color: const Color(0xFFFFD60A),
          ),
          const SizedBox(height: 12),
          for (final warning in warnings) ...[
            _WarningRow(warning: warning),
            if (warning != warnings.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _WarningRow extends StatelessWidget {
  final NutritionSafetyWarning warning;

  const _WarningRow({required this.warning});

  @override
  Widget build(BuildContext context) {
    final color = switch (warning.level) {
      NutritionSafetyLevel.danger => const Color(0xFFFF453A),
      NutritionSafetyLevel.warning => const Color(0xFFFFD60A),
      NutritionSafetyLevel.info => const Color(0xFF64D2FF),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${warning.message} ${warning.action}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _PremiumValueCard extends StatelessWidget {
  final bool isPremium;
  final bool isEn;

  const _PremiumValueCard({required this.isPremium, required this.isEn});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      borderColor: AppColors.primary.withValues(alpha: isPremium ? 0.18 : 0.36),
      child: Row(
        children: [
          _IconBubble(
            icon: isPremium ? Icons.verified_rounded : Icons.lock_open_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium
                      ? (isEn ? 'Premium is active' : 'Premium aktif')
                      : (isEn ? 'Why Premium matters' : 'Premium neyi açıyor?'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  isPremium
                      ? (isEn
                            ? 'AI can use your check-ins, memory and weekly rhythm for deeper plans.'
                            : 'AI; check-in, hafıza ve haftalık ritmini birlikte okuyarak daha derin plan çıkarır.')
                      : (isEn
                            ? 'Free tracks the day. Premium turns it into decisions: weekly analysis, AI memory and plan updates.'
                            : 'Ücretsiz plan günü takip eder. Premium bunu karara çevirir: haftalık analiz, AI hafıza ve plan güncelleme.'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _AnalyticsFootnote extends StatelessWidget {
  final bool isEn;

  const _AnalyticsFootnote({required this.isEn});

  @override
  Widget build(BuildContext context) {
    return Text(
      isEn
          ? 'Check-in opens and focus taps are stored locally for product analytics until remote analytics is connected.'
          : 'Check-in açılışları ve odak tıklamaları şimdilik yerel analytics olarak tutulur; uzaktan analytics bağlanınca aynı olaylar gönderilebilir.',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.34),
        height: 1.35,
        fontSize: 12,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF171719),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBubble(icon: icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBubble({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 19),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressItem {
  final String label;
  final String value;
  final double progress;
  final Color color;

  const _ProgressItem({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });
}
