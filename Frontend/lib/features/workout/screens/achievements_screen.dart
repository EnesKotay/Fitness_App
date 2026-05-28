import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streak_provider.dart';
import '../../weight/presentation/providers/weight_provider.dart';
import '../../nutrition/presentation/state/diet_provider.dart';

class AchievementsScreen extends StatelessWidget {
  final String? highlightBadgeId;
  const AchievementsScreen({super.key, this.highlightBadgeId});

  static const _bg = Color(0xFF121212);
  static const _card = Color(0xFF1E1E1E);
  static const _workoutAccent = Color(0xFFCC7A4A);
  static const _trackingAccent = Color(0xFF4DB6AC);
  static const _nutritionAccent = Color(0xFF81C784);

  static final _workoutBadges = [
    _BadgeInfo(
      'first_workout',
      'İlk Adım!',
      'İlk antreni tamamla',
      '🏁',
      1,
      '1 antrenman',
    ),
    _BadgeInfo(
      'seven_workouts',
      '7 Antrenman',
      '7 antren tamamla',
      '🔥',
      7,
      '7 antrenman',
    ),
    _BadgeInfo(
      'fourteen_workouts',
      'Ritim Buldu',
      '14 antrenman tamamla',
      '🥉',
      14,
      '14 antrenman',
    ),
    _BadgeInfo(
      'thirty_workouts',
      '30 Antrenman',
      '30 antren tamamla',
      '💪',
      30,
      '30 antrenman',
    ),
    _BadgeInfo(
      'fifty_workouts',
      'Yarım Yüz',
      '50 antrenman tamamla',
      '🥈',
      50,
      '50 antrenman',
    ),
    _BadgeInfo(
      'hundred_workouts',
      '100 Antrenman',
      '100 antren tamamla',
      '🏆',
      100,
      '100 antrenman',
    ),
    _BadgeInfo(
      'two_fifty_workouts',
      'Demir Arşivi',
      '250 antrenman tamamla',
      '🏛️',
      250,
      '250 antrenman',
    ),
    _BadgeInfo(
      'five_hundred_workouts',
      'Salon Efsanesi',
      '500 antrenman tamamla',
      '💎',
      500,
      '500 antrenman',
    ),
    _BadgeInfo(
      'streak_3',
      '3 Günlük Seri',
      '3 gün üst üste antren yap',
      '🔥',
      3,
      '3 günlük seri',
    ),
    _BadgeInfo(
      'streak_7',
      '7 Günlük Seri',
      '7 gün üst üste antren yap',
      '⚡',
      7,
      '7 günlük seri',
    ),
    _BadgeInfo(
      'streak_14',
      'İki Hafta Alev',
      '14 gün üst üste antren yap',
      '🔥',
      14,
      '14 günlük seri',
    ),
    _BadgeInfo(
      'streak_30',
      '30 Günlük Seri',
      '30 gün üst üste antren yap',
      '👑',
      30,
      '30 günlük seri',
    ),
    _BadgeInfo(
      'streak_60',
      'Çelik Alışkanlık',
      '60 gün üst üste antren yap',
      '🛡️',
      60,
      '60 günlük seri',
    ),
    _BadgeInfo(
      'streak_100',
      'Asfalt Ağlatan',
      '100 gün üst üste spor',
      '🔥',
      100,
      '100 günlük seri',
    ),
    _BadgeInfo(
      'streak_365',
      'Efsanevi Yıl',
      '365 gün antrenman yap',
      '🌟',
      365,
      '1 yıllık seri',
    ),
    _BadgeInfo(
      'task_streak_7',
      'Görev Haftası',
      '7 gün tüm görevleri tamamla',
      '✅',
      7,
      '7 görev günü',
    ),
    _BadgeInfo(
      'task_streak_30',
      'Görev Ustası',
      '30 gün tüm görevleri tamamla',
      '🏅',
      30,
      '30 görev günü',
    ),
    _BadgeInfo(
      'task_streak_60',
      'Rutin Mimarı',
      '60 gün tüm görevleri tamamla',
      '📌',
      60,
      '60 görev günü',
    ),
  ];

