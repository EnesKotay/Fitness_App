import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/repositories/diary_repository.dart';

class MicroNutrientsSheet extends StatelessWidget {
  final DiaryTotals totals;

  const MicroNutrientsSheet({
    super.key,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 40),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A1A).withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.science_rounded,
                    color: AppColors.secondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  'Detaylı Mikro Besinler',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildDetailRow(
              'Lif',
              totals.totalFiber,
              25.0,
              'g',
              const Color(0xFF8BC34A),
              Icons.grass_rounded,
              'Sindirim sağlığı ve tokluk hissi için önemlidir.',
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Şeker',
              totals.totalSugar,
              50.0,
              'g',
              const Color(0xFFE91E63),
              Icons.cake_rounded,
              'Fazla şeker tüketimi enerji dalgalanmalarına yol açabilir.',
              isInverse: true,
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Doymuş Yağ (~tahmini)',
              totals.totalFat * 0.3,
              20.0,
              'g',
              const Color(0xFFFF9800),
              Icons.opacity_rounded,
              'Toplam yağın ~%30\'u doymuş yağ kabul edilmiştir. Gerçek değer için besin etiketlerini takip edin.',
              isInverse: true,
            ),
            const SizedBox(height: 16),
            _buildNotTrackedRow(
              'Sodyum (Tuz)',
              const Color(0xFF00BCD4),
              Icons.grain_rounded,
              'Sodyum verisi besin kaydında tutulmamaktadır. Hazır gıda tüketimini sınırlayın (hedef < 2300 mg/gün).',
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildNotTrackedRow(
    String name,
    Color color,
    IconData icon,
    String desc,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.5), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'takip edilmiyor',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String name,
    double value,
    double target,
    String unit,
    Color color,
    IconData icon,
    String desc, {
    bool isInverse = false,
  }) {
    final progress = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    // Eğer inverse ise (örn. şeker) target aşıldığında renk kırmızıya dönsün
    final isOver = value > target;
    final displayColor = isInverse && isOver ? AppColors.error : color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: displayColor, size: 20),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${value.round()}$unit / ${target.round()}$unit',
                style: TextStyle(
                  color: displayColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: displayColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(displayColor),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
