/// Result from backend nutrition label scanning via Gemini Vision.
class ScannedNutritionResult {
  final String? productName;
  final double kcal;
  final double protein;
  final double carb;
  final double fat;
  final double? fiber;
  final double? sugar;
  final double? servingSize;
  final String? servingUnit;
  final double confidence;

  const ScannedNutritionResult({
    this.productName,
    this.kcal = 0,
    this.protein = 0,
    this.carb = 0,
    this.fat = 0,
    this.fiber,
    this.sugar,
    this.servingSize,
    this.servingUnit,
    this.confidence = 0,
  });

  factory ScannedNutritionResult.fromJson(Map<String, dynamic> json) {
    return ScannedNutritionResult(
      productName: json['productName'] as String?,
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carb: (json['carb'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble(),
      sugar: (json['sugar'] as num?)?.toDouble(),
      servingSize: (json['servingSize'] as num?)?.toDouble(),
      servingUnit: json['servingUnit'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  bool get isEmpty => kcal == 0 && protein == 0 && carb == 0 && fat == 0;
}
