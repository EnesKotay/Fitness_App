class User {
  final int id;
  final String email;
  final String name;
  final DateTime? createdAt;
  final double? height;
  final double? weight;
  final double? targetWeight;
  final DateTime? birthDate;
  final String? gender;
  final String? activityLevel;
  final String? goal;
  final String? goalHistoryJson;
  final String? workoutLocation;
  final String? equipmentType;
  final String? nutritionPreferencesJson;
  final String? aiMemorySummary;
  final String? motivationStatsJson;
  final String? premiumTier;
  final DateTime? premiumExpiresAt;
  final String? premiumPlan;
  final bool? premiumCancelAtPeriodEnd;
  final DateTime? premiumCanceledAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.createdAt,
    this.height,
    this.weight,
    this.targetWeight,
    this.birthDate,
    this.gender,
    this.activityLevel,
    this.goal,
    this.goalHistoryJson,
    this.workoutLocation,
    this.equipmentType,
    this.nutritionPreferencesJson,
    this.aiMemorySummary,
    this.motivationStatsJson,
    this.premiumTier,
    this.premiumExpiresAt,
    this.premiumPlan,
    this.premiumCancelAtPeriodEnd,
    this.premiumCanceledAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final email = json['email']?.toString();
    final name = json['name']?.toString();
    if (id == null ||
        email == null ||
        email.isEmpty ||
        name == null ||
        name.isEmpty) {
      throw FormatException(
        'Geçersiz kullanıcı verisi: id=$id, email=$email, name=$name',
      );
    }
    return User(
      id: (id is num) ? id.toInt() : int.tryParse(id.toString()) ?? 0,
      email: email,
      name: name,
      createdAt: _parseDateTime(json['createdAt']),
      height: json['height'] != null
          ? (json['height'] is num
                ? (json['height'] as num).toDouble()
                : double.tryParse(json['height'].toString()))
          : null,
      weight: json['weight'] != null
          ? (json['weight'] is num
                ? (json['weight'] as num).toDouble()
                : double.tryParse(json['weight'].toString()))
          : null,
      targetWeight: json['targetWeight'] != null
          ? (json['targetWeight'] is num
                ? (json['targetWeight'] as num).toDouble()
                : double.tryParse(json['targetWeight'].toString()))
          : null,
      birthDate: _parseDateTime(json['birthDate']),
      gender: json['gender']?.toString(),
      activityLevel: json['activityLevel']?.toString(),
      goal: json['goal']?.toString(),
      goalHistoryJson: json['goalHistoryJson']?.toString(),
      workoutLocation: json['workoutLocation']?.toString(),
      equipmentType: json['equipmentType']?.toString(),
      nutritionPreferencesJson: json['nutritionPreferencesJson']?.toString(),
      aiMemorySummary: json['aiMemorySummary']?.toString(),
      motivationStatsJson: json['motivationStatsJson']?.toString(),
      premiumTier: json['premiumTier']?.toString(),
      premiumExpiresAt: _parseDateTime(json['premiumExpiresAt']),
      premiumPlan: json['premiumPlan']?.toString(),
      premiumCancelAtPeriodEnd: json['premiumCancelAtPeriodEnd'] == true,
      premiumCanceledAt: _parseDateTime(json['premiumCanceledAt']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    // Jackson bazen LocalDateTime'ı [y,m,d,h,min,s] array olarak serialize eder
    if (value is List && value.length >= 3) {
      try {
        final y = (value[0] as num).toInt();
        final m = (value.length > 1 ? (value[1] as num).toInt() : 1).clamp(
          1,
          12,
        );
        final d = (value.length > 2 ? (value[2] as num).toInt() : 1).clamp(
          1,
          31,
        );
        final h = value.length > 3 ? (value[3] as num).toInt() : 0;
        final min = value.length > 4 ? (value[4] as num).toInt() : 0;
        final sec = value.length > 5 ? (value[5] as num).toInt() : 0;
        return DateTime(y, m, d, h, min, sec);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'createdAt': createdAt?.toIso8601String(),
      'height': height,
      'weight': weight,
      'birthDate': birthDate?.toIso8601String(),
      'targetWeight': targetWeight,
      'gender': gender,
      'activityLevel': activityLevel,
      'goal': goal,
      'goalHistoryJson': goalHistoryJson,
      'workoutLocation': workoutLocation,
      'equipmentType': equipmentType,
      'nutritionPreferencesJson': nutritionPreferencesJson,
      'aiMemorySummary': aiMemorySummary,
      'motivationStatsJson': motivationStatsJson,
      'premiumTier': premiumTier,
      'premiumExpiresAt': premiumExpiresAt?.toIso8601String(),
      'premiumPlan': premiumPlan,
      'premiumCancelAtPeriodEnd': premiumCancelAtPeriodEnd,
      'premiumCanceledAt': premiumCanceledAt?.toIso8601String(),
    };
  }

  User copyWith({
    int? id,
    String? email,
    String? name,
    DateTime? createdAt,
    double? height,
    double? weight,
    double? targetWeight,
    DateTime? birthDate,
    String? gender,
    String? activityLevel,
    String? goal,
    String? goalHistoryJson,
    String? workoutLocation,
    String? equipmentType,
    String? nutritionPreferencesJson,
    String? aiMemorySummary,
    String? motivationStatsJson,
    String? premiumTier,
    DateTime? premiumExpiresAt,
    String? premiumPlan,
    bool? premiumCancelAtPeriodEnd,
    DateTime? premiumCanceledAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      targetWeight: targetWeight ?? this.targetWeight,
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      goal: goal ?? this.goal,
      goalHistoryJson: goalHistoryJson ?? this.goalHistoryJson,
      workoutLocation: workoutLocation ?? this.workoutLocation,
      equipmentType: equipmentType ?? this.equipmentType,
      nutritionPreferencesJson:
          nutritionPreferencesJson ?? this.nutritionPreferencesJson,
      aiMemorySummary: aiMemorySummary ?? this.aiMemorySummary,
      motivationStatsJson: motivationStatsJson ?? this.motivationStatsJson,
      premiumTier: premiumTier ?? this.premiumTier,
      premiumExpiresAt: premiumExpiresAt ?? this.premiumExpiresAt,
      premiumPlan: premiumPlan ?? this.premiumPlan,
      premiumCancelAtPeriodEnd:
          premiumCancelAtPeriodEnd ?? this.premiumCancelAtPeriodEnd,
      premiumCanceledAt: premiumCanceledAt ?? this.premiumCanceledAt,
    );
  }
}
