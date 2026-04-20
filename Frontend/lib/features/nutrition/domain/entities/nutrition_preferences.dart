class NutritionPreferences {
  // excludePork is always true — pork is never in the food database
  bool get excludePork => true;
  final bool vegetarian;
  final bool vegan;
  final bool lactoseFree;
  final bool glutenFree;

  const NutritionPreferences({
    this.vegetarian = false,
    this.vegan = false,
    this.lactoseFree = false,
    this.glutenFree = false,
  });

  bool get hasAnyFilter => vegetarian || vegan || lactoseFree || glutenFree;

  NutritionPreferences copyWith({
    bool? vegetarian,
    bool? vegan,
    bool? lactoseFree,
    bool? glutenFree,
  }) {
    return NutritionPreferences(
      vegetarian: vegetarian ?? this.vegetarian,
      vegan: vegan ?? this.vegan,
      lactoseFree: lactoseFree ?? this.lactoseFree,
      glutenFree: glutenFree ?? this.glutenFree,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vegetarian': vegetarian,
      'vegan': vegan,
      'lactoseFree': lactoseFree,
      'glutenFree': glutenFree,
    };
  }

  factory NutritionPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NutritionPreferences();
    return NutritionPreferences(
      vegetarian: json['vegetarian'] == true,
      vegan: json['vegan'] == true,
      lactoseFree: json['lactoseFree'] == true,
      glutenFree: json['glutenFree'] == true,
    );
  }
}
