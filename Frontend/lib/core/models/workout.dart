class Workout {
  final int id;
  final String name;
  final String? workoutType;
  final int? durationMinutes;
  final int? caloriesBurned;
  final DateTime workoutDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Workout({
    required this.id,
    required this.name,
    this.workoutType,
    this.durationMinutes,
    this.caloriesBurned,
    required this.workoutDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Workout.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw ArgumentError('Workout.fromJson: json null');
    }
    final id = json['id'];
    final name = json['name']?.toString();
    final workoutDateRaw = json['workoutDate']?.toString();
    return Workout(
      id: id is num ? id.toInt() : int.tryParse(id?.toString() ?? '0') ?? 0,
      name: name != null && name.isNotEmpty ? name : 'Antrenman',
      workoutType: json['workoutType']?.toString(),
      durationMinutes: json['durationMinutes'] != null ? (json['durationMinutes'] as num).toInt() : null,
      caloriesBurned: json['caloriesBurned'] != null ? (json['caloriesBurned'] as num).toInt() : null,
      workoutDate: _parseDate(workoutDateRaw) ?? DateTime.now(),
      notes: json['notes']?.toString(),
      createdAt: _parseDate(json['createdAt']?.toString()),
      updatedAt: _parseDate(json['updatedAt']?.toString()),
    );
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'workoutType': workoutType,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'workoutDate': workoutDate.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
