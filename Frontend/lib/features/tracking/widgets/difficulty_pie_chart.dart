import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/models/workout.dart';
import '../../../../core/theme/app_colors.dart';

class DifficultyPieChart extends StatelessWidget {
  final List<Workout> workouts;

  const DifficultyPieChart({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const SizedBox.shrink();

    int light = 0;
    int medium = 0;
    int hard = 0;
    int extreme = 0;

    for (var w in workouts) {
      final diff = w.difficulty?.toLowerCase() ?? '';
      if (diff.contains('çok zor') || diff.contains('extreme') || diff.contains('çok ağır')) extreme++;
      else if (diff.contains('zor') || diff.contains('hard') || diff.contains('ağır')) hard++;
      else if (diff.contains('hafif') || diff.contains('light') || diff.contains('kolay')) light++;
      else medium++; // default
    }

    final total = light + medium + hard + extreme;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_rounded, color: AppColors.primaryLight, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Zorluk Dağılımı',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 25,
                      sections: [
                        if (light > 0)
                          PieChartSectionData(
                            color: const Color(0xFF30D158), // Green
                            value: light.toDouble(),
                            title: '${((light / total) * 100).round()}%',
                            radius: 30,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (medium > 0)
                          PieChartSectionData(
                            color: const Color(0xFF0A84FF), // Blue
                            value: medium.toDouble(),
                            title: '${((medium / total) * 100).round()}%',
                            radius: 35,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (hard > 0)
                          PieChartSectionData(
                            color: const Color(0xFFFF9F0A), // Orange
                            value: hard.toDouble(),
                            title: '${((hard / total) * 100).round()}%',
                            radius: 40,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        if (extreme > 0)
                          PieChartSectionData(
                            color: const Color(0xFFFF453A), // Red
                            value: extreme.toDouble(),
                            title: '${((extreme / total) * 100).round()}%',
                            radius: 45,
                            titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutQuart,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (light > 0) ...[
                        _indicator(color: const Color(0xFF30D158), text: 'Hafif ($light)'),
                        const SizedBox(height: 6),
                      ],
                      if (medium > 0) ...[
                        _indicator(color: const Color(0xFF0A84FF), text: 'Orta ($medium)'),
                        const SizedBox(height: 6),
                      ],
                      if (hard > 0) ...[
                        _indicator(color: const Color(0xFFFF9F0A), text: 'Zor ($hard)'),
                        const SizedBox(height: 6),
                      ],
                      if (extreme > 0) ...[
                        _indicator(color: const Color(0xFFFF453A), text: 'Çok Zor ($extreme)'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicator({required Color color, required String text}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
