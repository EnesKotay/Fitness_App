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
    if (food.proteinPer100g >= 20) {
      badges.add(('Yüksek Protein', _proteinColor));
    }
    if (food.carbPer100g < 5) badges.add(('Düşük Karb', _carbColor));
    if (food.fatPer100g < 3) badges.add(('Düşük Yağ', const Color(0xFF8BC34A)));
    if (food.kcalPer100g < 50) badges.add(('Hafif', Colors.white70));

    return PortionUtils.buildGlassCard(
      radius: 24,
      accentBorder: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: ringAnim,
                  builder: (context, child) => SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(
                      painter: RingPainter(
                        color: AppColors.secondary,
                        strokeWidth: 3.5,
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
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -0.8,
                              ),
                            ),
                            Text(
                              'kcal',
                              style: TextStyle(
                                color: AppColors.secondary.withValues(alpha: 0.8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '/ 100g',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 8,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Etiketler Row sarmalaması yerine Wrap kullanılmış
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          PortionUtils.buildBadge(
                            food.category.isEmpty ? 'Besin' : food.category,
                            Colors.white.withValues(alpha: 0.5),
                          ),
                          ...badges.map((b) => PortionUtils.buildBadge(b.$1, b.$2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroCol('Protein', food.proteinPer100g, _proteinColor),
                _sep(),
                _macroCol('Karb', food.carbPer100g, _carbColor),
                _sep(),
                _macroCol('Yağ', food.fatPer100g, _fatColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroCol(String label, double value, Color color) => Column(
    children: [
      Text(
        '${value.round()}g',
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
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 10,
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
