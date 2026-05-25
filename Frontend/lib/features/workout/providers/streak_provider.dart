import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/storage_helper.dart';

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
  static const _kWorkoutDatesKey = 'workout_dates';
  static const _kWeeklyWorkoutTargetKey = 'weekly_workout_target';
  static const _kStatsUpdatedAtKey = 'motivation_stats_updated_at';

  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalWorkouts = 0;
  DateTime? _lastWorkoutDate;
  List<String> _unlockedBadges = [];
  List<String> _workoutDates = [];
  int _taskStreak = 0;
  int _longestTaskStreak = 0;
  DateTime? _lastTaskCompletionDate;
  int _weeklyWorkoutTarget = 3;
  String? _activeScope;
  Future<void> Function(Map<String, dynamic> stats)? _remoteSync;
  bool _isApplyingRemote = false;
  Timer? _syncDebounce;

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
  int get weeklyWorkoutTarget => _weeklyWorkoutTarget;
  int get weeklyWorkoutCount => _workoutDates.where((raw) {
    final date = DateTime.tryParse(raw);
    return date != null && _isInCurrentWeek(date, DateTime.now());
  }).length;
  double get weeklyChallengeProgress => _weeklyWorkoutTarget <= 0
      ? 0
      : (weeklyWorkoutCount / _weeklyWorkoutTarget).clamp(0, 1).toDouble();
  bool get weeklyChallengeCompleted =>
      weeklyWorkoutCount >= _weeklyWorkoutTarget;

  bool get isOnFire => _currentStreak >= 3;

  /// SharedPreferences'tan yükle
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _activeScope = StorageHelper.getUserStorageSuffix();
    _currentStreak = prefs.getInt(_key(_kStreakKey)) ?? 0;
    _longestStreak = prefs.getInt(_key(_kLongestStreakKey)) ?? 0;
    _totalWorkouts = prefs.getInt(_key(_kTotalWorkoutsKey)) ?? 0;
    _unlockedBadges = prefs.getStringList(_key(_kUnlockedBadgesKey)) ?? [];
    _workoutDates = prefs.getStringList(_key(_kWorkoutDatesKey)) ?? [];
    _taskStreak = prefs.getInt(_key(_kTaskStreakKey)) ?? 0;
    _longestTaskStreak = prefs.getInt(_key(_kLongestTaskStreakKey)) ?? 0;
    _weeklyWorkoutTarget = prefs.getInt(_key(_kWeeklyWorkoutTargetKey)) ?? 3;
    final lastDateStr = prefs.getString(_key(_kLastWorkoutDateKey));
    if (lastDateStr != null) {
      _lastWorkoutDate = DateTime.tryParse(lastDateStr);
    } else {
      _lastWorkoutDate = null;
    }
    final lastTaskDateStr = prefs.getString(_key(_kLastTaskCompletionDateKey));
    if (lastTaskDateStr != null) {
      _lastTaskCompletionDate = DateTime.tryParse(lastTaskDateStr);
    } else {
      _lastTaskCompletionDate = null;
    }
    notifyListeners();
  }

  Future<void> bindAccount({
    required int? userId,
    required String? remoteStatsJson,
    required Future<void> Function(Map<String, dynamic> stats)? onRemoteSync,
  }) async {
    _remoteSync = userId != null && userId > 0 ? onRemoteSync : null;
    final scope = StorageHelper.getUserStorageSuffix();
    if (_activeScope != scope) {
      await init();
    }
    if (remoteStatsJson != null && remoteStatsJson.trim().isNotEmpty) {
      await _mergeRemoteStats(remoteStatsJson);
    }
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
    final todayKey = _dateKey(today);
    if (!_workoutDates.contains(todayKey)) {
      _workoutDates.add(todayKey);
    }
    _pruneOldWorkoutDates();

    if (_currentStreak > _longestStreak) {
      _longestStreak = _currentStreak;
    }

    // Rozet kontrolü
    AchievementBadge? newBadge;
    newBadge ??= _checkMilestoneBadge();
    newBadge ??= _checkWeeklyChallengeBadge();

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
    await prefs.setInt(_key(_kStreakKey), _currentStreak);
    await prefs.setInt(_key(_kLongestStreakKey), _longestStreak);
    await prefs.setInt(_key(_kTotalWorkoutsKey), _totalWorkouts);
    await prefs.setStringList(_key(_kUnlockedBadgesKey), _unlockedBadges);
    await prefs.setStringList(_key(_kWorkoutDatesKey), _workoutDates);
    await prefs.setInt(_key(_kTaskStreakKey), _taskStreak);
    await prefs.setInt(_key(_kLongestTaskStreakKey), _longestTaskStreak);
    await prefs.setInt(_key(_kWeeklyWorkoutTargetKey), _weeklyWorkoutTarget);
    await prefs.setString(
      _key(_kStatsUpdatedAtKey),
      DateTime.now().toIso8601String(),
    );
    if (_lastWorkoutDate != null) {
      await prefs.setString(
        _key(_kLastWorkoutDateKey),
        _lastWorkoutDate!.toIso8601String(),
      );
    }
    if (_lastTaskCompletionDate != null) {
      await prefs.setString(
        _key(_kLastTaskCompletionDateKey),
        _lastTaskCompletionDate!.toIso8601String(),
      );
    }
    if (!_isApplyingRemote && _remoteSync != null) {
      _syncDebounce?.cancel();
      _syncDebounce = Timer(const Duration(seconds: 30), () {
        final fn = _remoteSync;
        if (fn != null) {
          unawaited(fn(toRemoteStats()).catchError((_) {}));
        }
      });
    }
  }

  @override
  void dispose() {
    _syncDebounce?.cancel();
    super.dispose();
  }

  Map<String, dynamic> toRemoteStats() => {
    'currentStreak': _currentStreak,
    'longestStreak': _longestStreak,
    'totalWorkouts': _totalWorkouts,
    'lastWorkoutDate': _lastWorkoutDate?.toIso8601String(),
    'unlockedBadges': _unlockedBadges,
    'workoutDates': _workoutDates,
    'taskStreak': _taskStreak,
    'longestTaskStreak': _longestTaskStreak,
    'lastTaskCompletionDate': _lastTaskCompletionDate?.toIso8601String(),
    'weeklyWorkoutTarget': _weeklyWorkoutTarget,
    'weeklyWorkoutCount': weeklyWorkoutCount,
    'updatedAt': DateTime.now().toIso8601String(),
  };

  Future<void> reset() async {
    _syncDebounce?.cancel();
    _syncDebounce = null;
    _currentStreak = 0;
    _longestStreak = 0;
    _totalWorkouts = 0;
    _lastWorkoutDate = null;
    _unlockedBadges = [];
    _workoutDates = [];
    _justUnlockedBadge = null;
    _taskStreak = 0;
    _longestTaskStreak = 0;
    _lastTaskCompletionDate = null;
    _weeklyWorkoutTarget = 3;
    notifyListeners();
    await _persist();
  }

  AchievementBadge? _checkWeeklyChallengeBadge() {
    if (!weeklyChallengeCompleted) return null;
    final badgeId = 'weekly_${_weeklyWorkoutTarget}_workouts';
    final badge = AchievementBadge(
      id: badgeId,
      title: 'Haftalık Hedef Tamam!',
      description: 'Bu hafta $_weeklyWorkoutTarget antrenman hedefini bitirdin.',
      emoji: '🎯',
      isStreak: false,
    );
    if (_unlockedBadges.contains(badge.id)) return null;
    _unlockedBadges.add(badge.id);
    return badge;
  }

  /// 90 günden eski workout tarihlerini listeden temizle.
  void _pruneOldWorkoutDates() {
    final cutoff = DateTime.now().subtract(const Duration(days: 90));
    _workoutDates = _workoutDates.where((raw) {
      final date = DateTime.tryParse(raw);
      return date != null && date.isAfter(cutoff);
    }).toList();
  }

  Future<void> _mergeRemoteStats(String raw) async {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final remote = Map<String, dynamic>.from(decoded);
      final prefs = await SharedPreferences.getInstance();
      final localUpdatedAt = DateTime.tryParse(
        prefs.getString(_key(_kStatsUpdatedAtKey)) ?? '',
      );
      final remoteUpdatedAt = DateTime.tryParse(
        remote['updatedAt']?.toString() ?? '',
      );
      if (localUpdatedAt != null &&
          remoteUpdatedAt != null &&
          !remoteUpdatedAt.isAfter(localUpdatedAt)) {
        return;
      }

      _isApplyingRemote = true;
      _currentStreak = _asInt(remote['currentStreak'], _currentStreak);
      _longestStreak = _asInt(remote['longestStreak'], _longestStreak);
      _totalWorkouts = _asInt(remote['totalWorkouts'], _totalWorkouts);
      _lastWorkoutDate =
          DateTime.tryParse(remote['lastWorkoutDate']?.toString() ?? '') ??
          _lastWorkoutDate;
      _unlockedBadges = _asStringList(remote['unlockedBadges']).isEmpty
          ? _unlockedBadges
          : _asStringList(remote['unlockedBadges']);
      _workoutDates = _asStringList(remote['workoutDates']).isEmpty
          ? _workoutDates
          : _asStringList(remote['workoutDates']);
      _taskStreak = _asInt(remote['taskStreak'], _taskStreak);
      _longestTaskStreak = _asInt(
        remote['longestTaskStreak'],
        _longestTaskStreak,
      );
      _lastTaskCompletionDate =
          DateTime.tryParse(
            remote['lastTaskCompletionDate']?.toString() ?? '',
          ) ??
          _lastTaskCompletionDate;
      _weeklyWorkoutTarget = _asInt(
        remote['weeklyWorkoutTarget'],
        _weeklyWorkoutTarget,
      );
      await _persist();
      _isApplyingRemote = false;
      notifyListeners();
    } catch (_) {
      _isApplyingRemote = false;
    }
  }

  String _key(String base) => '${base}_${StorageHelper.getUserStorageSuffix()}';

  static String _dateKey(DateTime date) =>
      DateTime(date.year, date.month, date.day).toIso8601String();

  static bool _isInCurrentWeek(DateTime date, DateTime now) {
    final currentDay = DateTime(now.year, now.month, now.day);
    final start = currentDay.subtract(Duration(days: currentDay.weekday - 1));
    final end = start.add(const Duration(days: 7));
    final value = DateTime(date.year, date.month, date.day);
    return !value.isBefore(start) && value.isBefore(end);
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
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
