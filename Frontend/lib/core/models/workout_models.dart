import 'workout_set.dart';

// Workout Request
class WorkoutRequest {
  final String? name;
  final String? workoutType;
  final int? durationMinutes;
  final int? caloriesBurned;
  final int? sets;
  final int? reps;
  final double? weight;
  final DateTime? workoutDate;
  final String? notes;

  // ─── Yeni alanlar ─────────────────────────────────────────────────────────
  final List<WorkoutSet>? setDetails;
  final String? muscleGroup;
  final bool? isSuperset;
  final String? supersetPartner;
  final String? difficulty;
  final double? oneRepMax;

  WorkoutRequest({
    this.name,
    this.workoutType,
    this.durationMinutes,
    this.caloriesBurned,
    this.sets,
    this.reps,
    this.weight,
    this.workoutDate,
    this.notes,
    this.setDetails,
    this.muscleGroup,
    this.isSuperset,
    this.supersetPartner,
    this.difficulty,
    this.oneRepMax,
  });

  factory WorkoutRequest.fromJson(Map<String, dynamic> json) {
    List<WorkoutSet>? _setDetails;
    if (json['setDetails'] is List) {
      _setDetails = (json['setDetails'] as List)
          .map((e) => WorkoutSet.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return WorkoutRequest(
      name: json['name']?.toString(),
      workoutType: json['workoutType']?.toString(),
      durationMinutes: json['durationMinutes'] as int?,
      caloriesBurned: json['caloriesBurned'] as int?,
      sets: json['sets'] as int?,
      reps: json['reps'] as int?,
      weight: (json['weight'] as num?)?.toDouble(),
      workoutDate: json['workoutDate'] != null ? DateTime.parse(json['workoutDate']) : null,
      notes: json['notes']?.toString(),
      setDetails: _setDetails,
      muscleGroup: json['muscleGroup']?.toString(),
      isSuperset: json['isSuperset'] as bool?,
      supersetPartner: json['supersetPartner']?.toString(),
      difficulty: json['difficulty']?.toString(),
      oneRepMax: (json['oneRepMax'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'workoutType': workoutType,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'sets': sets,
      'reps': reps,
      'weight': weight,
      'workoutDate': workoutDate?.toIso8601String(),
      'notes': notes,
      if (setDetails != null && setDetails!.isNotEmpty)
        'setDetails': setDetails!.map((s) => s.toJson()).toList(),
      if (muscleGroup != null) 'muscleGroup': muscleGroup,
      if (isSuperset  != null) 'isSuperset':  isSuperset,
      if (supersetPartner != null) 'supersetPartner': supersetPartner,
      if (difficulty  != null) 'difficulty':  difficulty,
      if (oneRepMax   != null) 'oneRepMax':   oneRepMax,
    };
  }
}
