import 'package:uuid/uuid.dart';

class ProgramExercise {
  final String name;
  final String muscleGroup;
  final int sets;
  final int reps;

  const ProgramExercise({
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'muscleGroup': muscleGroup,
        'sets': sets,
        'reps': reps,
      };

  factory ProgramExercise.fromJson(Map<String, dynamic> json) => ProgramExercise(
        name: json['name'] as String,
        muscleGroup: json['muscleGroup'] as String,
        sets: json['sets'] as int,
        reps: json['reps'] as int,
      );
}

class ProgramDay {
  final String id;
  final String name;
  final List<ProgramExercise> exercises;

  ProgramDay({String? id, required this.name, required this.exercises})
      : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory ProgramDay.fromJson(Map<String, dynamic> json) => ProgramDay(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: (json['exercises'] as List<dynamic>)
            .map((e) => ProgramExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class WorkoutProgram {
  final String id;
  final String name;
  final String description;
  final List<ProgramDay> days;
  final DateTime createdAt;

  WorkoutProgram({
    String? id,
    required this.name,
    required this.description,
    required this.days,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'days': days.map((d) => d.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WorkoutProgram.fromJson(Map<String, dynamic> json) => WorkoutProgram(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        days: (json['days'] as List<dynamic>)
            .map((d) => ProgramDay.fromJson(d as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
