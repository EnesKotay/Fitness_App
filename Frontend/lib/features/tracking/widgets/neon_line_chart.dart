import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/presentation/providers/weight_provider.dart';

class NeonLineChart extends StatelessWidget {
  final WeightProvider provider;
  final int selectedFilterIndex;

  const NeonLineChart({
    super.key,
    required this.provider,
    required this.selectedFilterIndex,
  });

  static double _chartHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final h = size.height;
    final ratio = (h > 700) ? 0.38 : (h > 600 ? 0.36 : 0.34);
    final height = (h * ratio).roundToDouble();
    return height.clamp(260.0, 340.0);
  }

  static double _bottomInterval(List<WeightEntry> chartEntries) {
    if (chartEntries.length < 2) return 1;
    final span = chartEntries.last.date.millisecondsSinceEpoch -
        chartEntries.first.date.millisecondsSinceEpoch;
    final days = span / (24 * 60 * 60 * 1000);
    if (days <= 7) return span / 4;
    if (days <= 30) return span / 5;
    return span / 6;
  }

  @override
  Widget build(BuildContext context) {
    // Data preparation now delegates to Provider (or assumes Provider has sorted data)
    int days = 7;
    if (selectedFilterIndex == 1) days = 30;
    if (selectedFilterIndex == 2) days = 90;

    // Utilize helpers - provider entries are already sorted newest first by default in our update
    // But for chart we often need Oldest -> Newest to draw left to right.
    final filtered = provider.getFilteredEntries(days);
    
    // Reverse for Chart (Left=Old, Right=New)
    // We create a new list to avoid mutating the provider's list if we were using it directly
    final chartEntries = List<WeightEntry>.from(filtered.reversed);

    final chartHeight = _chartHeight(context);

    if (chartEntries.length < 2) {
      return SizedBox(
        height: chartHeight,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.show_chart,
                color: AppColors.textTertiary,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                chartEntries.isEmpty
                    ? 'Bu aralıkta veri yok'
                    : 'Grafik için en az 2 gün gerekli',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final weights = chartEntries.map((e) => e.weightKg).toList();
    final minY = weights.isEmpty ? 0.0 : (weights.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxY = weights.isEmpty ? 100.0 : (weights.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();
    
    final spots = chartEntries
        .map(
          (e) => FlSpot(e.date.millisecondsSinceEpoch.toDouble(), e.weightKg),
        )
        .toList();

    return SizedBox(
      height: chartHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Consumer<DietProvider>(
          builder: (context, dietProvider, _) {
            final targetWeight = dietProvider.profile?.targetWeight;
            
            return LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (targetWeight != null)
                    HorizontalLine(
                      y: targetWeight,
                      color: AppColors.primary.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 5, bottom: 5),
                        style: TextStyle(
                          color: AppColors.primary.withValues(alpha: 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        labelResolver: (line) => 'Hedef',
                      ),
                    ),
                ],
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        value.toInt(),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('d/M').format(date),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                    interval: _bottomInterval(chartEntries),
                    reservedSize: 28,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppColors.primary,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  shadow: const Shadow(color: AppColors.primary, blurRadius: 10),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: AppColors.primary,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.3),
                        AppColors.primary.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipBgColor: const Color(0xFF2E3236),
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final date = DateTime.fromMillisecondsSinceEpoch(
                        spot.x.toInt(),
                      );
                      return LineTooltipItem(
                        '${spot.y} kg\n',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: DateFormat('d MMM yyyy', 'tr_TR').format(date),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}
