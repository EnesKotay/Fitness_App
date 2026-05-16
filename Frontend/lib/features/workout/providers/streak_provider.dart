import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının antrenman serisini (streak) ve başarılarını yönetir.
class StreakProvider with ChangeNotifier {
  static const _kStreakKey = 'workout_streak';
  static const _kLongestStreakKey = 'longest_streak';
  static const _kLastWorkoutDateKey = 'last_workout_date';
  static const _kTotalWorkoutsKey = 'total_workouts';
  static const _kUnlockedBadgesKey = 'unlocked_badges';
  static const _kTaskStreakKey = 'task_streak';
  static const _kLongestTaskStreakKey = 'longest_task_streak';
  static const _kLastTaskCompletionDateKey = 'last_task_completion_date';

  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalWorkouts = 0;
  DateTime? _lastWorkoutDate;
  List<String> _unlockedBadges = [];
  int _taskStreak = 0;
  int _longestTaskStreak = 0;
  DateTime? _lastTaskCompletionDate;

  // Yeni kazanılan rozet (overlay tetikler)
  AchievementBadge? _justUnlockedBadge;

  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalWorkouts => _totalWorkouts;
  DateTime? get lastWorkoutDate => _lastWorkoutDate;
  List<String> get unlockedBadges => List.unmodifiable(_unlockedBadges);
  AchievementBadge? get justUnlockedBadge => _justUnlockedBadge;
  int get taskStreak => _taskStreak;
  int get longestTaskStreak => _longestTaskStreak;

  bool get isOnFire => _currentStreak >= 3;

  /// SharedPreferences'tan yükle
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentStreak = prefs.getInt(_kStreakKey) ?? 0;
    _longestStreak = prefs.getInt(_kLongestStreakKey) ?? 0;
    _totalWorkouts = prefs.getInt(_kTotalWorkoutsKey) ?? 0;
    _unlockedBadges = prefs.getStringList(_kUnlockedBadgesKey) ?? [];
    _taskStreak = prefs.getInt(_kTaskStreakKey) ?? 0;
    _longestTaskStreak = prefs.getInt(_kLongestTaskStreakKey) ?? 0;
    final lastDateStr = prefs.getString(_kLastWorkoutDateKey);
    if (lastDateStr != null) {
      _lastWorkoutDate = DateTime.tryParse(lastDateStr);
    }
    final lastTaskDateStr = prefs.getString(_kLastTaskCompletionDateKey);
    if (lastTaskDateStr != null) {
      _lastTaskCompletionDate = DateTime.tryParse(lastTaskDateStr);
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

  /// Günlük tüm görevler tamamlandığında çağrılır. Task streak'i günceller.
  /// Döndürür: yeni rozet kazanıldıysa [AchievementBadge], yoksa null.
  Future<AchievementBadge?> onDailyTasksAllCompleted() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastTaskCompletionDate != null) {
      final last = DateTime(
        _lastTaskCompletionDate!.year,
        _lastTaskCompletionDate!.month,
        _lastTaskCompletionDate!.day,
      );
      if (last == today) return null;

      final yesterday = today.subtract(const Duration(days: 1));
      if (last == yesterday) {
        _taskStreak++;
      } else {
        _taskStreak = 1;
      }
    } else {
      _taskStreak = 1;
    }

    _lastTaskCompletionDate = today;
    if (_taskStreak > _longestTaskStreak) {
      _longestTaskStreak = _taskStreak;
    }

    final badge = _checkTaskStreakBadge();
    _justUnlockedBadge = badge;
    await _persist();
    notifyListeners();
    return badge;
  }

  AchievementBadge? _checkTaskStreakBadge() {
    final milestones = <int, AchievementBadge>{
      7: AchievementBadge(
        id: 'task_streak_7',
        title: '7 Günlük Görev Serisi!',
        description: '7 gün boyunca tüm görevleri tamamladın!',
        emoji: '✅',
        isStreak: true,
      ),
      30: AchievementBadge(
        id: 'task_streak_30',
        title: '30 Günlük Görev Serisi!',
        description: 'Bir ay boyunca tüm görevleri tamamladın!',
        emoji: '🏅',
        isStreak: true,
      ),
    };
    final badge = milestones[_taskStreak];
    if (badge == null) return null;
    if (_unlockedBadges.contains(badge.id)) return null;
    _unlockedBadges.add(badge.id);
    return badge;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kStreakKey, _currentStreak);
    await prefs.setInt(_kLongestStreakKey, _longestStreak);
    await prefs.setInt(_kTotalWorkoutsKey, _totalWorkouts);
    await prefs.setStringList(_kUnlockedBadgesKey, _unlockedBadges);
    await prefs.setInt(_kTaskStreakKey, _taskStreak);
    await prefs.setInt(_kLongestTaskStreakKey, _longestTaskStreak);
    if (_lastWorkoutDate != null) {
      await prefs.setString(
          _kLastWorkoutDateKey, _lastWorkoutDate!.toIso8601String());
    }
    if (_lastTaskCompletionDate != null) {
      await prefs.setString(
          _kLastTaskCompletionDateKey, _lastTaskCompletionDate!.toIso8601String());
    }
  }

  Future<void> reset() async {
    _currentStreak = 0;
    _longestStreak = 0;
    _totalWorkouts = 0;
    _lastWorkoutDate = null;
    _unlockedBadges = [];
    _justUnlockedBadge = null;
    _taskStreak = 0;
    _longestTaskStreak = 0;
    _lastTaskCompletionDate = null;
    notifyListeners();
    await _persist();
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
