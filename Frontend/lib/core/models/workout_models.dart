import 'workout_set.dart';
import 'workout.dart';

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
    List<WorkoutSet>? setDetails;
    if (json['setDetails'] is List) {
      setDetails = (json['setDetails'] as List)
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
      workoutDate: json['workoutDate'] != null
          ? DateTime.parse(json['workoutDate'])
          : null,
      notes: json['notes']?.toString(),
      setDetails: setDetails,
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
      if (isSuperset != null) 'isSuperset': isSuperset,
      if (supersetPartner != null) 'supersetPartner': supersetPartner,
      if (difficulty != null) 'difficulty': difficulty,
      if (oneRepMax != null) 'oneRepMax': oneRepMax,
    };
  }
}

class WorkoutSessionExerciseRequest {
  final String name;
  final String? workoutType;
  final String? muscleGroup;
  final int plannedSets;
  final int completedSets;
  final int reps;
  final double? weight;
  final int restSeconds;
  final String? notes;
  final List<WorkoutSet> setDetails;

  WorkoutSessionExerciseRequest({
    required this.name,
    this.workoutType,
    this.muscleGroup,
    required this.plannedSets,
    required this.completedSets,
    required this.reps,
    this.weight,
    required this.restSeconds,
    this.notes,
    this.setDetails = const [],
  });

  factory WorkoutSessionExerciseRequest.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionExerciseRequest(
      name: json['name']?.toString() ?? 'Egzersiz',
      workoutType: json['workoutType']?.toString(),
      muscleGroup: json['muscleGroup']?.toString(),
      plannedSets: (json['plannedSets'] as num?)?.toInt() ?? 0,
      completedSets: (json['completedSets'] as num?)?.toInt() ?? 0,
      reps: (json['reps'] as num?)?.toInt() ?? 0,
      weight: (json['weight'] as num?)?.toDouble(),
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 90,
      notes: json['notes']?.toString(),
      setDetails:
          (json['setDetails'] as List<dynamic>?)
              ?.map((item) => WorkoutSet.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (workoutType != null) 'workoutType': workoutType,
    if (muscleGroup != null) 'muscleGroup': muscleGroup,
    'plannedSets': plannedSets,
    'completedSets': completedSets,
    'reps': reps,
    if (weight != null) 'weight': weight,
    'restSeconds': restSeconds,
    if (notes != null) 'notes': notes,
    if (setDetails.isNotEmpty)
      'setDetails': setDetails.map((set) => set.toJson()).toList(),
  };
}

class WorkoutSessionRequest {
  final String title;
  final DateTime? startedAt;
  final DateTime finishedAt;
  final int? durationMinutes;
  final int plannedSetCount;
  final int completedSetCount;
  final String? difficulty;
  final String? notes;
  final List<WorkoutSessionExerciseRequest> exercises;

  WorkoutSessionRequest({
    required this.title,
    this.startedAt,
    required this.finishedAt,
    this.durationMinutes,
    required this.plannedSetCount,
    required this.completedSetCount,
    this.difficulty,
    this.notes,
    required this.exercises,
  });

  factory WorkoutSessionRequest.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionRequest(
      title: json['title']?.toString() ?? 'Antrenman',
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      finishedAt:
          DateTime.tryParse(json['finishedAt']?.toString() ?? '') ??
          DateTime.now(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      plannedSetCount: (json['plannedSetCount'] as num?)?.toInt() ?? 0,
      completedSetCount: (json['completedSetCount'] as num?)?.toInt() ?? 0,
      difficulty: json['difficulty']?.toString(),
      notes: json['notes']?.toString(),
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .map(
            (item) => WorkoutSessionExerciseRequest.fromJson(
              item as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    'finishedAt': finishedAt.toIso8601String(),
    if (durationMinutes != null) 'durationMinutes': durationMinutes,
    'plannedSetCount': plannedSetCount,
    'completedSetCount': completedSetCount,
    if (difficulty != null) 'difficulty': difficulty,
    if (notes != null) 'notes': notes,
    'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
  };
}

class WorkoutSessionResponse {
  final int id;
  final String title;
  final DateTime? startedAt;
  final DateTime finishedAt;
  final int? durationMinutes;
  final int? plannedSetCount;
  final int? completedSetCount;
  final String? difficulty;
  final String? notes;
  final List<Workout> workouts;

  WorkoutSessionResponse({
    required this.id,
    required this.title,
    this.startedAt,
    required this.finishedAt,
    this.durationMinutes,
    this.plannedSetCount,
    this.completedSetCount,
    this.difficulty,
    this.notes,
    this.workouts = const [],
  });

  factory WorkoutSessionResponse.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionResponse(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? 'Antrenman',
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString())
          : null,
      finishedAt:
          DateTime.tryParse(json['finishedAt']?.toString() ?? '') ??
          DateTime.now(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      plannedSetCount: (json['plannedSetCount'] as num?)?.toInt(),
      completedSetCount: (json['completedSetCount'] as num?)?.toInt(),
      difficulty: json['difficulty']?.toString(),
      notes: json['notes']?.toString(),
      workouts:
          (json['workouts'] as List<dynamic>?)
              ?.map((item) => Workout.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
