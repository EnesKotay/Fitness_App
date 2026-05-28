import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' show max;
import '../../../../core/models/workout.dart';
import '../../../../core/theme/app_colors.dart';

class MuscleRadarChart extends StatelessWidget {
  final List<Workout> workouts;

  const MuscleRadarChart({super.key, required this.workouts});

  @override
  Widget build(BuildContext context) {
    // 1. Calculate muscle group frequencies
    final Map<String, int> frequencies = {
      'Göğüs': 0, 'Sırt': 0, 'Bacak': 0, 'Omuz': 0, 'Kol': 0, 'Merkez': 0
    };

    for (var w in workouts) {
      final group = w.muscleGroup?.toLowerCase() ?? '';
      if (group.contains('göğüs') || group.contains('chest')) frequencies['Göğüs'] = frequencies['Göğüs']! + 1;
      else if (group.contains('sırt') || group.contains('back')) frequencies['Sırt'] = frequencies['Sırt']! + 1;
      else if (group.contains('bacak') || group.contains('leg')) frequencies['Bacak'] = frequencies['Bacak']! + 1;
      else if (group.contains('omuz') || group.contains('shoulder')) frequencies['Omuz'] = frequencies['Omuz']! + 1;
      else if (group.contains('kol') || group.contains('arm') || group.contains('biceps') || group.contains('triceps')) frequencies['Kol'] = frequencies['Kol']! + 1;
      else if (group.contains('merkez') || group.contains('core') || group.contains('karın') || group.contains('abs')) frequencies['Merkez'] = frequencies['Merkez']! + 1;
    }

    final maxVal = frequencies.values.fold(0, (a, b) => max(a, b)).toDouble();
    
    // Check if there's any data
    if (maxVal == 0) return const SizedBox.shrink();

    return Container(
      height: 250,
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
              const Icon(Icons.radar_rounded, color: AppColors.primaryLight, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Kas Grubu Dengesi',
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
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    fillColor: AppColors.primary.withValues(alpha: 0.3),
                    borderColor: AppColors.primary,
                    entryRadius: 3,
                    dataEntries: [
                      RadarEntry(value: frequencies['Göğüs']!.toDouble()),
                      RadarEntry(value: frequencies['Sırt']!.toDouble()),
                      RadarEntry(value: frequencies['Bacak']!.toDouble()),
                      RadarEntry(value: frequencies['Omuz']!.toDouble()),
                      RadarEntry(value: frequencies['Kol']!.toDouble()),
                      RadarEntry(value: frequencies['Merkez']!.toDouble()),
                    ],
                    borderWidth: 2,
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.white12, width: 1.5),
                titlePositionPercentageOffset: 0.2,
                titleTextStyle: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                getTitle: (index, angle) {
                  switch (index) {
                    case 0: return const RadarChartTitle(text: 'Göğüs');
                    case 1: return const RadarChartTitle(text: 'Sırt');
                    case 2: return const RadarChartTitle(text: 'Bacak');
                    case 3: return const RadarChartTitle(text: 'Omuz');
                    case 4: return const RadarChartTitle(text: 'Kol');
                    case 5: return const RadarChartTitle(text: 'Merkez');
                    default: return const RadarChartTitle(text: '');
                  }
                },
                tickCount: 3,
                ticksTextStyle: const TextStyle(color: Colors.transparent),
                tickBorderData: const BorderSide(color: Colors.white12, width: 1),
                gridBorderData: const BorderSide(color: Colors.white12, width: 1),
              ),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutQuart,
            ),
          ),
        ],
      ),
    );
  }
}
