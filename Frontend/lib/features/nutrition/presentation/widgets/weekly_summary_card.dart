import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/diary_repository.dart';
import '../../services/pdf_service.dart';

/// Son 7 günlük kalori özetini çubuk grafik olarak gösteren kart.
class WeeklySummaryCard extends StatelessWidget {
  final Map<String, DiaryTotals> weeklyData;
  final double dailyTarget;

  const WeeklySummaryCard({
    super.key,
    required this.weeklyData,
    required this.dailyTarget,
  });

  @override
  Widget build(BuildContext context) {
    if (weeklyData.isEmpty) return const SizedBox.shrink();

    final sortedKeys = weeklyData.keys.toList()..sort();
    final values = sortedKeys.map((k) => weeklyData[k]!.totalKcal).toList();
    final total = values.fold(0.0, (a, b) => a + b);
    final avg = values.isNotEmpty ? total / values.length : 0.0;
    final hasData = total > 0;

    // Veri yokken güzel bir empty state göster
    if (!hasData) {
      return _buildEmptyState(sortedKeys);
    }

    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.where((v) => v > 0).isNotEmpty
        ? values.where((v) => v > 0).reduce((a, b) => a < b ? a : b)
        : 0.0;
    final chartMax = (maxVal > dailyTarget ? maxVal : dailyTarget) * 1.2;
    final activeDays = values.where((v) => v > 0).length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.chartGreen.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.03),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.chartGreen.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.chartGreen.withValues(alpha: 0.25),
                          AppColors.chartGreen.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      size: 22,
                      color: Color(0xFF4CD1A3),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Haftalık Özet',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$activeDays gün aktif • Ort: ${avg.round()} kcal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Export PDF Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        PdfService.generateAndShareWeeklyReport(
                          weeklyData,
                          dailyTarget,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.file_download_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Mini stats row
              Row(
                children: [
                  _miniStat(
                    'En Yüksek',
                    '${maxVal.round()}',
                    Icons.arrow_upward_rounded,
                    AppColors.chartRed,
                  ),
                  const SizedBox(width: 8),
                  _miniStat(
                    'En Düşük',
                    '${minVal.round()}',
                    Icons.arrow_downward_rounded,
                    AppColors.chartBlue,
                  ),
                  const SizedBox(width: 8),
                  _miniStat(
                    'Hedef',
                    '${dailyTarget.round()}',
                    Icons.flag_rounded,
                    AppColors.secondary,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Bar chart
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    maxY: chartMax,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor:
                            AppColors.surface.withValues(alpha: 0.95),
                        tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        tooltipRoundedRadius: 10,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final dayStr = sortedKeys[groupIndex];
                          final parts = dayStr.split('-');
                          final label = parts.length >= 3
                              ? '${parts[2]}/${parts[1]}'
                              : dayStr;
                          return BarTooltipItem(
                            '$label\n',
                            TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 10,
                            ),
                            children: [
                              TextSpan(
                                text: '${rod.toY.round()} kcal',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= sortedKeys.length) {
                              return const SizedBox.shrink();
                            }
                            final dayStr = sortedKeys[idx];
                            final parts = dayStr.split('-');
                            // Gün isimleri
                            final date = DateTime.tryParse(dayStr);
                            String label;
                            if (date != null) {
                              const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                              label = days[date.weekday - 1];
                            } else {
                              label = parts.length >= 3
                                  ? '${parts[2]}/${parts[1]}'
                                  : dayStr;
                            }
                            final isToday = idx == sortedKeys.length - 1;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: isToday
                                      ? AppColors.chartGreen
                                      : Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                  fontWeight: isToday
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: dailyTarget > 0 ? dailyTarget : 2000,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: AppColors.secondary.withValues(alpha: 0.25),
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                        );
                      },
                    ),
                    barGroups: List.generate(sortedKeys.length, (i) {
                      final val = values[i];
                      final isOver = val > dailyTarget;
                      final isToday = i == sortedKeys.length - 1;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: val > 0 ? val : 0,
                            width: isToday ? 28 : 22,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8)),
                            gradient: LinearGradient(
                              colors: isOver
                                  ? [
                                      AppColors.chartRed,
                                      AppColors.chartRed
                                          .withValues(alpha: 0.6),
                                    ]
                                  : isToday
                                      ? [
                                          AppColors.chartGreen,
                                          AppColors.chartGreen
                                              .withValues(alpha: 0.6),
                                        ]
                                      : [
                                          AppColors.secondary,
                                          AppColors.secondary
                                              .withValues(alpha: 0.5),
                                        ],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: chartMax,
                              color: Colors.white.withValues(alpha: 0.03),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOut);
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(List<String> sortedKeys) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.chartGreen.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.02),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.chartGreen.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            children: [
              // Animated icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.chartGreen.withValues(alpha: 0.2),
                      AppColors.chartGreen.withValues(alpha: 0.05),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  size: 32,
                  color: Color(0xFF4CD1A3),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.08, 1.08),
                    duration: 1500.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 16),
              const Text(
                'Haftalık Özet',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Henüz bu hafta yemek kaydı yok.\nİlk öğününü ekleyerek grafiğini oluştur! 🍽️',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(height: 16),
              // Mini placeholder bars
              SizedBox(
                height: 50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final heights = [18.0, 30.0, 22.0, 38.0, 15.0, 42.0, 28.0];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        width: 16,
                        height: heights[i],
                        decoration: BoxDecoration(
                          color: AppColors.chartGreen.withValues(alpha: 0.1),
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    );
                  }),
                ),
              )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .shimmer(
                    duration: 2000.ms,
                    color: AppColors.chartGreen.withValues(alpha: 0.15),
                  ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOut);
  }
}