  static final _trackingBadges = [
    _BadgeInfo('track_1', 'İlk Tartı', 'İlk kilonu kaydet', '⚖️', 1, '1 kayıt'),
    _BadgeInfo(
      'track_7',
      'Takip Başladı',
      'Toplam 7 kilo kaydı gir',
      '📈',
      7,
      '7 kayıt',
    ),
    _BadgeInfo(
      'track_30',
      'Veri Disiplini',
      'Toplam 30 kilo kaydı gir',
      '📊',
      30,
      '30 kayıt',
    ),
    _BadgeInfo(
      'track_streak_7',
      '7 Gün Takip',
      '7 gün üst üste tartıl',
      '🔥',
      7,
      '7 günlük seri',
    ),
    _BadgeInfo(
      'track_streak_30',
      '30 Gün Takip',
      '30 gün üst üste tartıl',
      '🏆',
      30,
      '30 günlük seri',
    ),
    _BadgeInfo(
      'track_streak_60',
      'Ayna Değil Veri',
      '60 gün üst üste tartıl',
      '🧭',
      60,
      '60 günlük seri',
    ),
    _BadgeInfo(
      'track_streak_100',
      'Disiplin Ustası',
      '100 gün üst üste tartıl',
      '🎯',
      100,
      '100 günlük seri',
    ),
    _BadgeInfo(
      'track_100',
      'Sadık Takipçi',
      'Toplam 100 kayıt gir',
      '💎',
      100,
      '100 kayıt',
    ),
    _BadgeInfo(
      'track_250',
      'Trend Avcısı',
      'Toplam 250 kayıt gir',
      '🔎',
      250,
      '250 kayıt',
    ),
    _BadgeInfo(
      'month_8',
      'Ayın Nabzı',
      'Son 30 günde 8 kayıt gir',
      '🗓️',
      8,
      '8/ay',
    ),
    _BadgeInfo(
      'weight_change_3',
      'İlk Büyük Değişim',
      'Başlangıca göre 3 kg değişim',
      '✨',
      3,
      '3 kg değişim',
    ),
    _BadgeInfo(
      'weight_change_5',
      'Net Dönüşüm',
      'Başlangıca göre 5 kg değişim',
      '🏁',
      5,
      '5 kg değişim',
    ),
    _BadgeInfo(
      'weight_change_10',
      'Büyük Dönüşüm',
      'Başlangıca göre 10 kg değişim',
      '🏆',
      10,
      '10 kg değişim',
    ),
  ];

