import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/food_item.dart';
import 'portion_utils.dart';

class ServingsCard extends StatelessWidget {
  final FoodItem food;
  final double currentGrams;
  final ValueChanged<double> onGramsSelected;

  const ServingsCard({
    super.key,
    required this.food,
    required this.currentGrams,
    required this.onGramsSelected,
  });

  @override
  Widget build(BuildContext context) {
    final filteredServings = food.servings.where((s) {
      final lower = s.label.toLowerCase().trim();
      return lower != '100 g' && lower != '100g';
    }).toList();

    if (filteredServings.isEmpty) return const SizedBox.shrink();

    return PortionUtils.buildGlassCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortionUtils.buildHeader(Icons.straighten_rounded, 'Standart Ölçüler'),
          const SizedBox(height: 8),
          Text(
            'Paket veya veri kaynağındaki hazır ölçüler.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: filteredServings.map((s) {
              final isSelected = (currentGrams - s.grams).abs() < 1;
              final label = PortionUtils.displayServingLabel(s.label);
              final subtitle = PortionUtils.humanPresetSubtitle(label, s.grams, food);
              final icon = PortionUtils.servingIcon(label);
              return GestureDetector(
                onTap: () => onGramsSelected(s.grams.toDouble()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: (MediaQuery.of(context).size.width - 82) / 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.secondary.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary
                          : Colors.white.withValues(alpha: 0.06),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.secondary.withValues(alpha: 0.20)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          size: 17,
                          color: isSelected ? AppColors.secondary : Colors.white60,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: isSelected ? AppColors.secondary : Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: isSelected
                                    ? AppColors.secondary.withValues(alpha: 0.72)
                                    : Colors.white.withValues(alpha: 0.46),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
