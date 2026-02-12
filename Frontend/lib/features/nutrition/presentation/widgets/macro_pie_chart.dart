import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class MacroPieChart extends StatefulWidget {
  final double proteinG;
  final double carbG;
  final double fatG;
  final bool animate;
  final double size;

  const MacroPieChart({
    super.key,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
    this.animate = true,
    this.size = 160,
  });

  @override
  State<MacroPieChart> createState() => _MacroPieChartState();
}

class _MacroPieChartState extends State<MacroPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // Kalori hesabı: Protein(4), Carb(4), Fat(9)
    final pKcal = widget.proteinG * 4;
    final cKcal = widget.carbG * 4;
    final fKcal = widget.fatG * 9;
    final totalKcal = pKcal + cKcal + fKcal;
    
    // Veri yoksa boş state
    if (totalKcal == 0) {
      return SizedBox(
        height: widget.size,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pie_chart_outline, size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 8),
              Text('Veri yok', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        // Pie Chart
        Expanded(
          flex: 3,
          child: SizedBox(
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedIndex = -1;
                            return;
                          }
                          _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: _showingSections(pKcal, cKcal, fKcal, totalKcal),
                  ),
                  swapAnimationDuration: const Duration(milliseconds: 600),
                  swapAnimationCurve: Curves.easeInOutQuint,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${totalKcal.round()}',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Legend
        Expanded(
          flex: 2,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LegendItem(
                color: const Color(0xFF4CAF50),
                label: 'Protein',
                value: '${widget.proteinG.round()}g',
                percentage: totalKcal > 0 ? (pKcal / totalKcal * 100).round() : 0,
                isTouched: _touchedIndex == 0,
              ),
              const SizedBox(height: 12),
              _LegendItem(
                color: const Color(0xFF2196F3),
                label: 'Karb', // Shortened for space
                value: '${widget.carbG.round()}g',
                percentage: totalKcal > 0 ? (cKcal / totalKcal * 100).round() : 0,
                isTouched: _touchedIndex == 1,
              ),
              const SizedBox(height: 12),
              _LegendItem(
                color: const Color(0xFFE91E63),
                label: 'Yağ',
                value: '${widget.fatG.round()}g',
                percentage: totalKcal > 0 ? (fKcal / totalKcal * 100).round() : 0,
                isTouched: _touchedIndex == 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _showingSections(
    double pKcal,
    double cKcal,
    double fKcal,
    double total,
  ) {
    return List.generate(3, (i) {
      final isTouched = i == _touchedIndex;
      final radius = isTouched ? 55.0 : 50.0;
      
      switch (i) {
        case 0: // Protein
          return PieChartSectionData(
            color: const Color(0xFF4CAF50),
            value: pKcal,
            title: '${(pKcal / total * 100).round()}%',
            radius: radius,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        case 1: // Carb
          return PieChartSectionData(
            color: const Color(0xFF2196F3),
            value: cKcal,
            title: '${(cKcal / total * 100).round()}%',
            radius: radius,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        case 2: // Fat
          return PieChartSectionData(
            color: const Color(0xFFE91E63),
            value: fKcal,
            title: '${(fKcal / total * 100).round()}%',
            radius: radius,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        default:
          throw Error();
      }
    });
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final int percentage;
  final bool isTouched;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
    required this.isTouched,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isTouched ? 1.1 : 1.0,
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                    // TextSpan(
                    //   text: ' ($percentage%)',
                    //   style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 10),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
