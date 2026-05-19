import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/storage_helper.dart';
import '../domain/entities/recipe.dart';

class RecipeApiService {
  Options get _authOptions {
    final token = StorageHelper.getToken();
    return Options(headers: token != null ? {'Authorization': 'Bearer $token'} : {});
  }

  bool get _hasToken {
    final token = StorageHelper.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<List<Recipe>> fetchCustomRecipes() async {
    if (!_hasToken) return [];
    try {
      final res = await ApiClient().get(ApiConstants.recipes, options: _authOptions);
      if (res.statusCode != 200) return [];
      final List<dynamic> data = res.data as List<dynamic>;
      return data
          .whereType<Map<String, dynamic>>()
          .map(_toRecipe)
          .whereType<Recipe>()
          .toList();
    } catch (e) {
      debugPrint('RecipeApiService.fetch error: $e');
      return [];
    }
  }

  Future<bool> upsertRecipe(Recipe recipe) async {
    if (!_hasToken) return false;
    try {
      final res = await ApiClient().post(
        ApiConstants.recipes,
        data: recipe.toJson(),
        options: _authOptions,
      );
      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      debugPrint('RecipeApiService.upsert error: $e');
      return false;
    }
  }

  Future<bool> deleteRecipe(String recipeId) async {
    if (!_hasToken) return false;
    try {
      final res = await ApiClient().delete(
        '${ApiConstants.recipes}/$recipeId',
        options: _authOptions,
      );
      return res.statusCode == 204;
    } catch (e) {
      debugPrint('RecipeApiService.delete error: $e');
      return false;
    }
  }

  Recipe? _toRecipe(Map<String, dynamic> json) {
    try {
      return Recipe.fromJson(json);
    } catch (e) {
      debugPrint('RecipeApiService._toRecipe parse error: $e');
      return null;
    }
  }
}
