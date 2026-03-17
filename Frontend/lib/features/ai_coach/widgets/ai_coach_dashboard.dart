import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../nutrition/domain/entities/user_profile.dart';
import '../models/ai_coach_models.dart';

class AiCoachDashboard extends StatelessWidget {
  const AiCoachDashboard({
    super.key,
    required this.summary,
    required this.goal,
  });

  final DailySummary summary;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final accent = _goalAccent(goal);
    return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF101826).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Bugünün özeti',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        goal.label,
                        style: GoogleFonts.dmSans(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Koçun bugünkü verileri buna göre yorumlayacak.',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MetricTile(
                      icon: Icons.local_fire_department_rounded,
                      value: summary.calories > 0 ? '${summary.calories}' : null,
                      label: 'kcal',
                      color: const Color(0xFFFF7043),
                    ),
                    const SizedBox(width: 8),
                    _MetricTile(
                      icon: Icons.water_drop_rounded,
                      value: summary.waterLiters > 0
                          ? summary.waterLiters.toStringAsFixed(1)
                          : null,
                      label: 'litre',
                      color: const Color(0xFF4FACFE),
                    ),
                    const SizedBox(width: 8),
                    _MetricTile(
                      icon: Icons.fitness_center_rounded,
                      value: summary.workouts > 0 ? '${summary.workouts}' : null,
                      label: 'seans',
                      color: const Color(0xFF34D399),
                    ),
                    const SizedBox(width: 8),
                    _MetricTile(
                      icon: Icons.timer_outlined,
                      value: summary.workoutMinutes > 0
                          ? '${summary.workoutMinutes}'
                          : null,
                      label: 'dakika',
                      color: const Color(0xFFA78BFA),
                    ),
                  ],
                ),
                if ((summary.targetCalories ?? 0) > 0 && summary.calories > 0) ...[
                  const SizedBox(height: 12),
                  _CalorieProgressBar(
                    consumed: summary.calories,
                    target: summary.targetCalories!,
                    goal: goal,
                  ),
                ],
                if (summary.workoutHighlights.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: summary.workoutHighlights
                        .take(3)
                        .map(
                          (item) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.035),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                            child: Text(
                              item,
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.64),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (_trendNotes(summary).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _trendNotes(summary)
                        .map(
                          (note) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Text(
                              note,
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 280.ms)
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic);
  }

  List<String> _trendNotes(DailySummary summary) {
    final notes = <String>[];
    if (summary.avgCaloriesLast7Days != null && summary.calories > 0) {
      final diff = summary.calories - summary.avgCaloriesLast7Days!;
      if (diff.abs() >= 150) {
        notes.add(
          diff > 0
              ? 'Kalori son 7 gün ortalamanın üstünde'
              : 'Kalori son 7 gün ortalamanın altında',
        );
      }
    }
    if (summary.avgWaterLast7Days != null && summary.waterLiters > 0) {
      notes.add(
        summary.waterLiters >= summary.avgWaterLast7Days!
            ? 'Su performansı ortalamanın üstünde'
            : 'Su alımı ortalamanın altında',
      );
    }
    if ((summary.targetCalories ?? 0) > 0 && summary.calories > 0) {
      final remaining = summary.targetCalories! - summary.calories;
      notes.add(
        remaining > 0
            ? '$remaining kcal alanın kaldı'
            : '${remaining.abs()} kcal hedefi aştın',
      );
    }
    return notes.take(3).toList();
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String? value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          color: hasValue
              ? color.withValues(alpha: 0.09)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasValue
                ? color.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: hasValue ? color : Colors.white.withValues(alpha: 0.16),
            ),
            const SizedBox(height: 7),
            Text(
              hasValue ? value! : '—',
              style: GoogleFonts.dmSans(
                color: hasValue
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.16),
                fontSize: 15,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(
                  alpha: hasValue ? 0.4 : 0.12,
                ),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalorieProgressBar extends StatelessWidget {
  const _CalorieProgressBar({
    required this.consumed,
    required this.target,
    required this.goal,
  });

  final int consumed;
  final int target;
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final accent = _goalAccent(goal);
    final progress = (consumed / target).clamp(0.0, 1.2);
    final isOver = consumed > target;
    final diff = (consumed - target).abs();
    final barColor = isOver ? const Color(0xFFFF7043) : accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Kalori hedefi',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              isOver
                  ? '$diff kcal fazla'
                  : '$diff kcal kaldı',
              style: GoogleFonts.dmSans(
                color: isOver
                    ? const Color(0xFFFF7043)
                    : Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            // Background track
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            // Filled bar
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      barColor.withValues(alpha: 0.7),
                      barColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: barColor.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: -1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '$consumed kcal',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              'Hedef: $target kcal',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.38),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

Color _goalAccent(Goal goal) {
  switch (goal) {
    case Goal.bulk:
      return const Color(0xFFEBC374);
    case Goal.cut:
      return const Color(0xFF53D3B4);
    case Goal.strength:
      return const Color(0xFF73A7FF);
    case Goal.maintain:
      return const Color(0xFFB388FF);
  }
}
