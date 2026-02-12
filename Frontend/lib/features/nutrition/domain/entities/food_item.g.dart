// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FoodItem _$FoodItemFromJson(Map<String, dynamic> json) => FoodItem(
  id: json['id'] as String,
  name: json['name'] as String,
  category: json['category'] as String,
  basis: FoodBasis.fromJson(json['basis'] as Map<String, dynamic>),
  nutrients: Nutrients.fromJson(
    json['nutrientsPerBasis'] as Map<String, dynamic>,
  ),
  servings:
      (json['servings'] as List<dynamic>?)
          ?.map((e) => ServingUnit.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  aliases:
      (json['aliases'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  tags:
      (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  brand: json['brand'] as String?,
);

Map<String, dynamic> _$FoodItemToJson(FoodItem instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'category': instance.category,
  'basis': instance.basis.toJson(),
  'nutrientsPerBasis': instance.nutrients.toJson(),
  'servings': instance.servings.map((e) => e.toJson()).toList(),
  'aliases': instance.aliases,
  'tags': instance.tags,
  'brand': instance.brand,
};

FoodBasis _$FoodBasisFromJson(Map<String, dynamic> json) => FoodBasis(
  amount: (json['amount'] as num).toDouble(),
  unit: json['unit'] as String,
);

Map<String, dynamic> _$FoodBasisToJson(FoodBasis instance) => <String, dynamic>{
  'amount': instance.amount,
  'unit': instance.unit,
};

Nutrients _$NutrientsFromJson(Map<String, dynamic> json) => Nutrients(
  kcal: (json['kcal'] as num).toDouble(),
  protein: (json['protein'] as num).toDouble(),
  carb: (json['carb'] as num).toDouble(),
  fat: (json['fat'] as num).toDouble(),
);

Map<String, dynamic> _$NutrientsToJson(Nutrients instance) => <String, dynamic>{
  'kcal': instance.kcal,
  'protein': instance.protein,
  'carb': instance.carb,
  'fat': instance.fat,
};

ServingUnit _$ServingUnitFromJson(Map<String, dynamic> json) => ServingUnit(
  id: json['id'] as String,
  label: json['label'] as String,
  grams: (json['grams'] as num).toDouble(),
  isDefault: json['isDefault'] as bool? ?? false,
);

Map<String, dynamic> _$ServingUnitToJson(ServingUnit instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'grams': instance.grams,
      'isDefault': instance.isDefault,
    };
