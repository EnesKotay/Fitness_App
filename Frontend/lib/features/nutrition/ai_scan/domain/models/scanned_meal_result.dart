import 'package:json_annotation/json_annotation.dart';

part 'scanned_meal_result.g.dart';

@JsonSerializable()
class ScannedMealResult {
  final String? mealName;
  final double estimatedKcal;
  final double protein;
  final double carb;
  final double fat;
  final double confidence;
  final List<String> detectedIngredients;
  final String? mealType;

  const ScannedMealResult({
    this.mealName,
    this.estimatedKcal = 0.0,
    this.protein = 0.0,
    this.carb = 0.0,
    this.fat = 0.0,
    this.confidence = 0.0,
    this.detectedIngredients = const [],
    this.mealType,
  });

  factory ScannedMealResult.fromJson(Map<String, dynamic> json) =>
      _$ScannedMealResultFromJson(json);

  Map<String, dynamic> toJson() => _$ScannedMealResultToJson(this);
}
