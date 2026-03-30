import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/entities/recipe.dart';
import '../domain/repositories/recipe_repository.dart';

class LocalRecipeRepository implements RecipeRepository {
  static const String _assetPath = 'assets/recipes/recipes_tr.json';

  static List<Recipe>? _cache;

  /// Throws on any error so the caller can decide how to handle it.
  @override
  Future<List<Recipe>> getAllRecipes() async {
    if (_cache != null) return _cache!;

    // Simulate network latency for backend migration preparation
    await Future.delayed(const Duration(milliseconds: 600));

    final raw = await rootBundle.loadString(_assetPath);
    final list = jsonDecode(raw) as List;
    _cache = list
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  /// Clear the cache (e.g. for testing or forced reload).
  static void clearCache() => _cache = null;
}

/// Backward-compatible facade used by existing callers.
class RecipeLoader {
  static final LocalRecipeRepository _repository = LocalRecipeRepository();

  static Future<List<Recipe>> loadAll() => _repository.getAllRecipes();

  static void clearCache() => LocalRecipeRepository.clearCache();
}
