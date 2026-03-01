// Workout Request
class WorkoutRequest {
  final String? name;
  final String? workoutType;
  final int? durationMinutes;
  final int? caloriesBurned;
  final DateTime? workoutDate;
  final String? notes;

  WorkoutRequest({
    this.name,
    this.workoutType,
    this.durationMinutes,
    this.caloriesBurned,
    this.workoutDate,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'workoutType': workoutType,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'workoutDate': workoutDate?.toIso8601String(),
      'notes': notes,
    };
  }
}
