import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/body_measurement.dart';
import '../providers/tracking_provider.dart';

/// Upgraded measurement trend chart with:
/// - Horizontal chip selector (not dropdown)
/// - Animated line with glow effect
/// - Min/max annotation
/// - Current value badge on last data point
class MeasurementTrendChart extends StatefulWidget {
  const MeasurementTrendChart({super.key});

  @override
  State<MeasurementTrendChart> createState() => _MeasurementTrendChartState();
}

class _MeasurementTrendChartState extends State<MeasurementTrendChart>
    with SingleTickerProviderStateMixin {
  static const _types = [
    _TypeDef('waist', 'Bel', Color(0xFFFF6B6B)),
    _TypeDef('chest', 'Göğüs', Color(0xFF64D2FF)),
    _TypeDef('hips', 'Kalça', Color(0xFFFF9F43)),
    _TypeDef('leftArm', 'Sol Kol', Color(0xFF48BB78)),
    _TypeDef('rightArm', 'Sağ Kol', Color(0xFF48BB78)),
    _TypeDef('leftLeg', 'Sol Bacak', Color(0xFFA78BFA)),
    _TypeDef('rightLeg', 'Sağ Bacak', Color(0xFFA78BFA)),
  ];

  String _selectedKey = 'waist';
  late AnimationController _lineCtrl;
  late Animation<double> _lineAnim;

  @override
  void initState() {
    super.initState();
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _lineAnim = CurvedAnimation(parent: _lineCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _lineCtrl.dispose();
    super.dispose();
  }

  void _select(String key) {
    if (_selectedKey == key) return;
    setState(() => _selectedKey = key);
    _lineCtrl
      ..reset()
      ..forward();
  }

  _TypeDef get _current => _types.firstWhere((t) => t.key == _selectedKey);

  double? _getVal(BodyMeasurement m, String key) {
    switch (key) {
      case 'chest':
        return m.chest;
      case 'waist':
        return m.waist;
      case 'hips':
        return m.hips;
      case 'leftArm':
        return m.leftArm;
      case 'rightArm':
        return m.rightArm;
      case 'leftLeg':
        return m.leftLeg;
      case 'rightLeg':
        return m.rightLeg;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.bodyMeasurements.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final sorted = [...provider.bodyMeasurements]
          ..sort((a, b) => a.date.compareTo(b.date));
        if (sorted.isEmpty) return const SizedBox.shrink();

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.07),
                Colors.white.withValues(alpha: 0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title row ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _current.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        color: _current.color,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Ölçüm Trendi · ${_current.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Chip selector ─────────────────────────────────────────────
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _types.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final t = _types[i];
                    final isSelected = t.key == _selectedKey;
                    return GestureDetector(
                      onTap: () => _select(t.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? t.color.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? t.color.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            t.label,
                            style: TextStyle(
                              color: isSelected ? t.color : Colors.white38,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // ── Chart ─────────────────────────────────────────────────────
              SizedBox(
                height: 200,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, left: 4, bottom: 4),
                  child: _buildChart(sorted),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChart(List<BodyMeasurement> measurements) {
    final valid = measurements
        .where((m) => _getVal(m, _selectedKey) != null)
        .toList();

    if (valid.isEmpty) {
      return Center(
        child: Text(
          'Bu bölge için henüz veri yok.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      );
    }
    if (valid.length == 1) {
      return Center(
        child: Text(
          'Grafik için en az 2 kayıt gerekiyor.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        ),
      );
    }

    final spots = valid.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), _getVal(e.value, _selectedKey)!);
    }).toList();

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    if (range < 1) {
      minY -= 5;
      maxY += 5;
    } else {
      minY -= range * 0.25;
      maxY += range * 0.25;
    }

    final color = _current.color;

    return AnimatedBuilder(
      animation: _lineAnim,
      builder: (_, _) => LineChart(
        LineChartData(
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.05),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= valid.length) return const SizedBox();
                  if (valid.length > 5) {
                    if (idx != 0 &&
                        idx != valid.length - 1 &&
                        idx != valid.length ~/ 2) {
                      return const SizedBox();
                    }
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('d MMM', 'tr_TR').format(valid[idx].date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.40),
                        fontSize: 10,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: (maxY - minY) / 4,
                getTitlesWidget: (value, _) => Text(
                  value.toStringAsFixed(0),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (valid.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.4,
              color: color,
              barWidth: 2.5,
              isStrokeCapRound: true,
              shadow: Shadow(
                color: color.withValues(alpha: 0.45 * _lineAnim.value),
                blurRadius: 10,
              ),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, pct, bar, idx) {
                  final isLast = idx == spots.length - 1;
                  return FlDotCirclePainter(
                    radius: isLast ? 5 : 3,
                    color: isLast ? color : color.withValues(alpha: 0.6),
                    strokeWidth: isLast ? 2 : 0,
                    strokeColor: Colors.white.withValues(alpha: 0.8),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.25 * _lineAnim.value),
                    color.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipBorder: BorderSide(color: color.withValues(alpha: 0.4)),
              getTooltipItems: (spots) => spots.map((spot) {
                final date = valid[spot.x.toInt()].date;
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} cm\n',
                  TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                  children: [
                    TextSpan(
                      text: DateFormat('d MMM yyyy', 'tr_TR').format(date),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeDef {
  final String key;
  final String label;
  final Color color;
  const _TypeDef(this.key, this.label, this.color);
}
