class WeightRecord {
  final int id;
  final double weight;
  final double? bodyFatPercentage;
  final double? muscleMass;
  final DateTime recordedAt;
  final String? notes;
  final DateTime? createdAt;

  WeightRecord({
    required this.id,
    required this.weight,
    this.bodyFatPercentage,
    this.muscleMass,
    required this.recordedAt,
    this.notes,
    this.createdAt,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: (json['id'] as num).toInt(),
      weight: (json['weight'] as num).toDouble(),
      bodyFatPercentage: json['bodyFatPercentage'] != null
          ? (json['bodyFatPercentage'] as num).toDouble()
          : null,
      muscleMass: json['muscleMass'] != null
          ? (json['muscleMass'] as num).toDouble()
          : null,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'weight': weight,
      'bodyFatPercentage': bodyFatPercentage,
      'muscleMass': muscleMass,
      'recordedAt': recordedAt.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}