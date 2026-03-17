import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/body_measurement.dart';
import '../providers/tracking_provider.dart';

class MeasurementTrendChart extends StatefulWidget {
  const MeasurementTrendChart({super.key});

  @override
  State<MeasurementTrendChart> createState() => _MeasurementTrendChartState();
}

class _MeasurementTrendChartState extends State<MeasurementTrendChart> {
  // Available measurements to chart
  final Map<String, String> _measurementTypes = {
    'chest': 'Göğüs',
    'waist': 'Bel',
    'hips': 'Kalça',
    'leftArm': 'S. Kol',
    'rightArm': 'Sğ. Kol',
    'leftLeg': 'S. Bacak',
    'rightLeg': 'Sğ. Bacak',
  };

  String _selectedType = 'waist'; // Default to waist

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.bodyMeasurements.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final measurements = provider.bodyMeasurements.toList();
        
        if (measurements.isEmpty) {
          return const SizedBox.shrink(); 
        }

        // Sort by date ascending for the chart
        measurements.sort((a, b) => a.date.compareTo(b.date));

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.straighten_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      const Text(
                        'Ölçüm Trendi',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  _buildDropdown(),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 220,
                child: _buildChart(measurements),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primaryLight, size: 20),
          dropdownColor: AppColors.surface,
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          onChanged: (String? newValue) {
            if (newValue != null) {
              setState(() => _selectedType = newValue);
            }
          },
          items: _measurementTypes.entries.map<DropdownMenuItem<String>>((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChart(List<BodyMeasurement> measurements) {
    // Filter out entries where the selected measurement is null
    final validData = measurements.where((m) => _getValue(m, _selectedType) != null).toList();

    if (validData.isEmpty) {
      return Center(
        child: Text(
          'Bu bölge için henüz veri yok.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    if (validData.length == 1) {
      return Center(
        child: Text(
          'Grafik için en az 2 kayıt gerekiyor.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    final spots = validData.asMap().entries.map((e) {
      final value = _getValue(e.value, _selectedType)!;
      return FlSpot(e.key.toDouble(), value);
    }).toList();

    double minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    double maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    
    // Add some padding to Y axis
    final yRange = maxY - minY;
    if (yRange == 0) {
      minY -= 5;
      maxY += 5;
    } else {
      minY -= (yRange * 0.2);
      maxY += (yRange * 0.2);
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.05),
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= validData.length) return const SizedBox();
                
                // Sadece başı, ortası ve sonu göster ki çok sıkışmasın
                if (validData.length > 5) {
                  if (index != 0 && index != validData.length - 1 && index != validData.length ~/ 2) {
                    return const SizedBox();
                  }
                }
                
                final date = validData[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    DateFormat('d MMM', 'tr_TR').format(date),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (maxY - minY) / 4,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (validData.length - 1).toDouble(),
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
            dotData: const FlDotData(show: false),
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
            tooltipRoundedRadius: 8,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final date = validData[spot.x.toInt()].date;
                final dateStr = DateFormat('d MMM', 'tr_TR').format(date);
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} cm\n$dateStr',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  double? _getValue(BodyMeasurement m, String type) {
    switch (type) {
      case 'chest': return m.chest;
      case 'waist': return m.waist;
      case 'hips': return m.hips;
      case 'leftArm': return m.leftArm;
      case 'rightArm': return m.rightArm;
      case 'leftLeg': return m.leftLeg;
      case 'rightLeg': return m.rightLeg;
      default: return null;
    }
  }
}
