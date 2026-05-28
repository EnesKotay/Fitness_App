import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/models/workout.dart';

class VolumeTrendChart extends StatelessWidget {
  final List<Workout> workouts;

  const VolumeTrendChart({super.key, required this.workouts});

  double _workoutVolume(Workout workout) {
    final details = workout.setDetails;
    if (details != null && details.isNotEmpty) {
      return details.fold<double>(0, (sum, set) {
        final reps = set.reps ?? workout.reps ?? 0;
        final weight = set.weight ?? workout.weight ?? 0;
        return sum + (reps * weight);
      });
    }
    return (workout.weight ?? 0) * (workout.sets ?? 1) * (workout.reps ?? 1);
  }

  @override
  Widget build(BuildContext context) {
    if (workouts.isEmpty) return const SizedBox.shrink();

    final Map<DateTime, double> dailyVolume = {};
    for (var w in workouts) {
      final date = DateTime(w.workoutDate.year, w.workoutDate.month, w.workoutDate.day);
      dailyVolume[date] = (dailyVolume[date] ?? 0) + _workoutVolume(w);
    }

    final sortedDates = dailyVolume.keys.toList()..sort();
    final spots = <FlSpot>[];
    
    // Take the last 14 active days
    final displayDates = sortedDates.length > 14 ? sortedDates.sublist(sortedDates.length - 14) : sortedDates;
    
    if (displayDates.length < 2) return const SizedBox.shrink();

    double minVol = double.infinity;
    double maxVol = -double.infinity;

    for (int i = 0; i < displayDates.length; i++) {
      final vol = dailyVolume[displayDates[i]]! / 1000.0; // Ton
      spots.add(FlSpot(i.toDouble(), vol));
      if (vol < minVol) minVol = vol;
      if (vol > maxVol) maxVol = vol;
    }

    final yInterval = ((maxVol - minVol) / 3).clamp(0.5, double.infinity).toDouble();

    return Container(
      height: 230,
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
              const Icon(Icons.show_chart_rounded, color: Color(0xFF64D2FF), size: 18),
              const SizedBox(width: 8),
              const Text(
                'Hacim Trendi (Ton)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.1),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= displayDates.length) return const SizedBox.shrink();
                        if (idx == 0 || idx == displayDates.length - 1 || idx == displayDates.length ~/ 2) {
                           return Padding(
                             padding: const EdgeInsets.only(top: 8.0),
                             child: Text(
                               DateFormat('d MMM', 'tr_TR').format(displayDates[idx]),
                               style: const TextStyle(color: Colors.white54, fontSize: 10),
                             ),
                           );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (displayDates.length - 1).toDouble(),
                minY: (minVol - yInterval).clamp(0, double.infinity).toDouble(),
                maxY: maxVol + yInterval,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF64D2FF),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF64D2FF).withValues(alpha: 0.3),
                          const Color(0xFF64D2FF).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => Colors.black87,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.toStringAsFixed(1)} Ton',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
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
