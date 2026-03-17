import 'workout_set.dart';

class Workout {
  final int id;
  final String name;
  final String? workoutType;
  final int? durationMinutes;
  final int? caloriesBurned;
  final int? sets;
  final int? reps;
  final double? weight;
  final DateTime workoutDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ─── Yeni alanlar ─────────────────────────────────────────────────────────
  final List<WorkoutSet>? setDetails;
  final String? muscleGroup;
  final bool? isSuperset;
  final String? supersetPartner;
  final double? oneRepMax;
  final String? difficulty;

  Workout({
    required this.id,
    required this.name,
    this.workoutType,
    this.durationMinutes,
    this.caloriesBurned,
    this.sets,
    this.reps,
    this.weight,
    required this.workoutDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.setDetails,
    this.muscleGroup,
    this.isSuperset,
    this.supersetPartner,
    this.oneRepMax,
    this.difficulty,
  });

  factory Workout.fromJson(Map<String, dynamic>? json) {
    if (json == null) throw ArgumentError('Workout.fromJson: json null');

    final id = json['id'];
    final name = json['name']?.toString();
    final workoutDateRaw = json['workoutDate']?.toString();

    List<WorkoutSet>? setDetails;
    if (json['setDetails'] is List) {
      setDetails = (json['setDetails'] as List)
          .map((e) => WorkoutSet.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return Workout(
      id: id is num ? id.toInt() : int.tryParse(id?.toString() ?? '0') ?? 0,
      name: name != null && name.isNotEmpty ? name : 'Antrenman',
      workoutType:     json['workoutType']?.toString(),
      durationMinutes: json['durationMinutes'] != null ? (json['durationMinutes'] as num).toInt() : null,
      caloriesBurned:  json['caloriesBurned']  != null ? (json['caloriesBurned']  as num).toInt() : null,
      sets:            json['sets']   != null ? (json['sets']   as num).toInt()    : null,
      reps:            json['reps']   != null ? (json['reps']   as num).toInt()    : null,
      weight:          json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      workoutDate: _parseDate(workoutDateRaw) ?? DateTime.now(),
      notes:       json['notes']?.toString(),
      createdAt:   _parseDate(json['createdAt']?.toString()),
      updatedAt:   _parseDate(json['updatedAt']?.toString()),
      setDetails:     setDetails,
      muscleGroup:    json['muscleGroup']?.toString(),
      isSuperset:     json['isSuperset'] as bool?,
      supersetPartner: json['supersetPartner']?.toString(),
      oneRepMax:  json['oneRepMax'] != null ? (json['oneRepMax'] as num).toDouble() : null,
      difficulty: json['difficulty']?.toString(),
    );
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try { return DateTime.parse(s); } catch (_) { return null; }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'workoutType': workoutType,
    'durationMinutes': durationMinutes,
    'caloriesBurned': caloriesBurned,
    'sets': sets,
    'reps': reps,
    'weight': weight,
    'workoutDate': workoutDate.toIso8601String(),
    'notes': notes,
    'createdAt': createdAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
    'muscleGroup': muscleGroup,
    'isSuperset': isSuperset,
    'supersetPartner': supersetPartner,
    'oneRepMax': oneRepMax,
    'difficulty': difficulty,
  };
}
