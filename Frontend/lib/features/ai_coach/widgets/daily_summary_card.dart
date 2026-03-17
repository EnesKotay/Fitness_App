import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../nutrition/domain/entities/user_profile.dart';
import '../models/ai_coach_models.dart';

class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({
    super.key,
    required this.goal,
    required this.summary,
  });

  final Goal goal;
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Adım', '${summary.steps}', Icons.directions_walk_rounded),
      ('Kalori', '${summary.calories} kcal', Icons.local_fire_department_rounded),
      ('Su', '${summary.waterLiters} L', Icons.water_drop_rounded),
      ('Uyku', '${summary.sleepHours} sa', Icons.dark_mode_rounded),
      ('Antrenman', '${summary.workouts}', Icons.fitness_center_rounded),
      ('Süre', '${summary.workoutMinutes} dk', Icons.timer_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF111827).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugünkü özet',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Koç önerileri bu verileri baz alır.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.58),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: _goalAccent(goal).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _goalAccent(goal).withValues(alpha: 0.32)),
                ),
                child: Text(
                  goal.label,
                  style: GoogleFonts.dmSans(
                    color: _goalAccent(goal),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.35,
            ),
            itemBuilder: (context, index) {
              final metric = metrics[index];
              return _MetricTile(
                label: metric.$1,
                value: metric.$2,
                icon: metric.$3,
              );
            },
          ),
          if (summary.workoutHighlights.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Öne çıkan hareketler',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summary.workoutHighlights
                  .take(4)
                  .map(
                    (name) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1220),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        name,
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.76),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.72)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
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

Color _goalAccent(Goal goal) {
  switch (goal) {
    case Goal.bulk:
      return const Color(0xFFF0B54C);
    case Goal.cut:
      return const Color(0xFF53D3B4);
    case Goal.strength:
      return const Color(0xFF73A7FF);
    case Goal.maintain:
      return const Color(0xFFB388FF);
  }
}
