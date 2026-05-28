import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../nutrition/presentation/state/diet_provider.dart';
import '../../weight/domain/entities/weight_entry.dart';
import '../../weight/presentation/providers/weight_provider.dart';

class TrackingChartEvent {
  const TrackingChartEvent({
    required this.date,
    required this.label,
    required this.color,
    required this.icon,
  });

  final DateTime date;
  final String label;
  final Color color;
  final IconData icon;
}

class NeonLineChart extends StatefulWidget {
  final WeightProvider provider;
  final int selectedFilterIndex;
  final List<TrackingChartEvent> events;

  const NeonLineChart({
    super.key,
    required this.provider,
    required this.selectedFilterIndex,
    this.events = const [],
  });

  @override
  State<NeonLineChart> createState() => _NeonLineChartState();
}

class _NeonLineChartState extends State<NeonLineChart> {
  int? _lastTouchedIndex;

  static double _chartHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final h = size.height;
    final ratio = (h > 700) ? 0.38 : (h > 600 ? 0.36 : 0.34);
    final height = (h * ratio).roundToDouble();
    return height.clamp(260.0, 340.0);
  }

  static double _bottomInterval(List<WeightEntry> chartEntries) {
    if (chartEntries.length < 2) return 1;
    final span =
        chartEntries.last.date.millisecondsSinceEpoch -
        chartEntries.first.date.millisecondsSinceEpoch;
    if (span <= 0) return 1;
    final days = span / (24 * 60 * 60 * 1000);
    if (days <= 7) return (span / 4).clamp(1, double.infinity);
    if (days <= 30) return (span / 5).clamp(1, double.infinity);
    return (span / 6).clamp(1, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    int days = 7;
    if (widget.selectedFilterIndex == 1) {
      days = 30;
    }
    if (widget.selectedFilterIndex == 2) {
      days = 90;
    }
    if (widget.selectedFilterIndex == 3) {
      days = 365 * 10;
    }

    final filtered = widget.provider.getFilteredEntries(days);

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

    final spots = chartEntries
        .map(
          (e) => FlSpot(e.date.millisecondsSinceEpoch.toDouble(), e.weightKg),
        )
        .toList();

    final avgSpots = <FlSpot>[];
    for (int i = 0; i < chartEntries.length; i++) {
      final start = (i - 6).clamp(0, i);
      final window = chartEntries.sublist(start, i + 1);
      final avg =
          window.fold<double>(0.0, (sum, e) => sum + e.weightKg) /
          window.length;
      avgSpots.add(
        FlSpot(chartEntries[i].date.millisecondsSinceEpoch.toDouble(), avg),
      );
    }

    final allY = [...spots.map((s) => s.y), ...avgSpots.map((s) => s.y)];
    final minY = allY.isEmpty
        ? 0.0
        : (allY.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final maxY = allY.isEmpty
        ? 100.0
        : (allY.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();
    final firstChartDay = DateTime(
      chartEntries.first.date.year,
      chartEntries.first.date.month,
      chartEntries.first.date.day,
    );
    final lastChartDay = DateTime(
      chartEntries.last.date.year,
      chartEntries.last.date.month,
      chartEntries.last.date.day,
    );
    final visibleEvents = widget.events.where((event) {
      final day = DateTime(event.date.year, event.date.month, event.date.day);
      return !day.isBefore(firstChartDay) && !day.isAfter(lastChartDay);
    }).toList();

    return SizedBox(
      height: chartHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Consumer<DietProvider>(
          builder: (context, dietProvider, _) {
            final targetWeight = dietProvider.profile?.targetWeight;
            final currentWeight = widget.provider.latestEntry?.weightKg;
            final weeklyChange = widget.provider.weeklyChange;
            
            FlSpot? predictionSpot;
            if (targetWeight != null && currentWeight != null && spots.isNotEmpty) {
              if (targetWeight < currentWeight && weeklyChange < -0.05) {
                final weeks = (currentWeight - targetWeight) / (-weeklyChange);
                if (weeks < 52) { // 1 yıl içinde
                  final predDate = DateTime.now().add(Duration(days: (weeks * 7).round()));
                  predictionSpot = FlSpot(predDate.millisecondsSinceEpoch.toDouble(), targetWeight);
                }
              } else if (targetWeight > currentWeight && weeklyChange > 0.05) {
                final weeks = (targetWeight - currentWeight) / weeklyChange;
                if (weeks < 52) {
                  final predDate = DateTime.now().add(Duration(days: (weeks * 7).round()));
                  predictionSpot = FlSpot(predDate.millisecondsSinceEpoch.toDouble(), targetWeight);
                }
              }
            }

            final minX = spots.first.x;
            final maxX = predictionSpot != null ? predictionSpot.x : spots.last.x;

            return LineChart(
              LineChartData(
                minX: minX,
                maxX: maxX,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withValues(alpha: 0.05),
                    strokeWidth: 1,
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  verticalLines: visibleEvents
                      .map(
                        (event) => VerticalLine(
                          x: DateTime(
                            event.date.year,
                            event.date.month,
                            event.date.day,
                          ).millisecondsSinceEpoch.toDouble(),
                          color: event.color.withValues(alpha: 0.28),
                          strokeWidth: 1,
                          dashArray: [3, 5],
                        ),
                      )
                      .toList(),
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
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: ((maxY - minY) / 4).roundToDouble().clamp(
                        0.5,
                        20,
                      ),
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            value.toStringAsFixed(0),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
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
                    shadow: const Shadow(
                      color: AppColors.primary,
                      blurRadius: 10,
                    ),
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
                  LineChartBarData(
                    spots: avgSpots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFFFFC107).withValues(alpha: 0.9),
                    barWidth: 2,
                    dashArray: [6, 4],
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  if (predictionSpot != null)
                    LineChartBarData(
                      spots: [spots.last, predictionSpot],
                      isCurved: false,
                      color: AppColors.primaryLight.withValues(alpha: 0.8),
                      barWidth: 2,
                      dashArray: [5, 5],
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          if (index == 0) return FlDotCirclePainter(radius: 0, color: Colors.transparent);
                          return FlDotCirclePainter(
                            radius: 4,
                            color: AppColors.surface,
                            strokeWidth: 2,
                            strokeColor: AppColors.primaryLight,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(show: false),
                    ),
                ],
                lineTouchData: LineTouchData(
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (touchResponse != null && touchResponse.lineBarSpots != null && touchResponse.lineBarSpots!.isNotEmpty) {
                      final spotIndex = touchResponse.lineBarSpots!.first.spotIndex;
                      if (_lastTouchedIndex != spotIndex) {
                        _lastTouchedIndex = spotIndex;
                        HapticFeedback.selectionClick();
                      }
                    } else if (event is FlPanEndEvent || event is FlTapUpEvent) {
                      _lastTouchedIndex = null;
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF2E3236),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final date = DateTime.fromMillisecondsSinceEpoch(
                          spot.x.toInt(),
                        );
                        final isAverageLine = spot.barIndex == 1;
                        return LineTooltipItem(
                          '${isAverageLine ? "Ort. " : ""}${spot.y.toStringAsFixed(1)} kg\n',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          children: [
                            TextSpan(
                              text: DateFormat(
                                'd MMM yyyy',
                                'tr_TR',
                              ).format(date),
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
