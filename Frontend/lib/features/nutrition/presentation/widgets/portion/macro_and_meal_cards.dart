import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/meal_type.dart';
import 'portion_utils.dart';


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
