class Meal {
  final int id;
  final String name;
  final String mealType;
  final int calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final DateTime mealDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Meal({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    this.protein,
    this.carbs,
    this.fat,
    required this.mealDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      mealType: json['mealType'] as String,
      calories: (json['calories'] as num).toInt(),
      protein: json['protein'] != null
          ? (json['protein'] as num).toDouble()
          : null,
      carbs: json['carbs'] != null ? (json['carbs'] as num).toDouble() : null,
      fat: json['fat'] != null ? (json['fat'] as num).toDouble() : null,
      mealDate: DateTime.parse(json['mealDate'] as String),
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mealType': mealType,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'mealDate': mealDate.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
