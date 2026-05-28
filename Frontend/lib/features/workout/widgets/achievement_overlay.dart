import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/streak_provider.dart';

/// Antrenman tamamlandığında ekranda gösterilen kutlama overlay'i.
class AchievementOverlay extends StatefulWidget {
  final AchievementBadge badge;
  final Color accentColor;
  final VoidCallback onDismiss;

  /// Non-premium kullanıcılar için soft-upsell göstermek amacıyla.
  /// null ise banner hiç gösterilmez.
  final bool isPremium;
  final VoidCallback? onUpgradeTap;

  const AchievementOverlay({
    super.key,
    required this.badge,
    required this.accentColor,
    required this.onDismiss,
    this.isPremium = true,
    this.onUpgradeTap,
  });

  @override
  State<AchievementOverlay> createState() => _AchievementOverlayState();
}

class _AchievementOverlayState extends State<AchievementOverlay>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );
    _confettiController.play();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ── Confetti ──────────────────────────────────────────────────
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.06,
                numberOfParticles: 20,
                gravity: 0.08,
                colors: [
                  widget.accentColor,
                  Colors.amber,
                  Colors.white,
                  Colors.green,
                  Colors.pinkAccent,
                ],
                createParticlePath: (size) {
                  final path = Path();
                  path.addOval(Rect.fromCircle(
                      center: Offset.zero, radius: size.width * 0.4));
                  return path;
                },
              ),
            ),

            // ── Merkez kart ───────────────────────────────────────────────
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 36),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: widget.accentColor.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.accentColor.withValues(alpha: 0.25),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rozet emoji
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            widget.accentColor.withValues(alpha: 0.3),
                            widget.accentColor.withValues(alpha: 0.05),
                          ],
                        ),
                        border: Border.all(
                          color: widget.accentColor.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          widget.badge.emoji,
                          style: const TextStyle(fontSize: 42),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Başlık
                    Text(
                      'Rozet Kazandın!',
                      style: TextStyle(
                        color: widget.accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.badge.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.badge.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Soft-upsell banner (sadece non-premium streak rozeti) ──
                    if (!widget.isPremium &&
                        widget.badge.isStreak &&
                        widget.onUpgradeTap != null) ..._buildStreakUpsell(),

                    // Kapat butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: widget.onDismiss,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.accentColor,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Harika! 🎉',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ekrana dok. kapatmak için',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Streak milestone'u kutlamasının altında gösterilen premium soft-upsell satırları.
  List<Widget> _buildStreakUpsell() {
    const gold = Color(0xFFEBC374);
    final streakLabel = widget.badge.id == 'streak_30'
        ? '30 günlük'
        : widget.badge.id == 'streak_7'
        ? '7 günlük'
        : '3 günlük';
    return [
      const SizedBox(height: 14),
      GestureDetector(
        onTap: widget.onUpgradeTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                gold.withValues(alpha: 0.13),
                gold.withValues(alpha: 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: gold.withValues(alpha: 0.32)),
          ),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded, color: gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$streakLabel serinle ciddi adım attın!',
                      style: GoogleFonts.dmSans(
                        color: gold,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bu haftanın tam besin trend analizini/haftalık programını Premium ile gör.',
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: gold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'PRO',
                  style: GoogleFonts.dmSans(
                    color: gold,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
    ];
  }
}

/// Streak gösterge widget'ı (Dashboard/header için)
class StreakBadgeWidget extends StatelessWidget {
  final int streak;
  final Color accentColor;
  final bool compact;

  const StreakBadgeWidget({
    super.key,
    required this.streak,
    required this.accentColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (streak == 0) return const SizedBox.shrink();
    final isOnFire = streak >= 3;
    final color = isOnFire ? Colors.orange : accentColor;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOnFire ? '🔥' : '⚡',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Text(
              '$streak gün',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Text(
            isOnFire ? '🔥' : '⚡',
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seri',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$streak Gün',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  isOnFire
                      ? 'Alev alev devam et! 💪'
                      : 'Devam et, seri başladı!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tüm rozetleri listeleyen widget
class AchievementListWidget extends StatelessWidget {
  final List<String> unlockedIds;
  final Color accentColor;

  const AchievementListWidget({
    super.key,
    required this.unlockedIds,
    required this.accentColor,
  });

  static const _allBadges = [
    ('first_workout', '🏁', 'İlk Adım', '1 antrenman'),
    ('seven_workouts', '🔥', '7 Antrenman', '7 antrenman'),
    ('thirty_workouts', '💪', '30 Antrenman', '30 antrenman'),
    ('hundred_workouts', '🏆', '100 Antrenman', '100 antrenman'),
    ('streak_3', '🔥', '3 Gün Seri', '3 ardışık gün'),
    ('streak_7', '⚡', '7 Gün Seri', '7 ardışık gün'),
    ('streak_30', '👑', '30 Gün Seri', '30 ardışık gün'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _allBadges.map((b) {
        final isUnlocked = unlockedIds.contains(b.$1);
        return Container(
          width: 90,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isUnlocked
                ? accentColor.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnlocked
                  ? accentColor.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            children: [
              Text(
                isUnlocked ? b.$2 : '🔒',
                style: TextStyle(
                    fontSize: 28,
                    color: isUnlocked ? null : Colors.white24),
              ),
              const SizedBox(height: 6),
              Text(
                b.$3,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isUnlocked
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.35),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                b.$4,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
