import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/tracking_provider.dart';

/// Bu Hafta Özeti kartı — Performans sekmesinin tepesinde gösterilir.
/// Kilo değişimi, antrenman sayısı, ölçüm sayısı ve streak verilerini özetler.
class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<WeightProvider, WorkoutProvider, TrackingProvider>(
      builder: (context, weightProv, workoutProv, trackingProv, _) {
        final weeklyChange = weightProv.weeklyChange;
        final streak = weightProv.currentStreak;

        // Bu haftaki antrenmanlar
        final cutoff = DateTime.now().subtract(const Duration(days: 7));
        final weeklyWorkouts = workoutProv.workouts
            .where((w) => w.workoutDate.isAfter(cutoff))
            .length;

        // Bu haftaki vücut ölçümleri
        final weeklyMeasurements = trackingProv.bodyMeasurements
            .where((m) => m.date.isAfter(cutoff))
            .length;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Başlık ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        size: 15,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Bu Hafta Özeti',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // ── İnce gradient ayırıcı çizgi ─────────────────────────────
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.40),
                      AppColors.primaryLight.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // ── 4 stat kutusu ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Row(
                  children: [
                    _StatBox(
                      label: 'Kilo Δ',
                      value: weeklyChange == 0
                          ? '—'
                          : '${weeklyChange > 0 ? '+' : ''}${weeklyChange.toStringAsFixed(1)} kg',
                      valueColor: weeklyChange < 0
                          ? AppColors.primaryLight
                          : weeklyChange > 0
                              ? AppColors.warning
                              : Colors.white54,
                      icon: weeklyChange < 0
                          ? Icons.trending_down_rounded
                          : weeklyChange > 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_flat_rounded,
                      iconColor: weeklyChange < 0
                          ? AppColors.primaryLight
                          : weeklyChange > 0
                              ? AppColors.warning
                              : Colors.white38,
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'Antrenman',
                      value: weeklyWorkouts > 0 ? '$weeklyWorkouts seans' : '—',
                      valueColor: weeklyWorkouts > 0
                          ? const Color(0xFF64D2FF)
                          : Colors.white38,
                      icon: Icons.fitness_center_rounded,
                      iconColor: const Color(0xFF64D2FF),
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'Ölçüm',
                      value: weeklyMeasurements > 0
                          ? '$weeklyMeasurements kayıt'
                          : '—',
                      valueColor: weeklyMeasurements > 0
                          ? const Color(0xFFFFA56E)
                          : Colors.white38,
                      icon: Icons.straighten_rounded,
                      iconColor: const Color(0xFFFFA56E),
                    ),
                    const SizedBox(width: 8),
                    _StatBox(
                      label: 'Seri',
                      value: streak > 0 ? '$streak gün' : '—',
                      valueColor: streak >= 3
                          ? const Color(0xFFFFB300)
                          : streak > 0
                              ? Colors.white70
                              : Colors.white38,
                      icon: Icons.local_fire_department_rounded,
                      iconColor: streak >= 3
                          ? const Color(0xFFFFB300)
                          : Colors.white38,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tek bir mini stat kutusu
class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final IconData icon;
  final Color iconColor;

  const _StatBox({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
