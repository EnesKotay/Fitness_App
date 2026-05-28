import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';

/// Hedef kilo için zaman çizelgesi görselleştirmesi.
/// calculateEstimatedGoalDate metodundan aldığı tarihi güzel bir timeline ile gösterir.
class GoalTimelineCard extends StatelessWidget {
  final WeightProvider weightProvider;
  final DietProvider dietProvider;
  final AppPreferences appPrefs;

  const GoalTimelineCard({
    super.key,
    required this.weightProvider,
    required this.dietProvider,
    required this.appPrefs,
  });

  @override
  Widget build(BuildContext context) {
    final target = dietProvider.profile?.targetWeight;
    final current = weightProvider.latestEntry?.weightKg;
    final startWeight =
        weightProvider.firstEntry?.weightKg ?? dietProvider.profile?.weightKg;
    final goalDate =
        target != null ? weightProvider.calculateEstimatedGoalDate(target) : null;

    if (target == null || current == null) return const SizedBox.shrink();

    final goalReached = (current - target).abs() < 0.1;
    final accentColor = goalReached ? AppColors.success : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst renkli şerit
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: goalReached
                        ? [AppColors.success, AppColors.success.withValues(alpha: 0.2)]
                        : [AppColors.primary, const Color(0xFF7BCBFF)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(goalReached, goalDate),
                    const SizedBox(height: 16),
                    if (goalReached)
                      _buildGoalReachedContent()
                    else if (goalDate != null)
                      _buildTimelineContent(
                        current, target, startWeight ?? current, goalDate)
                    else
                      _buildNoDataContent(current, target),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool goalReached, DateTime? goalDate) {
    final color = goalReached ? AppColors.success : AppColors.primaryLight;
    final icon =
        goalReached ? Icons.emoji_events_rounded : Icons.timeline_rounded;
    final title =
        goalReached ? 'Hedefe Ulaştın! 🎯' : 'Hedef Zaman Çizelgesi';
    final subtitle = goalReached
        ? 'Tebrikler, harika bir başarı!'
        : goalDate != null
            ? 'Tahmini: ${DateFormat("d MMMM yyyy", "tr_TR").format(goalDate)}'
            : 'Daha fazla kayıt gerekiyor';

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: color.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGoalReachedContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
      ),
      child: const Column(
        children: [
          Text('🏆', style: TextStyle(fontSize: 36)),
          SizedBox(height: 8),
          Text(
            'Hedef kilona ulaştın!',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Yeni bir hedef belirleyebilirsin.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineContent(
    double current,
    double target,
    double startWeight,
    DateTime goalDate,
  ) {
    final now = DateTime.now();
    final daysRemaining = goalDate.difference(now).inDays;
    final weeksRemaining = (daysRemaining / 7).ceil().clamp(1, 999);
    final isLosing = target < current;

    final totalDiff = (startWeight - target).abs();
    final progressDiff = (startWeight - current).abs();
    final progress =
        totalDiff > 0 ? (progressDiff / totalDiff).clamp(0.0, 1.0) : 0.0;
    final remaining = (current - target).abs();

    final milestones =
        _buildMilestones(startWeight, target, goalDate, now, isLosing);

    return Column(
      children: [
        // İlerleme barı
        _ProgressBar(
          progress: progress,
          startWeight: startWeight,
          target: target,
          appPrefs: appPrefs,
        ),
        const SizedBox(height: 14),

        // Metrikler
        Row(
          children: [
            _buildMetric(
              icon: Icons.calendar_today_rounded,
              label: 'Kalan',
              value: daysRemaining > 0 ? '$daysRemaining gün' : 'Yaklaştı!',
              color: daysRemaining > 30
                  ? AppColors.primaryLight
                  : const Color(0xFFFFD60A),
            ),
            const SizedBox(width: 8),
            _buildMetric(
              icon: Icons.monitor_weight_outlined,
              label: 'Hedefe',
              value: AppUnits.formatWeight(remaining, appPrefs),
              color: AppColors.primaryLight,
            ),
            const SizedBox(width: 8),
            _buildMetric(
              icon: Icons.date_range_rounded,
              label: 'Süre',
              value: '$weeksRemaining hafta',
              color: const Color(0xFFFFA56E),
            ),
          ],
        ),

        if (milestones.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMilestoneTimeline(milestones, progress),
        ],
      ],
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 10, color: color.withValues(alpha: 0.8)),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.40),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  List<_Milestone> _buildMilestones(
    double start,
    double target,
    DateTime goalDate,
    DateTime now,
    bool isLosing,
  ) {
    final totalDays = goalDate.difference(now).inDays;
    if (totalDays <= 0) return [];

    final totalDiff = (target - start).abs();
    final result = <_Milestone>[];
    for (int i = 1; i <= 3; i++) {
      final fraction = i / 4.0;
      final weight = isLosing
          ? start - (totalDiff * fraction)
          : start + (totalDiff * fraction);
      final date = now.add(Duration(days: (totalDays * fraction).round()));
      result.add(_Milestone(weight: weight, date: date, fraction: fraction));
    }
    return result;
  }

  Widget _buildMilestoneTimeline(
      List<_Milestone> milestones, double currentProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KİLOMETRE TAŞLARI',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.28),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: milestones.asMap().entries.expand((entry) {
            final i = entry.key;
            final m = entry.value;
            final isPast = currentProgress >= m.fraction;
            final color =
                isPast ? AppColors.primary : Colors.white.withValues(alpha: 0.20);

            return [
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.only(top: 13),
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPast
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.04),
                      border: Border.all(
                        color: isPast
                            ? AppColors.primary.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.10),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: isPast
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 14)
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    AppUnits.formatWeight(m.weight, appPrefs),
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM', 'tr_TR').format(m.date),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ];
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNoDataContent(double current, double target) {
    final remaining = (current - target).abs();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hedefe ${AppUnits.formatWeight(remaining, appPrefs)} kaldı',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tahmini tarih için en az 2 farklı günde kilo kaydı gir.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.40),
                    fontSize: 11,
                    height: 1.4,
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

// ── İlerleme Barı (ayrı StatelessWidget — MediaQuery kullanır) ────────────────

class _ProgressBar extends StatelessWidget {
  final double progress;
  final double startWeight;
  final double target;
  final AppPreferences appPrefs;

  const _ProgressBar({
    required this.progress,
    required this.startWeight,
    required this.target,
    required this.appPrefs,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = progress > 0.7
        ? AppColors.success
        : progress > 0.4
            ? AppColors.primary
            : AppColors.primaryLight;
    final isLosing = target < startWeight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${AppUnits.formatWeight(startWeight, appPrefs)} ${isLosing ? "↓" : "↑"}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(progress * 100).round()}% tamamlandı',
              style: TextStyle(
                color: progressColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              AppUnits.formatWeight(target, appPrefs),
              style: TextStyle(
                color: AppColors.primaryLight,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: progress.clamp(0.02, 1.0)),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (_, val, __) => FractionallySizedBox(
                  widthFactor: val,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          progressColor.withValues(alpha: 0.7),
                          progressColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: progressColor.withValues(alpha: 0.40),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Milestone model ───────────────────────────────────────────────────────────

class _Milestone {
  final double weight;
  final DateTime date;
  final double fraction;
  const _Milestone({
    required this.weight,
    required this.date,
    required this.fraction,
  });
}
