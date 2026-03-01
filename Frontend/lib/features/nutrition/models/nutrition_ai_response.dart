/// Nutrition AI response model - maps to backend NutritionAiResponse
class NutritionAiResponseModel {
  final String? reply;
  final List<SuggestedMealModel> meals;
  final List<String> shoppingList;
  final List<String> followUpQuestions;

  NutritionAiResponseModel({
    this.reply,
    List<SuggestedMealModel>? meals,
    List<String>? shoppingList,
    List<String>? followUpQuestions,
  }) : meals = meals ?? [],
       shoppingList = shoppingList ?? [],
       followUpQuestions = followUpQuestions ?? [];

  factory NutritionAiResponseModel.fromJson(Map<String, dynamic> json) {
    return NutritionAiResponseModel(
      reply: json['reply'] as String?,
      meals: _parseMeals(json['meals']),
      shoppingList: _parseStringList(json['shoppingList']),
      followUpQuestions: _parseStringList(json['followUpQuestions']),
    );
  }

  static List<SuggestedMealModel> _parseMeals(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map<String, dynamic>>()
        .map((item) => SuggestedMealModel.fromJson(item))
        .toList();
  }

  static List<String> _parseStringList(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  bool get hasMeals => meals.isNotEmpty;
  bool get hasFollowUpQuestions => followUpQuestions.isNotEmpty;
  bool get hasShoppingList => shoppingList.isNotEmpty;
}

/// Suggested meal model - maps to backend SuggestedMeal
class SuggestedMealModel {
  final String name;
  final String reason;
  final List<String> ingredients;
  final List<String> steps;
  final MealMacrosModel? macros;
  final int? prepMinutes;
  final List<String> tags;
  final List<String> warnings;

  SuggestedMealModel({
    required this.name,
    required this.reason,
    List<String>? ingredients,
    List<String>? steps,
    this.macros,
    this.prepMinutes,
    List<String>? tags,
    List<String>? warnings,
  }) : ingredients = ingredients ?? [],
       steps = steps ?? [],
       tags = tags ?? [],
       warnings = warnings ?? [];

  factory SuggestedMealModel.fromJson(Map<String, dynamic> json) {
    return SuggestedMealModel(
      name: (json['name'] as String?)?.trim() ?? '',
      reason: (json['reason'] as String?)?.trim() ?? '',
      ingredients: _parseStringList(json['ingredients']),
      steps: _parseStringList(json['steps']),
      macros: json['macros'] != null
          ? MealMacrosModel.fromJson(json['macros'] as Map<String, dynamic>)
          : null,
      prepMinutes: _parseInt(json['prepMinutes']),
      tags: _parseStringList(json['tags']),
      warnings: _parseStringList(json['warnings']),
    );
  }

  static List<String> _parseStringList(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  int get kcal => macros?.kcal ?? 0;
  int get proteinG => macros?.proteinG ?? 0;
  int get carbsG => macros?.carbsG ?? 0;
  int get fatG => macros?.fatG ?? 0;
}

/// Meal macros model - maps to backend MealMacros
class MealMacrosModel {
  final int? kcal;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;

  MealMacrosModel({this.kcal, this.proteinG, this.carbsG, this.fatG});

  factory MealMacrosModel.fromJson(Map<String, dynamic> json) {
    return MealMacrosModel(
      kcal: _parseInt(json['kcal']),
      proteinG: _parseInt(json['proteinG']),
      carbsG: _parseInt(json['carbsG']),
      fatG: _parseInt(json['fatG']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
