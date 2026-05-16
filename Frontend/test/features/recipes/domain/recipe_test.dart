import 'package:pusulafit/features/recipes/domain/entities/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _recipeFromJson(Map<String, dynamic> overrides) {
  return Recipe.fromJson({
    'id': 'recipe_1',
    'name': 'Protein Bowl',
    'description': 'Yuksek proteinli pratik tarif.',
    'category': 'bowl',
    'servings': 2,
    'prepTimeMinutes': 10,
    'cookTimeMinutes': 5,
    'ingredients': [
      {
        'name': 'yogurt',
        'amount': 100,
        'unit': 'g',
        'category': 'sut urunleri',
      },
      {'name': 'muz', 'amount': 1, 'unit': 'adet', 'category': 'sebze/meyve'},
    ],
    'steps': ['Karistir', 'Servis et'],
    'imageEmoji': '🥣',
    'kcalPerServing': 320,
    'proteinPerServing': 28,
    'carbPerServing': 18,
    'fatPerServing': 8,
    'tags': ['vegan', 'gluten free', 'meal prep'],
    'difficulty': 'kolay',
    ...overrides,
  });
}

void main() {
  test('typed dietary flags are derived from tags', () {
    final recipe = _recipeFromJson({});

    expect(recipe.isVegan, isTrue);
    expect(recipe.isVegetarian, isTrue);
    expect(recipe.isGlutenFree, isTrue);
    expect(
      recipe.goalTags.map((tag) => tag.label),
      containsAll(['yuksek protein', 'meal prep']),
    );
  });

  test('toGroceryItems scales ingredient quantities by requested portions', () {
    final recipe = _recipeFromJson({});

    final groceryItems = recipe.toGroceryItems(
      portions: 4,
      linkedMealName: recipe.name,
    );

    expect(groceryItems, hasLength(2));
    expect(groceryItems.first.name, 'yogurt');
    expect(groceryItems.first.quantityLabel, '200 g');
    expect(groceryItems.first.totalGrams, 200);
    expect(groceryItems.first.linkedMeals, [recipe.name]);
    expect(groceryItems[1].quantityLabel, '2 adet');
  });
}
