import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/meal_type.dart';
import 'portion_utils.dart';
import 'ring_painter.dart';

class MacroSummaryCard extends StatelessWidget {
  final double calculatedKcal;
  final double protein;
  final double carb;
  final double fat;
  final Animation<double> ringAnim;

  const MacroSummaryCard({
    super.key,
    required this.calculatedKcal,
    required this.protein,
    required this.carb,
    required this.fat,
    required this.ringAnim,
  });

  static const _proteinColor = Color(0xFF5B9BFF);
  static const _carbColor = Color(0xFF4CD1A3);
  static const _fatColor = Color(0xFFFFB74D);

  @override
  Widget build(BuildContext context) {
    final total = protein + carb + fat;
    final protPct = total > 0 ? (protein / total * 100).round() : 0;
    final carbPct = total > 0 ? (carb / total * 100).round() : 0;
    final fatPct = total > 0 ? (fat / total * 100).round() : 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.22),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: ringAnim,
                    builder: (c2, ch2) => SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                        painter: RingPainter(
                          color: AppColors.secondary,
                          strokeWidth: 4,
                          glowOpacity: 0.10 + ringAnim.value * 0.18,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${calculatedKcal.round()}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                'kcal',
                                style: TextStyle(
                                  color: AppColors.secondary.withValues(alpha: 0.85),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        if (total > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                if (protein > 0)
                                  Flexible(
                                    flex: (protein * 100).round(),
                                    child: Container(height: 8, color: _proteinColor),
                                  ),
                                if (carb > 0)
                                  Flexible(
                                    flex: (carb * 100).round(),
                                    child: Container(height: 8, color: _carbColor),
                                  ),
                                if (fat > 0)
                                  Flexible(
                                    flex: (fat * 100).round(),
                                    child: Container(height: 8, color: _fatColor),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _macroDetailCol('Protein', protein, protPct, _proteinColor),
                            _sep(),
                            _macroDetailCol('Karb', carb, carbPct, _carbColor),
                            _sep(),
                            _macroDetailCol('Yağ', fat, fatPct, _fatColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroDetailCol(String label, double grams, int pct, Color color) => Column(
    children: [
      Text(
        '${grams.toStringAsFixed(1)}g',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.50),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 1),
      Text(
        '$pct%',
        style: TextStyle(
          color: color.withValues(alpha: 0.55),
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _sep() => Container(
    width: 1,
    height: 30,
    color: Colors.white.withValues(alpha: 0.09),
  );
}

class MealTypeCard extends StatelessWidget {
  final MealType selectedMealType;
  final ValueChanged<MealType> onMealTypeSelected;

  const MealTypeCard({
    super.key,
    required this.selectedMealType,
    required this.onMealTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (MealType.breakfast, Icons.wb_sunny_rounded, 'Kahvaltı'),
      (MealType.lunch, Icons.wb_cloudy_rounded, 'Öğle'),
      (MealType.dinner, Icons.nights_stay_rounded, 'Akşam'),
      (MealType.snack, Icons.cookie_rounded, 'Ara'),
    ];

    return PortionUtils.buildGlassCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortionUtils.buildHeader(Icons.schedule_rounded, 'Öğün Seç'),
          const SizedBox(height: 12),
          Row(
            children: items.map((item) {
              final (type, icon, label) = item;
              final isSelected = selectedMealType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onMealTypeSelected(type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.32),
                                  AppColors.primary.withValues(alpha: 0.14),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.65)
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: isSelected ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
