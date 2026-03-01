import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ai_coach_models.dart';
import 'coach_premium_panel.dart';

class DailySummaryCard extends StatelessWidget {
  const DailySummaryCard({
    super.key,
    required this.goal,
    required this.summary,
  });

  final CoachGoal goal;
  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return CoachPremiumPanel(
      baseColor: const Color(0xFF141F37),
      edgeColor: const Color(0xFF3B4F7A),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF63B6FF).withValues(alpha: 0.4),
                      const Color(0xFF63B6FF).withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFF6EBAFF)),
                ),
                child: const Icon(
                  Icons.monitor_heart_outlined,
                  color: Color(0xFFABDCFF),
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Gunluk Ozet',
                style: GoogleFonts.cormorantGaramond(
                  color: const Color(0xFFF2ECD8),
                  fontWeight: FontWeight.w700,
                  fontSize: 27,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFEBC271).withValues(alpha: 0.5),
                  ),
                  color: const Color(0xFF2A1F0A).withValues(alpha: 0.65),
                ),
                child: Text(
                  goal.label.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFF1CD88),
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Hedef: ${goal.label}',
            style: GoogleFonts.dmSans(
              color: const Color(0xFFD5E2FF),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final compact = width < 350;
              final tileWidth = compact ? (width - 10) / 2 : (width - 20) / 3;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(
                    width: tileWidth,
                    label: 'Adim',
                    value: '${summary.steps}',
                    icon: Icons.directions_walk_rounded,
                  ),
                  _Metric(
                    width: tileWidth,
                    label: 'Kalori',
                    value: '${summary.calories} kcal',
                    icon: Icons.local_fire_department_rounded,
                  ),
                  _Metric(
                    width: tileWidth,
                    label: 'Su',
                    value: '${summary.waterLiters} L',
                    icon: Icons.water_drop_rounded,
                  ),
                  _Metric(
                    width: tileWidth,
                    label: 'Uyku',
                    value: '${summary.sleepHours} sa',
                    icon: Icons.dark_mode_rounded,
                  ),
                  _Metric(
                    width: tileWidth,
                    label: 'Antrenman',
                    value: '${summary.workouts}',
                    icon: Icons.fitness_center_rounded,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF121C32).withValues(alpha: 0.98),
            const Color(0xFF0D1528).withValues(alpha: 0.98),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF32476E)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A2A49),
              border: Border.all(color: const Color(0xFF405A89)),
            ),
            child: Icon(icon, size: 13, color: const Color(0xFF9FC0F8)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF9FB1D5),
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFFE4ECFF),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
