import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_card.dart';

class NutritionSummaryCard extends StatelessWidget {
  final double consumedKcal;
  final double targetKcal;
  final double proteinG;
  final double carbG;
  final double fatG;
  
  final double targetProteinG = 150; 
  final double targetCarbG = 200;
  final double targetFatG = 70;

  const NutritionSummaryCard({
    super.key,
    required this.consumedKcal,
    required this.targetKcal,
    required this.proteinG,
    required this.carbG,
    required this.fatG,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (targetKcal - consumedKcal).clamp(0.0, double.infinity);
    final progress = targetKcal > 0 ? (consumedKcal / targetKcal).clamp(0.0, 1.0) : 0.0;

    return AppCard(
      // Disable expensive entry animation on rebuilds
      animateOnAppear: false, 
      padding: EdgeInsets.zero, // Padding'i içeriye taşıyoruz
      child: Stack(
        children: [
          // Glass Effect Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.1),
                  Colors.white.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // İçerik
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Radial Progress & Kalori
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                     SizedBox(
                       width: 140,
                       height: 140,
                       child: Stack(
                         alignment: Alignment.center,
                         children: [
                           // Background Circle
                           SizedBox(
                             width: 140,
                             height: 140,
                             child: CircularProgressIndicator(
                               value: 1.0,
                               strokeWidth: 12,
                               color: Colors.white.withValues(alpha: 0.1), // Daha silik arka plan
                             ),
                           ),
                           // Animated Progress Circle
                           TweenAnimationBuilder<double>(
                             tween: Tween<double>(begin: 0.0, end: progress),
                             duration: const Duration(milliseconds: 1000),
                             curve: Curves.easeOutCubic,
                             builder: (context, value, _) {
                               return SizedBox(
                                 width: 140,
                                 height: 140,
                                 child: CircularProgressIndicator(
                                   value: value,
                                   strokeWidth: 12,
                                   color: AppColors.primary,
                                   strokeCap: StrokeCap.round,
                                 ),
                               );
                             },
                           ),
                           
                           // Text
                           Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               TweenAnimationBuilder<double>(
                                 tween: Tween<double>(begin: 0.0, end: remaining),
                                 duration: const Duration(milliseconds: 800),
                                 curve: Curves.easeOut,
                                 builder: (context, value, _) {
                                   return Text(
                                     value.round().toString(),
                                     style: const TextStyle(
                                       fontSize: 32, // Biraz daha büyük
                                       fontWeight: FontWeight.bold,
                                       color: Colors.white,
                                       shadows: [
                                          Shadow(
                                            color: AppColors.primary,
                                            blurRadius: 20,
                                          )
                                       ]
                                     ),
                                   );
                                 },
                               ),
                               const Text(
                                 'Kalan',
                                 style: TextStyle(
                                   fontSize: 12,
                                   color: AppColors.textSecondary,
                                   letterSpacing: 1.2,
                                 ),
                               ),
                             ],
                           ),
                         ],
                       ),
                     ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Macros
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMacroColumn('Protein', proteinG, targetProteinG, const Color(0xFF4E95FF)),
                      _buildMacroColumn('Karb', carbG, targetCarbG, const Color(0xFF50D1AA)),
                      _buildMacroColumn('Yağ', fatG, targetFatG, const Color(0xFFFFCC00)),
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

  Widget _buildMacroColumn(String label, double current, double target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text(
            '${current.round()}/${target.round()}g',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceLight,
                  color: color,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
