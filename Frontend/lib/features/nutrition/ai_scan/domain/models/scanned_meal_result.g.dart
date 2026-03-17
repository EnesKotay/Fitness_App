// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scanned_meal_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ScannedMealResult _$ScannedMealResultFromJson(Map<String, dynamic> json) =>
    ScannedMealResult(
      mealName: json['mealName'] as String?,
      estimatedKcal: (json['estimatedKcal'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carb: (json['carb'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      detectedIngredients: (json['detectedIngredients'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      mealType: json['mealType'] as String?,
    );

Map<String, dynamic> _$ScannedMealResultToJson(ScannedMealResult instance) =>
    <String, dynamic>{
      'mealName': instance.mealName,
      'estimatedKcal': instance.estimatedKcal,
      'protein': instance.protein,
      'carb': instance.carb,
      'fat': instance.fat,
      'confidence': instance.confidence,
      'detectedIngredients': instance.detectedIngredients,
      'mealType': instance.mealType,
    };
