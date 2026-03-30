import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streak_provider.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  static const _bg = Color(0xFF121212);
  static const _card = Color(0xFF1E1E1E);
  static const _accent = Color(0xFFCC7A4A);

  // Tüm rozetlerin sabit listesi (hem kilitli hem açık gösterim için)
  static final _allBadges = [
    _BadgeInfo(
      id: 'first_workout',
      title: 'İlk Adım!',
      description: 'İlk antreni tamamla',
      emoji: '🏁',
      isStreak: false,
      threshold: 1,
      thresholdLabel: '1 antrenman',
    ),
    _BadgeInfo(
      id: 'seven_workouts',
      title: '7 Antrenman',
      description: '7 antren tamamla',
      emoji: '🔥',
      isStreak: false,
      threshold: 7,
      thresholdLabel: '7 antrenman',
    ),
    _BadgeInfo(
      id: 'thirty_workouts',
      title: '30 Antrenman',
      description: '30 antren tamamla',
      emoji: '💪',
      isStreak: false,
      threshold: 30,
      thresholdLabel: '30 antrenman',
    ),
    _BadgeInfo(
      id: 'hundred_workouts',
      title: '100 Antrenman',
      description: '100 antren tamamla',
      emoji: '🏆',
      isStreak: false,
      threshold: 100,
      thresholdLabel: '100 antrenman',
    ),
    _BadgeInfo(
      id: 'streak_3',
      title: '3 Günlük Seri',
      description: '3 gün üst üste antren yap',
      emoji: '🔥',
      isStreak: true,
      threshold: 3,
      thresholdLabel: '3 günlük seri',
    ),
    _BadgeInfo(
      id: 'streak_7',
      title: '7 Günlük Seri',
      description: '7 gün üst üste antren yap',
      emoji: '⚡',
      isStreak: true,
      threshold: 7,
      thresholdLabel: '7 günlük seri',
    ),
    _BadgeInfo(
      id: 'streak_30',
      title: '30 Günlük Seri',
      description: '30 gün üst üste antren yap',
      emoji: '👑',
      isStreak: true,
      threshold: 30,
      thresholdLabel: '30 günlük seri',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<StreakProvider>(
      builder: (context, streak, _) {
        final unlocked = streak.unlockedBadges.toSet();
        final unlockedList =
            _allBadges.where((b) => unlocked.contains(b.id)).toList();
        final lockedList =
            _allBadges.where((b) => !unlocked.contains(b.id)).toList();

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            title: const Text(
              'Başarımlar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _statsRow(streak),
              const SizedBox(height: 24),
              if (unlockedList.isNotEmpty) ...[
                _sectionHeader(
                    'KAZANILAN ROZETLER (${unlockedList.length})'),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: unlockedList.length,
                  itemBuilder: (context, i) =>
                      _badgeCard(unlockedList[i], unlocked: true),
                ),
                const SizedBox(height: 28),
              ],
              if (lockedList.isNotEmpty) ...[
                _sectionHeader('KİLİTLİ ROZETLER (${lockedList.length})'),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: lockedList.length,
                  itemBuilder: (context, i) =>
                      _badgeCard(lockedList[i], unlocked: false),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _statsRow(StreakProvider streak) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('🔥', '${streak.currentStreak}', 'Günlük Seri'),
          _vDivider(),
          _statItem('💪', '${streak.totalWorkouts}', 'Toplam Antren'),
          _vDivider(),
          _statItem('🏅', '${streak.unlockedBadges.length}', 'Rozet'),
        ],
      ),
    );
  }

  Widget _statItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11),
        ),
      ],
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 48,
        color: Colors.white12,
      );

  Widget _sectionHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF9E9E9E),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _badgeCard(_BadgeInfo badge, {required bool unlocked}) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: unlocked
            ? Border.all(color: _accent.withValues(alpha: 0.4), width: 1.5)
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  unlocked ? badge.emoji : '🔒',
                  style: TextStyle(
                    fontSize: 36,
                    color: unlocked ? null : Colors.white24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  badge.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white38,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  unlocked ? badge.description : badge.thresholdLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: unlocked
                        ? Colors.white54
                        : Colors.white24,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (unlocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✓',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BadgeInfo {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool isStreak;
  final int threshold;
  final String thresholdLabel;

  const _BadgeInfo({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.isStreak,
    required this.threshold,
    required this.thresholdLabel,
  });
}
