import 'package:json_annotation/json_annotation.dart';

part 'food_item.g.dart';

@JsonSerializable(explicitToJson: true)
class FoodItem {
  final String id;
  final String name;
  final String category;
  
  // v2 Fields
  final FoodBasis basis;
  @JsonKey(name: 'nutrientsPerBasis')
  final Nutrients nutrients;
  final List<ServingUnit> servings;
  final List<String> aliases;
  /// Geniş eşleşme: protein, kahvaltı, ev yemeği, fastfood, tavuk, pilav vb.
  final List<String> tags;
  final String? brand;
  
  // Computed getters for backward compatibility (assuming basis is 100g)
  // If basis is not 100g, we should normalize, but for MVP we assume 100g basis for now
  // or calculate on the fly.
  double get kcalPer100g => _normalize(nutrients.kcal);
  double get proteinPer100g => _normalize(nutrients.protein);
  double get carbPer100g => _normalize(nutrients.carb);
  double get fatPer100g => _normalize(nutrients.fat);

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.basis,
    required this.nutrients,
    this.servings = const [],
    this.aliases = const [],
    this.tags = const [],
    this.brand,
  });

  double _normalize(double val) {
    if (basis.unit == 'g' && basis.amount == 100) return val;
    if (basis.unit == 'ml' && basis.amount == 100) return val;
    // Simple normalization for now
    if (basis.amount > 0) {
      return (val / basis.amount) * 100;
    }
    return val;
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    // Backward compatibility for v1 JSON
    if (json['nutrientsPerBasis'] == null) {
      return _fromV1(json);
    }
    return _$FoodItemFromJson(json);
  }

  Map<String, dynamic> toJson() => _$FoodItemToJson(this);

  static FoodItem _fromV1(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String? ?? 'Diğer',
      basis: const FoodBasis(amount: 100, unit: 'g'),
      nutrients: Nutrients(
        kcal: (json['kcalPer100g'] as num?)?.toDouble() ?? 0,
        protein: (json['proteinPer100g'] as num?)?.toDouble() ?? 0,
        carb: (json['carbPer100g'] as num?)?.toDouble() ?? 0,
        fat: (json['fatPer100g'] as num?)?.toDouble() ?? 0,
      ),
      tags: const [],
    );
  }
}

@JsonSerializable()
class FoodBasis {
  final double amount;
  final String unit; // 'g', 'ml'

  const FoodBasis({required this.amount, required this.unit});

  factory FoodBasis.fromJson(Map<String, dynamic> json) => _$FoodBasisFromJson(json);
  Map<String, dynamic> toJson() => _$FoodBasisToJson(this);
}

@JsonSerializable()
class Nutrients {
  final double kcal;
  final double protein;
  final double carb;
  final double fat;

  const Nutrients({
    required this.kcal,
    required this.protein,
    required this.carb,
    required this.fat,
  });

  factory Nutrients.fromJson(Map<String, dynamic> json) => _$NutrientsFromJson(json);
  Map<String, dynamic> toJson() => _$NutrientsToJson(this);
}

@JsonSerializable()
class ServingUnit {
  final String id;
  final String label; // "1 Adet", "1 Porsiyon"
  final double grams;
  final bool isDefault;

  const ServingUnit({
    required this.id,
    required this.label,
    required this.grams,
    this.isDefault = false,
  });

  factory ServingUnit.fromJson(Map<String, dynamic> json) => _$ServingUnitFromJson(json);
  Map<String, dynamic> toJson() => _$ServingUnitToJson(this);
}
