import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/food_item.dart';
import 'portion_utils.dart';
import 'ring_painter.dart';

class FoodHeroCard extends StatelessWidget {
  final FoodItem food;
  final Animation<double> ringAnim;

  const FoodHeroCard({
    super.key,
    required this.food,
    required this.ringAnim,
  });

  static const _proteinColor = Color(0xFF5B9BFF);
  static const _carbColor = Color(0xFF4CD1A3);
  static const _fatColor = Color(0xFFFFB74D);

  @override
  Widget build(BuildContext context) {
    final badges = <(String, Color)>[];
    if (food.proteinPer100g >= 20) badges.add(('Yüksek Protein', _proteinColor));
    if (food.carbPer100g < 5) badges.add(('Düşük Karb', _carbColor));
    if (food.fatPer100g < 3) badges.add(('Düşük Yağ', const Color(0xFF8BC34A)));
    if (food.kcalPer100g < 50) badges.add(('Hafif', Colors.white70));

    return PortionUtils.buildGlassCard(
      radius: 22,
      accentBorder: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Kalori Halkası ──────────────────────
            AnimatedBuilder(
              animation: ringAnim,
              builder: (context, child) => SizedBox(
                width: 72,
                height: 72,
                child: CustomPaint(
                  painter: RingPainter(
                    color: AppColors.secondary,
                    strokeWidth: 3,
                    glowOpacity: 0.08 + ringAnim.value * 0.14,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${food.kcalPer100g.round()}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            letterSpacing: -0.8,
                          ),
                        ),
                        Text(
                          'kcal',
                          style: TextStyle(
                            color: AppColors.secondary.withValues(alpha: 0.8),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '/100g',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // ── İsim + Etiketler + Makrolar ─────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // İsim
                  Text(
                    food.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Etiketler (kategori + besin etiketleri)
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      PortionUtils.buildBadge(
                        food.category.isEmpty ? 'Besin' : food.category,
                        Colors.white.withValues(alpha: 0.45),
                      ),
                      ...badges.map((b) => PortionUtils.buildBadge(b.$1, b.$2)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Makrolar — tek satır
                  Row(
                    children: [
                      _macroChip('P', '${food.proteinPer100g.round()}g', _proteinColor),
                      const SizedBox(width: 6),
                      _macroChip('K', '${food.carbPer100g.round()}g', _carbColor),
                      const SizedBox(width: 6),
                      _macroChip('Y', '${food.fatPer100g.round()}g', _fatColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String abbr, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.20)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          abbr,
          style: TextStyle(
            color: color.withValues(alpha: 0.65),
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: GoogleFonts.inter(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}
