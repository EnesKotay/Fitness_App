import '../../../nutrition/domain/entities/grocery_item.dart';

enum RecipeDietaryFlag {
  vegan,
  vegetarian,
  glutenFree,
}

extension RecipeDietaryFlagLabel on RecipeDietaryFlag {
  String get label {
    switch (this) {
      case RecipeDietaryFlag.vegan:
        return 'vegan';
      case RecipeDietaryFlag.vegetarian:
        return 'vejetaryen';
      case RecipeDietaryFlag.glutenFree:
        return 'glutensiz';
    }
  }
}

enum RecipeGoalTag {
  highProtein,
  lowCarb,
  lowFat,
  fast,
  breakfast,
  mealPrep,
  omega3,
  antioxidant,
}

extension RecipeGoalTagLabel on RecipeGoalTag {
  String get label {
    switch (this) {
      case RecipeGoalTag.highProtein:
        return 'yuksek protein';
      case RecipeGoalTag.lowCarb:
        return 'dusuk karb';
      case RecipeGoalTag.lowFat:
        return 'dusuk yag';
      case RecipeGoalTag.fast:
        return 'hizli';
      case RecipeGoalTag.breakfast:
        return 'kahvaltilik';
      case RecipeGoalTag.mealPrep:
        return 'meal prep';
      case RecipeGoalTag.omega3:
        return 'omega 3';
      case RecipeGoalTag.antioxidant:
        return 'antioksidan';
    }
  }
}

