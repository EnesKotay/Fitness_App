import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../workout/providers/workout_provider.dart';
import '../../../core/models/workout.dart';

/// Son 10 antrenmanı listeleyen premium kart.
/// Performans sekmesinde `_PeriodizationCard`'dan önce gösterilir.
class WorkoutHistoryCard extends StatelessWidget {
  const WorkoutHistoryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WorkoutProvider>(
      builder: (context, wp, _) {
        final sorted = [...wp.workouts]
          ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
        final recent = sorted.take(10).toList();

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Başlık ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFFFFA56E).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 15,
                        color: Color(0xFFFFA56E),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Antrenman Geçmişi',
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

              // ── İnce gradient ayırıcı çizgi ──────────────────────────────
              Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFA56E).withValues(alpha: 0.35),
                      const Color(0xFFFFA56E).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 4),

              // ── İçerik ────────────────────────────────────────────────────
              if (recent.isEmpty)
                _buildEmptyState()
              else
                ...recent.asMap().entries.map(
                      (e) => _WorkoutRow(
                        workout: e.value,
                        isLast: e.key == recent.length - 1,
                      ),
                    ),

              // ── Tüm Geçmişi Gör butonu ────────────────────────────────────
              if (recent.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: GestureDetector(
                    onTap: () {
                      // İleride antrenman geçmiş sayfasına yönlendirme
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.list_rounded,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tüm Geçmişi Gör',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 36,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 12),
          Text(
            'Henüz antrenman kaydı yok',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'İlk antrenmanını kaydettiğinde burada görünecek',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.22),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tek bir antrenman satırı
class _WorkoutRow extends StatelessWidget {
  final Workout workout;
  final bool isLast;

  const _WorkoutRow({required this.workout, required this.isLast});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFFA56E);
    final hasWeight = workout.weight != null && workout.weight! > 0;
    final hasSets = workout.sets != null;
    final hasReps = workout.reps != null;
    final hasCalories =
        workout.caloriesBurned != null && workout.caloriesBurned! > 0;

    // Performans etiketi oluştur
    String? perfLabel;
    if (hasWeight && hasSets && hasReps) {
      perfLabel =
          '${workout.weight!.truncateToDouble() == workout.weight! ? workout.weight!.toInt() : workout.weight!.toStringAsFixed(1)} kg'
          ' × ${workout.sets} × ${workout.reps}';
    } else if (hasSets && hasReps) {
      perfLabel = '${workout.sets} × ${workout.reps} tekrar';
    } else if (hasSets) {
      perfLabel = '${workout.sets} set';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // ── Tarih kutusu ─────────────────────────────────────────────
            Container(
              width: 42,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('d').format(workout.workoutDate),
                    style: const TextStyle(
                      color: AppColors.primaryLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    DateFormat('MMM', 'tr_TR').format(workout.workoutDate),
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.7),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Egzersiz adı + performans ─────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workout.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (perfLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      perfLabel,
                      style: TextStyle(
                        color: hasWeight
                            ? orange
                            : Colors.white.withValues(alpha: 0.45),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Kalori ───────────────────────────────────────────────────
            if (hasCalories) ...[
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${workout.caloriesBurned} kcal',
                    style: TextStyle(
                      color: const Color(0xFF30D158).withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'yakım',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 9,
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
}
