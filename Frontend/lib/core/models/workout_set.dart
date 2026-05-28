/// Tek bir setin Flutter taraf veri modeli.
/// Backend WorkoutSetDto ile birebir eşleşir.
class WorkoutSet {
  final int? setNumber;

  /// WARMUP | NORMAL | DROP | FAILURE
  final String setType;
  final int? reps;
  final double? weight;
  final double? rpe;

  const WorkoutSet({
    this.setNumber,
    this.setType = 'NORMAL',
    this.reps,
    this.weight,
    this.rpe,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
    setNumber: json['setNumber'] != null
        ? (json['setNumber'] as num).toInt()
        : null,
    setType: json['setType']?.toString() ?? 'NORMAL',
    reps: json['reps'] != null ? (json['reps'] as num).toInt() : null,
    weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    rpe: json['rpe'] != null ? (json['rpe'] as num).toDouble() : null,
  );

  Map<String, dynamic> toJson() => {
    'setNumber': setNumber,
    'setType': setType,
    'reps': reps,
    'weight': weight,
    'rpe': rpe,
  };
}
