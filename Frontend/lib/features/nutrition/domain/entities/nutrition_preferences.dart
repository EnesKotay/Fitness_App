class NutritionPreferences {
  final bool excludePork;
  final bool halalFriendly;
  final bool vegetarian;
  final bool vegan;
  final bool lactoseFree;
  final bool glutenFree;

  const NutritionPreferences({
    this.excludePork = true,
    this.halalFriendly = false,
    this.vegetarian = false,
    this.vegan = false,
    this.lactoseFree = false,
    this.glutenFree = false,
  });

  bool get hasAnyFilter =>
      excludePork ||
      halalFriendly ||
      vegetarian ||
      vegan ||
      lactoseFree ||
      glutenFree;

  NutritionPreferences copyWith({
    bool? excludePork,
    bool? halalFriendly,
    bool? vegetarian,
    bool? vegan,
    bool? lactoseFree,
    bool? glutenFree,
  }) {
    return NutritionPreferences(
      excludePork: excludePork ?? this.excludePork,
      halalFriendly: halalFriendly ?? this.halalFriendly,
      vegetarian: vegetarian ?? this.vegetarian,
      vegan: vegan ?? this.vegan,
      lactoseFree: lactoseFree ?? this.lactoseFree,
      glutenFree: glutenFree ?? this.glutenFree,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'excludePork': excludePork,
      'halalFriendly': halalFriendly,
      'vegetarian': vegetarian,
      'vegan': vegan,
      'lactoseFree': lactoseFree,
      'glutenFree': glutenFree,
    };
  }

  factory NutritionPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NutritionPreferences();
    return NutritionPreferences(
      excludePork: json['excludePork'] == true,
      halalFriendly: json['halalFriendly'] == true,
      vegetarian: json['vegetarian'] == true,
      vegan: json['vegan'] == true,
      lactoseFree: json['lactoseFree'] == true,
      glutenFree: json['glutenFree'] == true,
    );
  }
}
