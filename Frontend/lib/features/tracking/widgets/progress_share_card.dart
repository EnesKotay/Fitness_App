import 'package:flutter/material.dart';

/// Sosyal medya paylaşımı için tasarlanmış özel kart.
/// Screenshot.captureFromWidget() ile render edilir.
class ProgressShareCard extends StatelessWidget {
  final double? currentWeightKg;
  final double? goalWeightKg;
  final double? weightChangeSinceStart;
  final int streak;
  final int totalCaloriesToday;
  final String? userName;
  final bool showCurrentWeight;
  final bool showGoal;
  final bool showChange;

  const ProgressShareCard({
    super.key,
    this.currentWeightKg,
    this.goalWeightKg,
    this.weightChangeSinceStart,
    this.streak = 0,
    this.totalCaloriesToday = 0,
    this.userName,
    this.showCurrentWeight = true,
    this.showGoal = true,
    this.showChange = true,
  });

  @override
  Widget build(BuildContext context) {
    final goalDiff =
        (showGoal && currentWeightKg != null && goalWeightKg != null)
        ? (currentWeightKg! - goalWeightKg!).abs()
        : null;
    final isLosing = (currentWeightKg != null && goalWeightKg != null)
        ? currentWeightKg! > goalWeightKg!
        : true;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
        ),
      ),
      child: Stack(
        children: [
          // Arka plan glow efektleri
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFCC7A4A).withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF4CAF50).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // İçerik
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst: Logo + marka
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFCC7A4A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('💪', style: TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'PusulaFit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    if (streak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCC7A4A).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFFCC7A4A,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          '🔥 $streak gün',
                          style: const TextStyle(
                            color: Color(0xFFCC7A4A),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                // İlerleme başlığı
                Text(
                  userName != null
                      ? '${userName!.split(' ').first} ilerleme kaydediyor!'
                      : 'İlerleme kaydediyorum!',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // Mevcut ağırlık büyük gösterim
                if (showCurrentWeight && currentWeightKg != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        currentWeightKg!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10, left: 4),
                        child: Text(
                          'kg',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                // Değişim bilgisi
                if (showChange && weightChangeSinceStart != null) ...[
                  Row(
                    children: [
                      Icon(
                        weightChangeSinceStart! < 0
                            ? Icons.trending_down_rounded
                            : Icons.trending_up_rounded,
                        color: weightChangeSinceStart! < 0
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFEF5350),
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${weightChangeSinceStart!.abs().toStringAsFixed(1)} kg '
                        '${weightChangeSinceStart! < 0 ? 'verdim' : 'aldım'}',
                        style: TextStyle(
                          color: weightChangeSinceStart! < 0
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFEF5350),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 8),
                // Alt bilgiler: Hedef + Kalori
                Row(
                  children: [
                    if (goalDiff != null)
                      _infoChip(
                        icon: '🎯',
                        label:
                            '${goalDiff.toStringAsFixed(1)} kg ${isLosing ? "kaldı" : "kaldı"}',
                      ),
                    if (goalDiff != null) const SizedBox(width: 10),
                    if (totalCaloriesToday > 0)
                      _infoChip(icon: '🥗', label: '$totalCaloriesToday kcal'),
                  ],
                ),
                const SizedBox(height: 20),
                // Alt etiket
                const Text(
                  '#PusulaFit #SağlıklıYaşam #Fitness',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip({required String icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
