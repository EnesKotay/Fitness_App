import 'meal_type.dart';

/// Günlüğe eklenen tek bir yemek kaydı (tarih + öğün + yiyecek + gram + hesaplanan kcal + opsiyonel makro).
class FoodEntry {
  final String id;
  final String date; // yyyy-MM-dd
  final MealType mealType;
  final String foodId;
  final String foodName; // snapshot, arama kolaylığı için
  final double grams;
  final double calculatedKcal;
  final double protein; // bu porsiyon için
  final double carb;
  final double fat;
  final DateTime createdAt;

  const FoodEntry({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodId,
    required this.foodName,
    required this.grams,
    required this.calculatedKcal,
    this.protein = 0,
    this.carb = 0,
    this.fat = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'mealType': mealType.name,
        'foodId': foodId,
        'foodName': foodName,
        'grams': grams,
        'calculatedKcal': calculatedKcal,
        'protein': protein,
        'carb': carb,
        'fat': fat,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    try {
      final id = json['id']?.toString() ?? '';
      final date = json['date']?.toString() ?? '';
      final mealTypeStr = json['mealType']?.toString() ?? '';
      final foodId = json['foodId']?.toString() ?? '';
      final foodName = json['foodName']?.toString() ?? '';
      final createdAtStr = json['createdAt']?.toString() ?? '';
      
      if (id.isEmpty || date.isEmpty || foodId.isEmpty || foodName.isEmpty || createdAtStr.isEmpty) {
        throw FormatException('FoodEntry: Gerekli alanlar boş olamaz');
      }
      
      MealType mealType;
      try {
        mealType = MealType.values.byName(mealTypeStr);
      } catch (_) {
        mealType = MealType.snack; // Varsayılan
      }
      
      double safeDouble(num? value, double defaultValue) {
        if (value == null) return defaultValue;
        final d = value.toDouble();
        return d.isNaN || d.isInfinite ? defaultValue : d;
      }
      
      DateTime createdAt;
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {
        createdAt = DateTime.now(); // Varsayılan
      }
      
      return FoodEntry(
        id: id,
        date: date,
        mealType: mealType,
        foodId: foodId,
        foodName: foodName,
        grams: safeDouble(json['grams'] as num?, 0),
        calculatedKcal: safeDouble(json['calculatedKcal'] as num?, 0),
        protein: safeDouble(json['protein'] as num?, 0),
        carb: safeDouble(json['carb'] as num?, 0),
        fat: safeDouble(json['fat'] as num?, 0),
        createdAt: createdAt,
      );
    } catch (e) {
      throw FormatException('FoodEntry.fromJson hatası: $e, json: $json');
    }
  }
}
