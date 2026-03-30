import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının antrenman serisini (streak) ve başarılarını yönetir.
class StreakProvider with ChangeNotifier {
  static const _kStreakKey = 'workout_streak';
  static const _kLongestStreakKey = 'longest_streak';
  static const _kLastWorkoutDateKey = 'last_workout_date';
  static const _kTotalWorkoutsKey = 'total_workouts';
  static const _kUnlockedBadgesKey = 'unlocked_badges';

  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalWorkouts = 0;
  DateTime? _lastWorkoutDate;
  List<String> _unlockedBadges = [];

  // Yeni kazanılan rozet (overlay tetikler)
  AchievementBadge? _justUnlockedBadge;

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalWorkouts => _totalWorkouts;
  DateTime? get lastWorkoutDate => _lastWorkoutDate;
  List<String> get unlockedBadges => List.unmodifiable(_unlockedBadges);
  AchievementBadge? get justUnlockedBadge => _justUnlockedBadge;

  bool get isOnFire => _currentStreak >= 3;

  /// SharedPreferences'tan yükle
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentStreak = prefs.getInt(_kStreakKey) ?? 0;
    _longestStreak = prefs.getInt(_kLongestStreakKey) ?? 0;
    _totalWorkouts = prefs.getInt(_kTotalWorkoutsKey) ?? 0;
    _unlockedBadges = prefs.getStringList(_kUnlockedBadgesKey) ?? [];
    final lastDateStr = prefs.getString(_kLastWorkoutDateKey);
    if (lastDateStr != null) {
      _lastWorkoutDate = DateTime.tryParse(lastDateStr);
    }
    notifyListeners();
  }

  /// Antrenman tamamlandığında çağrılır. Streak'i günceller.
  /// Döndürür: yeni rozet kazanıldıysa [AchievementBadge], yoksa null.
  Future<AchievementBadge?> onWorkoutCompleted() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Bugün zaten sayıldıysa tekrar sayma
    if (_lastWorkoutDate != null) {
      final last = DateTime(
        _lastWorkoutDate!.year,
        _lastWorkoutDate!.month,
        _lastWorkoutDate!.day,
      );
      if (last == today) {
        return null; // Bugün zaten kaydedilmiş
      }

      // Dün çalışmışsa seri devam eder; yoksa sıfırla
      final yesterday = today.subtract(const Duration(days: 1));
      if (last == yesterday) {
        _currentStreak++;
      } else {
        _currentStreak = 1;
      }
    } else {
      _currentStreak = 1;
    }

    _lastWorkoutDate = today;
    _totalWorkouts++;

    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }

    // Rozet kontrolü
    AchievementBadge? newBadge;
    newBadge ??= _checkMilestoneBadge();

    _justUnlockedBadge = newBadge;

    await _persist();
    notifyListeners();
    return newBadge;
  }

  /// Rozet gösteriminden sonra sıfırla
  void clearJustUnlocked() {
    _justUnlockedBadge = null;
    notifyListeners();
  }

  AchievementBadge? _checkMilestoneBadge() {
    final milestones = {
      1: AchievementBadge(
        id: 'first_workout',
        title: 'İlk Adım!',
        description: 'İlk antreni tamamladın.',
        emoji: '🏁',
        isStreak: false,
      ),
      7: AchievementBadge(
        id: 'seven_workouts',
        title: '7 Antrenman',
        description: '7 antreni geride bıraktın!',
        emoji: '🔥',
        isStreak: false,
      ),
      30: AchievementBadge(
        id: 'thirty_workouts',
        title: '30 Antrenman',
        description: 'Aylık hedefe ulaştın!',
        emoji: '💪',
        isStreak: false,
      ),
      100: AchievementBadge(
        id: 'hundred_workouts',
        title: '100 Antrenman',
        description: '100 antreni geçtin! Efsane!',
        emoji: '🏆',
        isStreak: false,
      ),
    };

    final streakMilestones = {
      3: AchievementBadge(
        id: 'streak_3',
        title: '3 Günlük Seri!',
        description: '3 gün üst üste antrendi.',
        emoji: '🔥',
        isStreak: true,
      ),
      7: AchievementBadge(
        id: 'streak_7',
        title: '7 Günlük Seri!',
        description: 'Bir hafta boyunca durmadın!',
        emoji: '⚡',
        isStreak: true,
      ),
      30: AchievementBadge(
        id: 'streak_30',
        title: '30 Günlük Seri!',
        description: 'Bir ay kesintisiz antrenman!',
        emoji: '👑',
        isStreak: true,
      ),
    };

    // Toplam antrenman rozeti
    if (milestones.containsKey(_totalWorkouts)) {
      final badge = milestones[_totalWorkouts]!;
      if (!_unlockedBadges.contains(badge.id)) {
        _unlockedBadges.add(badge.id);
        return badge;
      }
    }

    // Seri rozeti
    if (streakMilestones.containsKey(_currentStreak)) {
      final badge = streakMilestones[_currentStreak]!;
      if (!_unlockedBadges.contains(badge.id)) {
        _unlockedBadges.add(badge.id);
        return badge;
      }
    }

    return null;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStreakKey, _currentStreak);
    await prefs.setInt(_kLongestStreakKey, _longestStreak);
    await prefs.setInt(_kTotalWorkoutsKey, _totalWorkouts);
    await prefs.setStringList(_kUnlockedBadgesKey, _unlockedBadges);
    if (_lastWorkoutDate != null) {
      await prefs.setString(
          _kLastWorkoutDateKey, _lastWorkoutDate!.toIso8601String());
    }
  }

  void reset() {
    _currentStreak = 0;
    _longestStreak = 0;
    _totalWorkouts = 0;
    _lastWorkoutDate = null;
    _unlockedBadges = [];
    _justUnlockedBadge = null;
    notifyListeners();
  }
}

/// Rozet modeli
class AchievementBadge {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool isStreak;

  const AchievementBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
    required this.isStreak,
  });
}
