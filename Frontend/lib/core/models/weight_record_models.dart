// Weight Record Request
class WeightRecordRequest {
  final double? weight;
  final double? bodyFatPercentage;
  final double? muscleMass;
  final DateTime? recordedAt;
  final String? notes;

  WeightRecordRequest({
    this.weight,
    this.bodyFatPercentage,
    this.muscleMass,
    this.recordedAt,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'weight': weight,
      'bodyFatPercentage': bodyFatPercentage,
      'muscleMass': muscleMass,
      'recordedAt': recordedAt?.toIso8601String(),
      'notes': notes,
    };
  }
}
