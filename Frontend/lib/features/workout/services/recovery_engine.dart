import '../../../core/models/workout.dart';
import '../../../core/utils/muscle_group_utils.dart';


/// Kas grubu bazlı dinlenme ve yorgunluk skoru hesaplar.
class RecoveryEngine {
  static const Map<String, int> _recoveryHoursMap = {
    'LEGS': 72,
    'BACK': 60,
    'CHEST': 60,
    'SHOULDERS': 48,
    'BICEPS': 36,
    'TRICEPS': 36,
    'CORE': 24,
    'GLUTES': 60,
  };

  /// Tüm kas grupları için [FatigueStatus] döndürür.
  static Map<String, FatigueStatus> computeAll(List<Workout> workouts) {
    final now = DateTime.now();
    final result = <String, FatigueStatus>{};

    for (final entry in _recoveryHoursMap.entries) {
      final group = entry.key;
      final requiredHours = entry.value;

      // Bu kas grubunu hedefleyen en son antrenmanı bul (normalize edilmiş eşleşme)
      final lastWorkout = workouts
          .where((w) =>
              normalizeMuscleGroupCode(w.muscleGroup) == group ||
              normalizeMuscleGroupCode(w.workoutType) == group)
          .toList()
        ..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));

      if (lastWorkout.isEmpty) {
        result[group] = FatigueStatus(
          muscleGroup: group,
          level: FatigueLevel.fresh,
          hoursElapsed: 999,
          requiredHours: requiredHours,
          lastWorkoutDate: null,
        );
        continue;
      }

      final last = lastWorkout.first.workoutDate;
      final elapsed = now.difference(last).inHours;
      final ratio = elapsed / requiredHours;

      FatigueLevel level;
      if (ratio >= 1.0) {
        level = FatigueLevel.fresh;
      } else if (ratio >= 0.6) {
        level = FatigueLevel.recovering;
      } else {
        level = FatigueLevel.fatigued;
      }

      result[group] = FatigueStatus(
        muscleGroup: group,
        level: level,
        hoursElapsed: elapsed,
        requiredHours: requiredHours,
        lastWorkoutDate: last,
      );
    }

    return result;
  }

  /// Belirli bir kas grubu için fatigue durumu döndürür.
  static FatigueStatus compute(String muscleGroup, List<Workout> workouts) {
    final all = computeAll(workouts);
    return all[muscleGroup.trim().toUpperCase()] ??
        FatigueStatus(
          muscleGroup: muscleGroup,
          level: FatigueLevel.fresh,
          hoursElapsed: 999,
          requiredHours: 48,
          lastWorkoutDate: null,
        );
  }

  /// Bugünkü antrenman için en uygun kas gruplarını önerir.
  static List<String> recommendedGroupsToday(List<Workout> workouts) {
    final all = computeAll(workouts);
    return all.entries
        .where((e) => e.value.level == FatigueLevel.fresh)
        .map((e) => e.key)
        .toList();
  }

  /// Kullanıcının Deload (Toparlanma) yapıp yapmaması gerektiğini kontrol eder
  static bool isDeloadRecommended(List<Workout> workouts) {
    if (workouts.isEmpty) return false;

    // 1. Kriter: Kasların çoğunluğu "Fatigued" durumunda mı?
    final allFatigue = computeAll(workouts);
    final fatiguedCount = allFatigue.values.where((s) => s.level == FatigueLevel.fatigued).length;
    
    // 2. Kriter: Son 3 antrenmanın ortalama RPE'si 9 ve üzeri mi?
    final recentWorkouts = workouts.toList()..sort((a, b) => b.workoutDate.compareTo(a.workoutDate));
    final last3 = recentWorkouts.take(3).toList();
    
    double avgRecentRpe = 0;
    int rpeCount = 0;
    for (final w in last3) {
      if (w.setDetails != null) {
        for (final s in w.setDetails!) {
          if (s.rpe != null && s.rpe! > 0) {
            avgRecentRpe += s.rpe!;
            rpeCount++;
          }
        }
      }
    }
    
    if (rpeCount > 0) {
      avgRecentRpe /= rpeCount;
    }

    // 3. Kriter: Son 7 günde 6 veya daha fazla gün antrenman yapılmış mı?
    final recentDays = <DateTime>{};
    final now = DateTime.now();
    for (final w in workouts) {
      final d = DateTime(w.workoutDate.year, w.workoutDate.month, w.workoutDate.day);
      if (now.difference(d).inDays <= 6) recentDays.add(d);
    }

    return fatiguedCount >= 4 || avgRecentRpe >= 9.0 || recentDays.length >= 6;
  }
}

class FatigueStatus {
  final String muscleGroup;
  final FatigueLevel level;
  final int hoursElapsed;
  final int requiredHours;
  final DateTime? lastWorkoutDate;

  const FatigueStatus({
    required this.muscleGroup,
    required this.level,
    required this.hoursElapsed,
    required this.requiredHours,
    required this.lastWorkoutDate,
  });

  /// 0.0 (tam yorgun) – 1.0 (tam dinlenmiş)
  double get recoveryPercent =>
      (hoursElapsed / requiredHours).clamp(0.0, 1.0);

  int get remainingHours => (requiredHours - hoursElapsed).clamp(0, 999);

  String get levelLabel => switch (level) {
        FatigueLevel.fresh => 'Hazır ✅',
        FatigueLevel.recovering => 'İyileşiyor 🟡',
        FatigueLevel.fatigued => 'Yorgun 🔴',
      };
}

enum FatigueLevel { fresh, recovering, fatigued }
