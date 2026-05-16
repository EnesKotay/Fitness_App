import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../core/theme/app_colors.dart';
import '../../../domain/entities/food_item.dart';
import 'portion_utils.dart';
import 'ring_painter.dart';

class FoodHeroCard extends StatelessWidget {
  final FoodItem food;
  final Animation<double> ringAnim;
  final double currentGrams;
  final double calculatedKcal;
  final double calculatedProtein;
  final double calculatedCarb;
  final double calculatedFat;

  const FoodHeroCard({
    super.key,
    required this.food,
    required this.ringAnim,
    required this.currentGrams,
    required this.calculatedKcal,
    required this.calculatedProtein,
    required this.calculatedCarb,
    required this.calculatedFat,
  });

  static const _proteinColor = Color(0xFF5B9BFF);
  static const _carbColor = Color(0xFF4CD1A3);
  static const _fatColor = Color(0xFFFFB74D);

  @override
  Widget build(BuildContext context) {
    final badges = <(String, Color)>[];
    final confidence = _confidenceBadge(food);
    badges.add(confidence);
    if (food.proteinPer100g >= 20) {
      badges.add(('Yüksek Protein', _proteinColor));
    }
    if (food.carbPer100g < 5) badges.add(('Düşük Karb', _carbColor));
    if (food.fatPer100g < 3) badges.add(('Düşük Yağ', const Color(0xFF8BC34A)));
    if (food.kcalPer100g < 50) badges.add(('Hafif', Colors.white70));

    final total = calculatedProtein + calculatedCarb + calculatedFat;
    final protPct = total > 0 ? (calculatedProtein / total * 100).round() : 0;
    final carbPct = total > 0 ? (calculatedCarb / total * 100).round() : 0;
    final fatPct = total > 0 ? (calculatedFat / total * 100).round() : 0;

    return PortionUtils.buildGlassCard(
      radius: 22,
      accentBorder: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Üst Kısım: İsim, Etiketler ve Kalori Halkası ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          PortionUtils.buildBadge(
                            food.category.isEmpty ? 'Besin' : food.category,
                            Colors.white.withValues(alpha: 0.45),
                          ),
                          ...badges.map(
                            (b) => PortionUtils.buildBadge(b.$1, b.$2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                AnimatedBuilder(
                  animation: ringAnim,
                  builder: (context, child) => SizedBox(
                    width: 76,
                    height: 76,
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
                              '${calculatedKcal.round()}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -0.8,
                              ),
                            ),
                            Text(
                              'kcal',
                              style: TextStyle(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '/${PortionUtils.formatGrams(currentGrams)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
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
              ],
            ),

            const SizedBox(height: 18),

            // ── Alt Kısım: Makro Bar ve Detaylı Kutular ──
            if (total > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    if (calculatedProtein > 0)
                      Flexible(
                        flex: (calculatedProtein * 100).round(),
                        child: Container(height: 7, color: _proteinColor),
                      ),
                    if (calculatedCarb > 0)
                      Flexible(
                        flex: (calculatedCarb * 100).round(),
                        child: Container(height: 7, color: _carbColor),
                      ),
                    if (calculatedFat > 0)
                      Flexible(
                        flex: (calculatedFat * 100).round(),
                        child: Container(height: 7, color: _fatColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Row(
              children: [
                Expanded(
                  child: _detailedMacroChip(
                    'Protein',
                    calculatedProtein,
                    protPct,
                    _proteinColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _detailedMacroChip(
                    'Karb',
                    calculatedCarb,
                    carbPct,
                    _carbColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _detailedMacroChip(
                    'Yağ',
                    calculatedFat,
                    fatPct,
                    _fatColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailedMacroChip(String label, double grams, int pct, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.16)),
        ),
        child: Column(
          children: [
            Text(
              '${grams.toStringAsFixed(1)}g',
              style: GoogleFonts.inter(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.50),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '$pct%',
              style: TextStyle(
                color: color.withValues(alpha: 0.50),
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );

  (String, Color) _confidenceBadge(FoodItem food) {
    if (food.tags.contains('barcode-verified') ||
        food.tags.contains('user-corrected') ||
        food.category.toLowerCase().contains('barkodlu')) {
      return ('Doğrulandı', AppColors.success);
    }
    if (food.tags.contains('open-food-facts') ||
        food.tags.contains('etiket-verisi')) {
      return ('Dış veri - kontrol et', AppColors.warning);
    }
    if (food.tags.contains('ai-estimate')) {
      return ('Tahmini', AppColors.secondary);
    }
    return ('Uygulama verisi', Colors.white70);
  }
}
