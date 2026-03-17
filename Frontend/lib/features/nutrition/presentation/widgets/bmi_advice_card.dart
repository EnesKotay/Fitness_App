import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';

class BMIAdviceCard extends StatelessWidget {
  final double bmi;
  final String category;
  final String advice;

  const BMIAdviceCard({
    super.key,
    required this.bmi,
    required this.category,
    required this.advice,
  });

  Color get _categoryColor {
    if (bmi < 18.5) return Colors.blueAccent;
    if (bmi < 25) return Colors.greenAccent;
    if (bmi < 30) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      animateOnAppear: true,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Vücut Endeksi (BMI)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _categoryColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    color: _categoryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                bmi.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tavsiye',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      advice,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // BMI Scale Visualization
          _buildBMIScale(),
        ],
      ),
    );
  }

  Widget _buildBMIScale() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: const LinearGradient(
                  colors: [
                    Colors.blueAccent,
                    Colors.greenAccent,
                    Colors.orangeAccent,
                    Colors.redAccent,
                  ],
                ),
              ),
            ),
            // Indicator
            LayoutBuilder(
              builder: (context, constraints) {
                // Map BMI 15-40 to 0-100%
                double percent = ((bmi - 15) / (40 - 15)).clamp(0, 1.0);
                return Positioned(
                  left: percent * (constraints.maxWidth - 4),
                  child: Container(
                    width: 4,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('15', style: TextStyle(color: Colors.white24, fontSize: 10)),
            Text('25', style: TextStyle(color: Colors.white24, fontSize: 10)),
            Text('40+', style: TextStyle(color: Colors.white24, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
