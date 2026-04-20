import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  @override
  Widget build(BuildContext context) {
    // ── 1. Uygulama presetleri ──────────────────────────────────
    final presets = PortionUtils.buildUserFriendlyPresets(food, defaultPortionGrams);

    // ── 2. Yiyeceğe özel ölçüler (servings) — "100g" hariç ──────
    final extraServings = food.servings.where((s) {
      final lower = s.label.toLowerCase().trim();
      return lower != '100 g' && lower != '100g';
    }).toList();

    // ── 3. Birleşik tile listesi ────────────────────────────────
    // Preset tile'ları
    final List<_PortionTile> tiles = presets.take(4).map((p) {
      final (label, icon, grams) = p;
      return _PortionTile(
        label: PortionUtils.displayPresetTitle(label, food),
        icon: icon,
        grams: grams,
        kcal: (food.kcalPer100g * grams / 100).round(),
      );
    }).toList();

    // Serving tile'ları — preset ile çakışanları atla (±5g tolerans)
    for (final s in extraServings) {
      final g = s.grams.toDouble();
      final alreadyCovered = tiles.any((t) => (t.grams - g).abs() < 5);
      if (!alreadyCovered) {
        tiles.add(_PortionTile(
          label: PortionUtils.displayServingLabel(s.label),
          icon: PortionUtils.servingIcon(s.label),
          grams: g,
          kcal: (food.kcalPer100g * g / 100).round(),
          isServing: true,
        ));
      }
    }

    return PortionUtils.buildGlassCard(
      radius: 22,
      accentBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık ────────────────────────────────
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  size: 15,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Porsiyon Seç',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              // Seçili kcal pill
              if (currentGrams > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: AppColors.secondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${calculatedKcal.round()} kcal',
                    style: GoogleFonts.inter(
                      color: AppColors.secondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Tile Grid ─────────────────────────────
          _buildGrid(context, tiles),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<_PortionTile> tiles) {
    final screenW = MediaQuery.of(context).size.width;
    // 3 sütun: dış padding 16×2 + kart iç padding 16×2 + 2 boşluk×10
    final itemW = (screenW - 32 - 32 - 20) / 3;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tiles.map((tile) {
        final isSelected = (currentGrams - tile.grams).abs() < 1;
        final accentColor = tile.isServing ? AppColors.secondary : AppColors.primary;
        final accentLight = tile.isServing ? AppColors.secondary : AppColors.primaryLight;

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onGramsSelected(tile.grams);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: itemW,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.28),
                        accentColor.withValues(alpha: 0.10),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  tile.icon,
                  size: 20,
                  color: isSelected
                      ? accentLight
                      : Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Text(
                  tile.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tile.kcal} kcal',
                  style: GoogleFonts.inter(
                    color: isSelected
                        ? accentLight
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PortionTile {
  final String label;
  final IconData icon;
  final double grams;
  final int kcal;
  final bool isServing; // serving tile'ları hafif farklı renk alır

  const _PortionTile({
    required this.label,
    required this.icon,
    required this.grams,
    required this.kcal,
    this.isServing = false,
  });
}
