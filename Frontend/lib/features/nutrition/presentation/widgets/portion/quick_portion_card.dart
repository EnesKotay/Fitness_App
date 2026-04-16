import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/food_item.dart';
import 'portion_utils.dart';

class QuickPortionCard extends StatelessWidget {
  final FoodItem food;
  final double currentGrams;
  final double calculatedKcal;
  final double defaultPortionGrams;
  final ValueChanged<double> onGramsSelected;

  const QuickPortionCard({
    super.key,
    required this.food,
    required this.currentGrams,
    required this.calculatedKcal,
    required this.defaultPortionGrams,
    required this.onGramsSelected,
  });

  String _selectedFriendlyAmountTitle() {
    final presets = PortionUtils.buildUserFriendlyPresets(food, defaultPortionGrams);
    for (final preset in presets) {
      if ((preset.$3 - currentGrams).abs() < 1) {
        return PortionUtils.displayPresetTitle(preset.$1, food);
      }
    }

    for (final serving in food.servings) {
      if ((serving.grams - currentGrams).abs() < 1) {
        return PortionUtils.displayServingLabel(serving.label);
      }
    }

    // fallback unit using diet provider logic moved to utils if possible, otherwise hardcode
    final unit = 'Porsiyon'; 
    if (currentGrams <= 0) return 'Miktar seç';
    final ratio = currentGrams / (defaultPortionGrams <= 0 ? 100 : defaultPortionGrams);

    if ((ratio - 0.5).abs() < 0.1) return 'Yarım $unit';
    if ((ratio - 1).abs() < 0.1) return '1 $unit';
    if ((ratio - 1.5).abs() < 0.1) return '1,5 $unit';
    if ((ratio - 2).abs() < 0.15) return '2 $unit';
    return '${ratio.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')} $unit';
  }

  String _selectedFriendlyAmountSubtitle() {
    if (currentGrams <= 0) return 'Miktar seçildiğinde burada görünür';
    return '${PortionUtils.formatGrams(currentGrams)} • yaklaşık ${calculatedKcal.round()} kcal';
  }

  @override
  Widget build(BuildContext context) {
    final title = _selectedFriendlyAmountTitle();
    final subtitle = _selectedFriendlyAmountSubtitle();

    return PortionUtils.buildGlassCard(
      radius: 24,
      accentBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortionUtils.buildHeader(Icons.restaurant_menu_rounded, 'Bugün Ne Kadar Yedin?'),
          const SizedBox(height: 10),
          Text(
            'Önce tabak, kase veya porsiyon seç. Gram bilmen gerekmiyor.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.20),
                  AppColors.secondary.withValues(alpha: 0.12),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seçilen miktar',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.58),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.1,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryPill('${calculatedKcal.round()} kcal', const Color(0xFFFFB067)),
                    _summaryPill(subtitle, Colors.white70),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickPortionGrid(context),
        ],
      ),
    );
  }

  Widget _buildQuickPortionGrid(BuildContext context) {
    final presets = PortionUtils.buildUserFriendlyPresets(food, defaultPortionGrams);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: presets.map((preset) {
        final (label, icon, grams) = preset;
        final isSelected = (currentGrams - grams).abs() < 1;
        final title = PortionUtils.displayPresetTitle(label, food);
        final subtitle = PortionUtils.humanPresetSubtitle(title, grams, food);

        return GestureDetector(
          onTap: () => onGramsSelected(grams),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: (MediaQuery.of(context).size.width - 82) / 2,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.30),
                        AppColors.primary.withValues(alpha: 0.14),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.70)
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.20)
                        : Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: isSelected ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: isSelected ? AppColors.primaryLight : Colors.white.withValues(alpha: 0.54),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _summaryPill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.22)),
    ),
    child: Text(
      text,
      style: GoogleFonts.inter(
        color: color == Colors.white70 ? Colors.white70 : color,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