  static final _nutritionBadges = [
    _BadgeInfo(
      'diet_1',
      'İlk Isırık',
      'İlk yemeğini kaydet',
      '🍎',
      1,
      '1 gün kayıt',
    ),
    _BadgeInfo(
      'diet_streak_3',
      '3 Gün Temiz Başlangıç',
      '3 gün üst üste besin gir',
      '🌱',
      3,
      '3 günlük seri',
    ),
    _BadgeInfo(
      'diet_streak_7',
      'Sağlıklı Hafta',
      '7 gün üst üste besin gir',
      '🥗',
      7,
      '7 günlük seri',
    ),
    _BadgeInfo(
      'diet_streak_14',
      'İki Hafta Şef',
      '14 gün üst üste besin gir',
      '🍳',
      14,
      '14 günlük seri',
    ),
    _BadgeInfo(
      'diet_streak_30',
      'Aşçıbaşı',
      '30 gün üst üste besin gir',
      '👨‍🍳',
      30,
      '30 günlük seri',
    ),
    _BadgeInfo(
      'diet_streak_60',
      'Menü Ustası',
      '60 gün üst üste besin gir',
      '📒',
      60,
      '60 günlük seri',
    ),
    _BadgeInfo(
      'diet_streak_100',
      'Beslenme Efsanesi',
      '100 gün üst üste besin gir',
      '🏆',
      100,
      '100 günlük seri',
    ),
    _BadgeInfo(
      'three_meals',
      'Dengeli Gün',
      'Bugün 3 öğün kaydet',
      '🍽️',
      3,
      '3 öğün',
    ),
    _BadgeInfo(
      'five_entries',
      'Planlı Gün',
      'Bugün 5 besin kaydı gir',
      '📝',
      5,
      '5 kayıt',
    ),
    _BadgeInfo(
      'exact_calories',
      'Tam İsabet',
      'Günlük kaloriyi tam tuttur',
      '🎯',
      1,
      'Kalori Hedefi %5',
    ),
    _BadgeInfo(
      'protein_monster',
      'Protein Canavarı',
      'Protein hedefine ulaş',
      '🥩',
      1,
      'Protein Hedefi',
    ),
    _BadgeInfo(
      'fiber_friend',
      'Lif Dostu',
      'Bugün 25g lif hedefine ulaş',
      '🥦',
      25,
      '25g lif',
    ),
    _BadgeInfo(
      'water_warrior',
      'Su Savaşçısı',
      '2 Litre su hedefine ulaş',
      '💧',
      1,
      '2L Su',
    ),
    _BadgeInfo(
      'hydration_master',
      'Hidrasyon Ustası',
      'Bugün 3 litre su iç',
      '🌊',
      3,
      '3L Su',
    ),
    _BadgeInfo(
      'early_bird',
      'Erkenci Kuş',
      'Sabah 07:00 öncesi aktivite',
      '🌅',
      1,
      '07:00 öncesi',
    ),
    _BadgeInfo(
      'night_owl',
      'Gece Kuşu',
      'Gece 23:00 sonrası aktivite',
      '🦉',
      1,
      '23:00 sonrası',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer3<StreakProvider, WeightProvider, DietProvider>(
      builder: (context, streak, weight, diet, _) {
        // Haftalık rozet — target'a göre dinamik ID
        final weeklyBadgeId = 'weekly_${streak.weeklyWorkoutTarget}_workouts';
        final weeklyBadge = _BadgeInfo(
          weeklyBadgeId,
          'Haftalık Hedef',
          'Bir haftada ${streak.weeklyWorkoutTarget} antrenman tamamla',
          '🎯',
          streak.weeklyWorkoutTarget,
          '${streak.weeklyWorkoutTarget}/hafta',
        );
        final workoutBadges = [
          ..._workoutBadges.sublist(0, 4), // milestone rozetleri
          weeklyBadge, // dinamik haftalık
          ..._workoutBadges.sublist(4), // seri rozetleri
        ];

        // Calculate Unlocked
        final unlockedWorkout = streak.unlockedBadges.toSet();
        if (streak.weeklyChallengeCompleted ||
            streak.unlockedBadges.contains(weeklyBadgeId)) {
          unlockedWorkout.add(weeklyBadgeId);
        }
        for (final badge in workoutBadges) {
          if (_workoutProgressFor(badge, streak).isComplete) {
            unlockedWorkout.add(badge.id);
          }
        }

        final unlockedTracking = <String>{};
        for (final badge in _trackingBadges) {
          if (_trackingProgressFor(badge, weight).isComplete) {
            unlockedTracking.add(badge.id);
          }
        }

        final unlockedNutrition = <String>{};
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
        for (final badge in _nutritionBadges) {
          if (_nutritionProgressFor(badge, diet).isComplete) {
            unlockedNutrition.add(badge.id);
          }
        }

        final totalUnlocked =
            unlockedWorkout.length +
            unlockedTracking.length +
            unlockedNutrition.length;
        final totalBadges =
            workoutBadges.length +
            _trackingBadges.length +
            _nutritionBadges.length;
        final nextBadge = _findNextBadge(
          workoutBadges: workoutBadges,
          unlockedWorkout: unlockedWorkout,
          trackingBadges: _trackingBadges,
          unlockedTracking: unlockedTracking,
          nutritionBadges: _nutritionBadges,
          unlockedNutrition: unlockedNutrition,
          workoutProgress: (badge) => _workoutProgressFor(badge, streak),
          trackingProgress: (badge) => _trackingProgressFor(badge, weight),
          nutritionProgress: (badge) => _nutritionProgressFor(badge, diet),
        );

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _bg,
            elevation: 0,
            centerTitle: true,
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
              _heroPanel(
                streak: streak,
                weight: weight,
                totalUnlocked: totalUnlocked,
                totalBadges: totalBadges,
                nextBadge: nextBadge,
              ),
              const SizedBox(height: 24),

              _buildCategorySection(
                title: 'DEMİR BÜKÜCÜ (ANTRENMAN)',
                accent: _workoutAccent,
                badges: workoutBadges,
                unlockedIds: unlockedWorkout,
                progressFor: (badge) => _workoutProgressFor(badge, streak),
              ),
              const SizedBox(height: 32),

              _buildCategorySection(
                title: 'DİSİPLİN USTASI (TAKİP)',
                accent: _trackingAccent,
                badges: _trackingBadges,
                unlockedIds: unlockedTracking,
                progressFor: (badge) => _trackingProgressFor(badge, weight),
              ),
              const SizedBox(height: 32),

              _buildCategorySection(
                title: 'MUTFAK ŞEFİ (BESLENME)',
                accent: _nutritionAccent,
                badges: _nutritionBadges,
                unlockedIds: unlockedNutrition,
                progressFor: (badge) => _nutritionProgressFor(badge, diet),
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
    required _BadgeProgress Function(_BadgeInfo badge) progressFor,
  }) {
    final unlockedList = badges
        .where((b) => unlockedIds.contains(b.id))
        .toList();
    final lockedList = badges
        .where((b) => !unlockedIds.contains(b.id))
        .toList();
    final ratio = badges.isEmpty ? 0.0 : unlockedList.length / badges.length;
    final nextLocked = lockedList.isEmpty
        ? null
        : (lockedList.toList()..sort(
                (a, b) => progressFor(b).ratio.compareTo(progressFor(a).ratio),
              ))
              .first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _categoryHeader(
          title: title,
          accent: accent,
          unlocked: unlockedList.length,
          total: badges.length,
          ratio: ratio,
          nextBadge: nextLocked,
          nextProgress: nextLocked == null ? null : progressFor(nextLocked),
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
            itemBuilder: (context, i) => _badgeCard(
              unlockedList[i],
              unlocked: true,
              accent: accent,
              progress: progressFor(unlockedList[i]),
            ),
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
              childAspectRatio: 0.92,
            ),
            itemCount: lockedList.length,
            itemBuilder: (context, i) => _badgeCard(
              lockedList[i],
              unlocked: false,
              accent: accent,
              progress: progressFor(lockedList[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _heroPanel({
    required StreakProvider streak,
    required WeightProvider weight,
    required int totalUnlocked,
    required int totalBadges,
    required _NextBadge? nextBadge,
  }) {
    final completion = totalBadges == 0 ? 0.0 : totalUnlocked / totalBadges;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _workoutAccent.withValues(alpha: 0.26),
            _card,
            _bg.withValues(alpha: 0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _workoutAccent.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                  border: Border.all(
                    color: _workoutAccent.withValues(alpha: 0.45),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text('🏆', style: TextStyle(fontSize: 30)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$totalUnlocked/$totalBadges kupa açıldı',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nextBadge == null
                          ? 'Tüm kupalar sende.'
                          : 'Sıradaki: ${nextBadge.badge.title}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _percentRing(completion, _workoutAccent),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completion.clamp(0, 1),
              minHeight: 7,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(_workoutAccent),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  icon: '🔥',
                  value: '${streak.currentStreak}',
                  label: 'Antrenman serisi',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  icon: '⚖️',
                  value: '${weight.currentStreak}',
                  label: 'Takip serisi',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniStat(
                  icon: '🎯',
                  value:
                      '${streak.weeklyWorkoutCount}/${streak.weeklyWorkoutTarget}',
                  label: 'Haftalık',
                ),
              ),
            ],
          ),
          if (nextBadge != null) ...[
            const SizedBox(height: 14),
            _nextBadgeStrip(nextBadge),
          ],
        ],
      ),
    );
  }

  Widget _miniStat({
    required String icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _percentRing(double value, Color accent) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0, 1),
            strokeWidth: 4,
            backgroundColor: Colors.white.withValues(alpha: 0.09),
            valueColor: AlwaysStoppedAnimation(accent),
          ),
          Text(
            '%${(value * 100).round()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextBadgeStrip(_NextBadge next) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: next.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Text(next.badge.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next.progress.remainingLabel,
                  style: TextStyle(
                    color: next.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next.badge.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 72,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: next.progress.ratio,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(next.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryHeader({
    required String title,
    required Color accent,
    required int unlocked,
    required int total,
    required double ratio,
    required _BadgeInfo? nextBadge,
    required _BadgeProgress? nextProgress,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.workspace_premium_rounded, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Text(
                '$unlocked/$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.07),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          if (nextBadge != null && nextProgress != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(nextBadge.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${nextBadge.title} için ${nextProgress.remainingLabel.toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.58),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _badgeCard(
    _BadgeInfo badge, {
    required bool unlocked,
    required Color accent,
    required _BadgeProgress progress,
  }) {
    final isHighlighted =
        highlightBadgeId != null && badge.id == highlightBadgeId;
    return Container(
      decoration: BoxDecoration(
        gradient: unlocked
            ? LinearGradient(
                colors: [accent.withValues(alpha: 0.26), _card],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: unlocked ? null : _card,
        borderRadius: BorderRadius.circular(20),
        border: isHighlighted
            ? Border.all(color: accent, width: 2.5)
            : unlocked
            ? Border.all(color: accent.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: Colors.white.withValues(alpha: 0.055)),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: -4,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unlocked
                            ? Colors.white.withValues(alpha: 0.10)
                            : Colors.black.withValues(alpha: 0.18),
                        border: Border.all(
                          color: unlocked
                              ? accent.withValues(alpha: 0.34)
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unlocked ? badge.emoji : '🔒',
                        style: TextStyle(
                          fontSize: 26,
                          color: unlocked ? null : Colors.white24,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (unlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'AÇIK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  badge.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unlocked ? Colors.white : Colors.white54,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  unlocked ? badge.description : progress.detailLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unlocked ? Colors.white60 : Colors.white30,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.ratio,
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.07),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          progress.valueLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.40),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        progress.remainingLabel,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!unlocked)
            Positioned(
              right: -10,
              top: -8,
              child: Opacity(
                opacity: 0.06,
                child: Text(badge.emoji, style: const TextStyle(fontSize: 74)),
              ),
            ),
        ],
      ),
    );
  }

  _BadgeProgress _workoutProgressFor(_BadgeInfo badge, StreakProvider streak) {
    if (badge.id.startsWith('weekly_')) {
      return _BadgeProgress.count(
        current: streak.weeklyWorkoutCount,
        target: streak.weeklyWorkoutTarget,
        unit: 'antrenman',
      );
    }
    if (badge.id.startsWith('task_streak_')) {
      return _BadgeProgress.count(
        current: streak.taskStreak,
        target: badge.threshold,
        unit: 'görev günü',
      );
    }
    if (badge.id.startsWith('streak_')) {
      return _BadgeProgress.count(
        current: streak.currentStreak,
        target: badge.threshold,
        unit: 'gün',
      );
    }
    return _BadgeProgress.count(
      current: streak.totalWorkouts,
      target: badge.threshold,
      unit: 'antrenman',
    );
  }

  _BadgeProgress _trackingProgressFor(_BadgeInfo badge, WeightProvider weight) {
    if (badge.id.startsWith('track_streak_')) {
      return _BadgeProgress.count(
        current: weight.currentStreak,
        target: badge.threshold,
        unit: 'gün',
      );
    }
    if (badge.id.startsWith('track_')) {
      return _BadgeProgress.count(
        current: weight.entries.length,
        target: badge.threshold,
        unit: 'kayıt',
      );
    }
    if (badge.id == 'month_8') {
      return _BadgeProgress.count(
        current: weight.last30DaysCount,
        target: badge.threshold,
        unit: 'aylık kayıt',
      );
    }
    if (badge.id.startsWith('weight_change_')) {
      return _BadgeProgress.decimal(
        current: weight.totalChange.abs(),
        target: badge.threshold.toDouble(),
        unit: 'kg',
        detail: '${badge.threshold} kg değişim yakala',
      );
    }
    return _BadgeProgress.count(
      current: 0,
      target: badge.threshold,
      unit: 'adım',
    );
  }

  _BadgeProgress _nutritionProgressFor(_BadgeInfo badge, DietProvider diet) {
    switch (badge.id) {
      case 'three_meals':
        return _BadgeProgress.count(
          current: diet.entries.map((e) => e.mealType).toSet().length,
          target: badge.threshold,
          unit: 'öğün',
        );
      case 'five_entries':
        return _BadgeProgress.count(
          current: diet.entries.length,
          target: badge.threshold,
          unit: 'kayıt',
        );
      case 'exact_calories':
        final target = diet.dailyTargetKcal ?? 0;
        final consumed = diet.totals.totalKcal;
        if (target <= 0) {
          return const _BadgeProgress(
            ratio: 0,
            valueLabel: 'Hedef yok',
            remainingLabel: 'Profil gerek',
            detailLabel: 'Günlük kalori hedefini ayarla',
          );
        }
        final diff = (target - consumed).abs();
        final tolerance = target * 0.05;
        final ratio = (1 - (diff / target)).clamp(0.0, 1.0);
        return _BadgeProgress(
          ratio: diff <= tolerance ? 1 : ratio,
          valueLabel: '${consumed.round()}/${target.round()} kcal',
          remainingLabel: diff <= tolerance
              ? 'Hazır'
              : '${diff.round()} kcal fark',
          detailLabel: 'Hedefin %5 bandına gir',
        );
      case 'protein_monster':
        return _BadgeProgress.decimal(
          current: diet.totals.totalProtein,
          target: diet.macroTargets.protein,
          unit: 'g protein',
          detail: 'Protein hedefini tamamla',
        );
      case 'fiber_friend':
        return _BadgeProgress.decimal(
          current: diet.totals.totalFiber,
          target: badge.threshold.toDouble(),
          unit: 'g lif',
          detail: 'Lif hedefini tamamla',
        );
      case 'water_warrior':
        return _BadgeProgress.decimal(
          current: diet.waterLiters,
          target: 2.0,
          unit: 'L su',
          detail: 'Günlük su hedefini tamamla',
        );
      case 'hydration_master':
        return _BadgeProgress.decimal(
          current: diet.waterLiters,
          target: 3.0,
          unit: 'L su',
          detail: '3 litre suya ulaş',
        );
      case 'early_bird':
        final complete = _hasEarlyActivity(diet);
        return _BadgeProgress(
          ratio: complete ? 1 : 0,
          valueLabel: '${complete ? 1 : 0}/1 aktivite',
          remainingLabel: complete ? 'Hazır' : '1 kaldı',
          detailLabel: '07:00 öncesi kayıt gir',
        );
      case 'night_owl':
        final complete = _hasNightActivity(diet);
        return _BadgeProgress(
          ratio: complete ? 1 : 0,
          valueLabel: '${complete ? 1 : 0}/1 aktivite',
          remainingLabel: complete ? 'Hazır' : '1 kaldı',
          detailLabel: '23:00 sonrası kayıt gir',
        );
      default:
        return _BadgeProgress.count(
          current: diet.currentStreak,
          target: badge.threshold,
          unit: 'gün',
        );
    }
  }

  _NextBadge? _findNextBadge({
    required List<_BadgeInfo> workoutBadges,
    required Set<String> unlockedWorkout,
    required List<_BadgeInfo> trackingBadges,
    required Set<String> unlockedTracking,
    required List<_BadgeInfo> nutritionBadges,
    required Set<String> unlockedNutrition,
    required _BadgeProgress Function(_BadgeInfo badge) workoutProgress,
    required _BadgeProgress Function(_BadgeInfo badge) trackingProgress,
    required _BadgeProgress Function(_BadgeInfo badge) nutritionProgress,
  }) {
    final candidates = <_NextBadge>[
      for (final badge in workoutBadges)
        if (!unlockedWorkout.contains(badge.id))
          _NextBadge(badge, _workoutAccent, workoutProgress(badge)),
      for (final badge in trackingBadges)
        if (!unlockedTracking.contains(badge.id))
          _NextBadge(badge, _trackingAccent, trackingProgress(badge)),
      for (final badge in nutritionBadges)
        if (!unlockedNutrition.contains(badge.id))
          _NextBadge(badge, _nutritionAccent, nutritionProgress(badge)),
    ];
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.progress.ratio.compareTo(a.progress.ratio));
    return candidates.first;
  }

  bool _hasEarlyActivity(DietProvider diet) {
    for (final entry in diet.entries) {
      if (entry.createdAt.hour < 7) return true;
    }
    for (final workout in diet.todayWorkouts) {
      if (workout.workoutDate.hour < 7) return true;
    }
    return false;
  }

  bool _hasNightActivity(DietProvider diet) {
    for (final entry in diet.entries) {
      if (entry.createdAt.hour >= 23) return true;
    }
    for (final workout in diet.todayWorkouts) {
      if (workout.workoutDate.hour >= 23) return true;
    }
    return false;
  }
}

class _BadgeProgress {
  final double ratio;
  final String valueLabel;
  final String remainingLabel;
  final String detailLabel;

  const _BadgeProgress({
    required this.ratio,
    required this.valueLabel,
    required this.remainingLabel,
    required this.detailLabel,
  });

  bool get isComplete => ratio >= 1;

  factory _BadgeProgress.count({
    required int current,
    required int target,
    required String unit,
  }) {
    final safeTarget = target <= 0 ? 1 : target;
    final safeCurrent = current.clamp(0, safeTarget);
    final remaining = (safeTarget - safeCurrent).clamp(0, safeTarget);
    return _BadgeProgress(
      ratio: safeCurrent / safeTarget,
      valueLabel: '$safeCurrent/$safeTarget $unit',
      remainingLabel: remaining == 0 ? 'Hazır' : '$remaining kaldı',
      detailLabel: '$safeTarget $unit tamamla',
    );
  }

  factory _BadgeProgress.decimal({
    required double current,
    required double target,
    required String unit,
    required String detail,
  }) {
    final safeTarget = target <= 0 ? 1.0 : target;
    final safeCurrent = current.clamp(0, safeTarget).toDouble();
    final remaining = (safeTarget - safeCurrent).clamp(0, safeTarget);
    final useOneDecimal = unit.startsWith('L') || unit == 'kg';
    final currentText = useOneDecimal
        ? safeCurrent.toStringAsFixed(1)
        : safeCurrent.round().toString();
    final targetText = useOneDecimal
        ? safeTarget.toStringAsFixed(1)
        : safeTarget.round().toString();
    final remainingText = useOneDecimal
        ? remaining.toStringAsFixed(1)
        : remaining.round().toString();
    return _BadgeProgress(
      ratio: safeCurrent / safeTarget,
      valueLabel: '$currentText/$targetText $unit',
      remainingLabel: remaining <= 0 ? 'Hazır' : '$remainingText kaldı',
      detailLabel: detail,
    );
  }
}

class _NextBadge {
  final _BadgeInfo badge;
  final Color accent;
  final _BadgeProgress progress;

  const _NextBadge(this.badge, this.accent, this.progress);
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
