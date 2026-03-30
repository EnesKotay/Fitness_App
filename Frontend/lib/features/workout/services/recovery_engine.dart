import '../../../core/models/workout.dart';

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

      // Bu kas grubunu hedefleyen en son antrenmanı bul
      final lastWorkout = workouts
          .where((w) =>
              (w.muscleGroup ?? '').trim().toUpperCase() == group ||
              (w.workoutType ?? '').trim().toUpperCase() == group)
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