String _normalizeRecipeText(String input) {
  return input
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('İ', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _categorySearchLabel(String category) {
  switch (category) {
    case 'bowl':
      return 'bowl kase';
    case 'ana_yemek':
      return 'ana yemek ogle aksam';
    case 'salata':
      return 'salata hafif';
    case 'smoothie':
      return 'smoothie icecek';
    case 'atistirmalik':
      return 'atistirmalik snack ara ogun';
    default:
      return category;
  }
}

class RecipeIngredient {
  final String name;
  final double amount;
  final String unit;
  final String? category;

  const RecipeIngredient({
    required this.name,
    required this.amount,
    required this.unit,
    this.category,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      unit: json['unit'] as String,
      category: json['category'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'unit': unit,
      if (category != null) 'category': category,
    };
  }

  String get displayAmount {
    final normalized = amount == amount.roundToDouble()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(1);
    return '$normalized $unit';
  }

  String get normalizedName => _normalizeRecipeText(name);

  RecipeIngredient scaled(double factor) {
    return RecipeIngredient(
      name: name,
      amount: amount * factor,
      unit: unit,
      category: category,
    );
  }
}

class Recipe {
  final String id;
  final String name;
  final String description;
  final String category;
  final int servings;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final String imageEmoji;
  final String? imageAsset;
  final double kcalPerServing;
  final double proteinPerServing;
  final double carbPerServing;
  final double fatPerServing;
  final double fiberPerServing;
  final double sugarPerServing;
  final List<String> tags;
  final String difficulty;

  Recipe({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.servings,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.ingredients,
    required this.steps,
    required this.imageEmoji,
    this.imageAsset,
    required this.kcalPerServing,
    required this.proteinPerServing,
    required this.carbPerServing,
    required this.fatPerServing,
    required this.fiberPerServing,
    required this.sugarPerServing,
    required this.tags,
    required this.difficulty,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      servings: (json['servings'] as num).toInt(),
      prepTimeMinutes: (json['prepTimeMinutes'] as num).toInt(),
      cookTimeMinutes: (json['cookTimeMinutes'] as num).toInt(),
      ingredients: (json['ingredients'] as List)
          .map((e) => RecipeIngredient.fromJson(e as Map<String, dynamic>))
          .toList(),
      steps: (json['steps'] as List).map((e) => e as String).toList(),
      imageEmoji: json['imageEmoji'] as String? ?? '🍽️',
      imageAsset: (json['imageAsset'] as String?)?.trim().isEmpty == true
          ? null
          : (json['imageAsset'] as String?),
      kcalPerServing: (json['kcalPerServing'] as num).toDouble(),
      proteinPerServing: (json['proteinPerServing'] as num).toDouble(),
      carbPerServing: (json['carbPerServing'] as num).toDouble(),
      fatPerServing: (json['fatPerServing'] as num).toDouble(),
      fiberPerServing: (json['fiberPerServing'] as num?)?.toDouble() ?? 0.0,
      sugarPerServing: (json['sugarPerServing'] as num?)?.toDouble() ?? 0.0,
      tags: (json['tags'] as List? ?? []).map((e) => e as String).toList(),
      difficulty: json['difficulty'] as String? ?? 'orta',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'servings': servings,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
      'steps': steps,
      'imageEmoji': imageEmoji,
      if (imageAsset != null) 'imageAsset': imageAsset,
      'kcalPerServing': kcalPerServing,
      'proteinPerServing': proteinPerServing,
      'carbPerServing': carbPerServing,
      'fatPerServing': fatPerServing,
      'fiberPerServing': fiberPerServing,
      'sugarPerServing': sugarPerServing,
      'tags': tags,
      'difficulty': difficulty,
    };
  }

  // Lazy cached computed fields — bir kez hesaplanır, sonra tekrar kullanılır
  late final Set<String> _normalizedTags =
      tags.map(_normalizeRecipeText).toSet();

  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  int get difficultyRank {
    switch (difficulty) {
      case 'kolay':
        return 0;
      case 'orta':
        return 1;
      case 'zor':
        return 2;
      default:
        return 1;
    }
  }

  late final Set<RecipeDietaryFlag> dietaryFlags = _computeDietaryFlags();
  late final Set<RecipeGoalTag> goalTags = _computeGoalTags();
  late final String searchableText = _computeSearchableText();

  Set<RecipeDietaryFlag> _computeDietaryFlags() {
    final flags = <RecipeDietaryFlag>{};
    if (_normalizedTags.any((tag) => tag.contains('vegan'))) {
      flags.add(RecipeDietaryFlag.vegan);
    }
    if (_normalizedTags.any((tag) =>
        tag.contains('vejetaryen') ||
        tag.contains('vegetarian') ||
        tag.contains('vegan'))) {
      flags.add(RecipeDietaryFlag.vegetarian);
    }
    if (_normalizedTags.any((tag) =>
        tag.contains('gluten free') || tag.contains('glutensiz'))) {
      flags.add(RecipeDietaryFlag.glutenFree);
    }
    return flags;
  }

  Set<RecipeGoalTag> _computeGoalTags() {
    final result = <RecipeGoalTag>{};
    if (_normalizedTags.any((tag) => tag.contains('yuksek protein')) ||
        proteinPerServing >= 20) {
      result.add(RecipeGoalTag.highProtein);
    }
    if (_normalizedTags.any((tag) => tag.contains('dusuk karb')) ||
        carbPerServing <= 20) {
      result.add(RecipeGoalTag.lowCarb);
    }
    if (_normalizedTags.any((tag) => tag.contains('dusuk yag')) ||
        fatPerServing <= 10) {
      result.add(RecipeGoalTag.lowFat);
    }
    if (_normalizedTags.any((tag) => tag.contains('hizli')) ||
        totalTimeMinutes <= 15) {
      result.add(RecipeGoalTag.fast);
    }
    if (_normalizedTags.any((tag) => tag.contains('kahvaltilik'))) {
      result.add(RecipeGoalTag.breakfast);
    }
    if (_normalizedTags.any((tag) => tag.contains('meal prep'))) {
      result.add(RecipeGoalTag.mealPrep);
    }
    if (_normalizedTags.any((tag) => tag.contains('omega 3'))) {
      result.add(RecipeGoalTag.omega3);
    }
    if (_normalizedTags.any((tag) => tag.contains('antioksidan'))) {
      result.add(RecipeGoalTag.antioxidant);
    }
    return result;
  }

  bool get isVegan => dietaryFlags.contains(RecipeDietaryFlag.vegan);

  bool get isVegetarian =>
      dietaryFlags.contains(RecipeDietaryFlag.vegetarian) || isVegan;

  bool get isGlutenFree =>
      dietaryFlags.contains(RecipeDietaryFlag.glutenFree);

  bool get hasImageAsset =>
      imageAsset != null && imageAsset!.trim().isNotEmpty;

  List<String> get searchTerms {
    return [
      name,
      description,
      difficulty,
      _categorySearchLabel(category),
      ...tags,
      ...ingredients.map((ingredient) => ingredient.name),
      ...dietaryFlags.map((flag) => flag.label),
      ...goalTags.map((goalTag) => goalTag.label),
    ];
  }

  String _computeSearchableText() =>
      _normalizeRecipeText(searchTerms.where((term) => term.trim().isNotEmpty).join(' '));

  double portionFactorFor(int desiredServings) {
    if (servings <= 0 || desiredServings <= 0) return 1;
    return desiredServings / servings;
  }

  List<RecipeIngredient> scaledIngredientsFor(int desiredServings) {
    final factor = portionFactorFor(desiredServings);
    return ingredients.map((ingredient) => ingredient.scaled(factor)).toList();
  }

  List<GroceryItem> toGroceryItems({
    int? portions,
    String? linkedMealName,
  }) {
    final desiredPortions = portions ?? servings;
    return scaledIngredientsFor(desiredPortions).map((ingredient) {
      final normalizedUnit = _normalizeRecipeText(ingredient.unit);
      final totalGrams = normalizedUnit == 'g' ? ingredient.amount : 0.0;
      return GroceryItem(
        name: ingredient.name,
        normalizedName: ingredient.normalizedName,
        category: ingredient.category?.trim() ?? '',
        totalGrams: totalGrams,
        quantityLabel: ingredient.displayAmount,
        linkedMeals: [
          if (linkedMealName != null && linkedMealName.trim().isNotEmpty)
            linkedMealName.trim(),
        ],
        source: 'recipe',
      );
    }).toList();
  }

  @Deprecated('Use toGroceryItems() for structured recipe shopping export.')
  List<String> get shoppingIngredients =>
      ingredients.map((ingredient) => '${ingredient.displayAmount} ${ingredient.name}').toList();
}
