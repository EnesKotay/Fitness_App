import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streak_provider.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  static const _bg = Color(0xFF121212);
  static const _card = Color(0xFF1E1E1E);
  static const _workoutAccent = Color(0xFFCC7A4A);
  static const _trackingAccent = Color(0xFF4DB6AC);
  static const _nutritionAccent = Color(0xFF81C784);

  static final _workoutBadges = [
    _BadgeInfo('first_workout', 'İlk Adım!', 'İlk antreni tamamla', '🏁', 1, '1 antrenman'),
    _BadgeInfo('seven_workouts', '7 Antrenman', '7 antren tamamla', '🔥', 7, '7 antrenman'),
    _BadgeInfo('thirty_workouts', '30 Antrenman', '30 antren tamamla', '💪', 30, '30 antrenman'),
    _BadgeInfo('hundred_workouts', '100 Antrenman', '100 antren tamamla', '🏆', 100, '100 antrenman'),
    _BadgeInfo('streak_3', '3 Günlük Seri', '3 gün üst üste antren yap', '🔥', 3, '3 günlük seri'),
    _BadgeInfo('streak_7', '7 Günlük Seri', '7 gün üst üste antren yap', '⚡', 7, '7 günlük seri'),
    _BadgeInfo('streak_30', '30 Günlük Seri', '30 gün üst üste antren yap', '👑', 30, '30 günlük seri'),
    _BadgeInfo('streak_100', 'Asfalt Ağlatan', '100 gün üst üste spor', '🔥', 100, '100 günlük seri'),
    _BadgeInfo('streak_365', 'Efsanevi Yıl', '365 gün antrenman yap', '🌟', 365, '1 yıllık seri'),
  ];

  static final _trackingBadges = [
    _BadgeInfo('track_1', 'İlk Tartı', 'İlk kilonu kaydet', '⚖️', 1, '1 kayıt'),
    _BadgeInfo('track_streak_7', '7 Gün Takip', '7 gün üst üste tartıl', '🔥', 7, '7 günlük seri'),
    _BadgeInfo('track_streak_30', '30 Gün Takip', '30 gün üst üste tartıl', '🏆', 30, '30 günlük seri'),
    _BadgeInfo('track_streak_100', 'Disiplin Ustası', '100 gün üst üste tartıl', '🎯', 100, '100 günlük seri'),
    _BadgeInfo('track_100', 'Sadık Takipçi', 'Toplam 100 kayıt gir', '💎', 100, '100 kayıt'),
  ];

  static final _nutritionBadges = [
    _BadgeInfo('diet_1', 'İlk Isırık', 'İlk yemeğini kaydet', '🍎', 1, '1 gün kayıt'),
    _BadgeInfo('diet_streak_7', 'Sağlıklı Hafta', '7 gün üst üste besin gir', '🥗', 7, '7 günlük seri'),
    _BadgeInfo('diet_streak_30', 'Aşçıbaşı', '30 gün üst üste besin gir', '👨‍🍳', 30, '30 günlük seri'),
    _BadgeInfo('exact_calories', 'Tam İsabet', 'Günlük kaloriyi tam tuttur', '🎯', 1, 'Kalori Hedefi %5'),
    _BadgeInfo('protein_monster', 'Protein Canavarı', 'Protein hedefine ulaş', '🥩', 1, 'Protein Hedefi'),
    _BadgeInfo('water_warrior', 'Su Savaşçısı', '2 Litre su hedefine ulaş', '💧', 1, '2L Su'),
    _BadgeInfo('early_bird', 'Erkenci Kuş', 'Sabah 07:00 öncesi aktivite', '🌅', 1, '07:00 öncesi'),
    _BadgeInfo('night_owl', 'Gece Kuşu', 'Gece 23:00 sonrası aktivite', '🦉', 1, '23:00 sonrası'),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer3<StreakProvider, WeightProvider, DietProvider>(
      builder: (context, streak, weight, diet, _) {
        // Calculate Unlocked
        final unlockedWorkout = streak.unlockedBadges.toSet();
        if (streak.currentStreak >= 100) unlockedWorkout.add('streak_100');
        if (streak.currentStreak >= 365) unlockedWorkout.add('streak_365');
        
        final unlockedTracking = <String>{};
        if (weight.entries.isNotEmpty) unlockedTracking.add('track_1');
        if (weight.currentStreak >= 7) unlockedTracking.add('track_streak_7');
        if (weight.currentStreak >= 30) unlockedTracking.add('track_streak_30');
        if (weight.currentStreak >= 100) unlockedTracking.add('track_streak_100');
        if (weight.entries.length >= 100) unlockedTracking.add('track_100');

        final unlockedNutrition = <String>{};
        if (diet.currentStreak >= 1) unlockedNutrition.add('diet_1');
        if (diet.currentStreak >= 7) unlockedNutrition.add('diet_streak_7');
        if (diet.currentStreak >= 30) unlockedNutrition.add('diet_streak_30');
        
        // Exact calories (within 5%)
        final target = diet.dailyTargetKcal;
        final consumed = diet.totals.totalKcal;
        if (target != null && target > 0 && consumed > 0) {
          final diff = (target - consumed).abs();
          if (diff / target <= 0.05) unlockedNutrition.add('exact_calories');
        }

        // Protein Monster
        if (diet.totals.totalProtein >= diet.macroTargets.protein && diet.macroTargets.protein > 0) {
          unlockedNutrition.add('protein_monster');
        }

        // Water Warrior
        if (diet.waterLiters >= 2.0) {
          unlockedNutrition.add('water_warrior');
        }

        // Early Bird & Night Owl check
        bool isEarly = false;
        bool isNight = false;
        for (var entry in diet.entries) {
          if (entry.createdAt.hour < 7) isEarly = true;
          if (entry.createdAt.hour >= 23) isNight = true;
        }
        for (var workout in diet.todayWorkouts) {
          if (workout.workoutDate.hour < 7) isEarly = true;
          if (workout.workoutDate.hour >= 23) isNight = true;
        }

        if (isEarly) unlockedNutrition.add('early_bird');
        if (isNight) unlockedNutrition.add('night_owl');

        final totalUnlocked = unlockedWorkout.length + unlockedTracking.length + unlockedNutrition.length;

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            title: const Text(
              'Kupa Odası',
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
              _statsRow(streak, weight, totalUnlocked),
              const SizedBox(height: 32),
              
              _buildCategorySection(
                title: 'DEMİR BÜKÜCÜ (ANTRENMAN)',
                accent: _workoutAccent,
                badges: _workoutBadges,
                unlockedIds: unlockedWorkout,
              ),
              const SizedBox(height: 32),

              _buildCategorySection(
                title: 'DİSİPLİN USTASI (TAKİP)',
                accent: _trackingAccent,
                badges: _trackingBadges,
                unlockedIds: unlockedTracking,
              ),
              const SizedBox(height: 32),

              _buildCategorySection(
                title: 'MUTFAK ŞEFİ (BESLENME)',
                accent: _nutritionAccent,
                badges: _nutritionBadges,
                unlockedIds: unlockedNutrition,
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySection({
    required String title,
    required Color accent,
    required List<_BadgeInfo> badges,
    required Set<String> unlockedIds,
  }) {
    final unlockedList = badges.where((b) => unlockedIds.contains(b.id)).toList();
    final lockedList = badges.where((b) => !unlockedIds.contains(b.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '${unlockedList.length}/${badges.length}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (unlockedList.isNotEmpty) ...[
          _sectionHeader('KAZANILANLAR'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: unlockedList.length,
            itemBuilder: (context, i) => _badgeCard(unlockedList[i], unlocked: true, accent: accent),
          ),
          const SizedBox(height: 24),
        ],
        if (lockedList.isNotEmpty) ...[
          _sectionHeader('KİLİTLİ OLANLAR'),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: lockedList.length,
            itemBuilder: (context, i) => _badgeCard(lockedList[i], unlocked: false, accent: accent),
          ),
        ],
      ],
    );
  }

  Widget _statsRow(StreakProvider streak, WeightProvider weight, int totalRozet) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('🔥', '${streak.currentStreak}', 'Antren. Serisi'),
          _vDivider(),
          _statItem('⚖️', '${weight.currentStreak}', 'Takip Serisi'),
          _vDivider(),
          _statItem('🏅', '$totalRozet', 'Toplam Rozet'),
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

  Widget _badgeCard(_BadgeInfo badge, {required bool unlocked, required Color accent}) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: unlocked
            ? Border.all(color: accent.withValues(alpha: 0.4), width: 1.5)
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
                  color: accent,
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
  final int threshold;
  final String thresholdLabel;

  const _BadgeInfo(
    this.id,
    this.title,
    this.description,
    this.emoji,
    this.threshold,
    this.thresholdLabel,
  );
}
