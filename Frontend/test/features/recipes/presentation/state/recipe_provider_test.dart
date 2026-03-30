import 'package:fitness/features/recipes/domain/entities/recipe.dart';
import 'package:fitness/features/recipes/presentation/state/recipe_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Recipe _recipe({
  required String id,
  required String name,
  required String category,
  required double kcal,
  required double protein,
  required List<String> tags,
  required List<Map<String, dynamic>> ingredients,
  int totalMinutes = 20,
}) {
  return Recipe.fromJson({
    'id': id,
    'name': name,
    'description': '$name aciklamasi',
    'category': category,
    'servings': 1,
    'prepTimeMinutes': totalMinutes ~/ 2,
    'cookTimeMinutes': totalMinutes ~/ 2,
    'ingredients': ingredients,
    'steps': ['Hazirla'],
    'imageEmoji': '🍽️',
    'kcalPerServing': kcal,
    'proteinPerServing': protein,
    'carbPerServing': 20,
    'fatPerServing': 8,
    'tags': tags,
    'difficulty': 'kolay',
  });
}

void main() {
  late RecipeProvider provider;
  late Recipe glutenFreeBowl;
  late Recipe snackRecipe;
  late Recipe heavySalad;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = RecipeProvider();
    glutenFreeBowl = _recipe(
      id: 'bowl',
      name: 'Gluten Free Bowl',
      category: 'bowl',
      kcal: 420,
      protein: 34,
      tags: ['gluten free', 'yuksek protein'],
      ingredients: [
        {'name': 'tavuk', 'amount': 150, 'unit': 'g', 'category': 'et'},
      ],
      totalMinutes: 18,
    );
    snackRecipe = _recipe(
      id: 'snack',
      name: 'Enerji Topu',
      category: 'atistirmalik',
      kcal: 180,
      protein: 8,
      tags: ['hizli'],
      ingredients: [
        {'name': 'yulaf', 'amount': 40, 'unit': 'g', 'category': 'tahil'},
      ],
      totalMinutes: 8,
    );
    heavySalad = _recipe(
      id: 'salad',
      name: 'Buyuk Salata',
      category: 'salata',
      kcal: 690,
      protein: 22,
      tags: ['antioksidan'],
      ingredients: [
        {
          'name': 'avokado',
          'amount': 1,
          'unit': 'adet',
          'category': 'sebze/meyve',
        },
      ],
      totalMinutes: 25,
    );
  });

  test('normalized search matches typed dietary flags and synonyms', () {
    provider.seedStateForTesting(
      recipes: [glutenFreeBowl, snackRecipe, heavySalad],
      searchQuery: 'glutensiz',
    );

    expect(provider.filtered.map((recipe) => recipe.id), ['bowl']);

    provider.seedStateForTesting(
      recipes: [glutenFreeBowl, snackRecipe, heavySalad],
      searchQuery: 'snack',
    );

    expect(provider.filtered.map((recipe) => recipe.id), ['snack']);
  });

  test('typed filters use recipe attributes instead of raw string contains', () {
    provider.seedStateForTesting(
      recipes: [glutenFreeBowl, snackRecipe, heavySalad],
      filter: const RecipeFilter(
        maxMinutes: 20,
        minProtein: 20,
        glutenFreeOnly: true,
      ),
    );

    expect(provider.filtered.map((recipe) => recipe.id), ['bowl']);
  });

  test('recommendedFor prioritizes history and remaining calories', () {
    provider.seedStateForTesting(
      recipes: [glutenFreeBowl, snackRecipe, heavySalad],
      favoriteIds: {'bowl'},
      recentlyViewedIds: ['bowl'],
      cookCounts: const {'bowl': 2},
    );

    final recommended = provider.recommendedFor(
      remainingKcal: 500,
      limit: 2,
    );

    expect(recommended.first.id, 'bowl');
    expect(recommended.map((recipe) => recipe.id), isNot(contains('salad')));
  });

  test('similarTo prefers category and shared traits', () {
    final bowlVariant = _recipe(
      id: 'bowl_2',
      name: 'Tavuk Bowl',
      category: 'bowl',
      kcal: 430,
      protein: 30,
      tags: ['yuksek protein'],
      ingredients: [
        {'name': 'tavuk', 'amount': 120, 'unit': 'g', 'category': 'et'},
      ],
      totalMinutes: 16,
    );

    provider.seedStateForTesting(
      recipes: [glutenFreeBowl, snackRecipe, heavySalad, bowlVariant],
    );

    final similar = provider.similarTo(glutenFreeBowl, limit: 2);

    expect(similar.first.id, 'bowl_2');
  });
}
