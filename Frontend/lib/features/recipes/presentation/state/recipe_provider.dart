import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/storage_helper.dart';
import '../../data/recipe_api_service.dart';
import '../../data/recipe_loader.dart';
import '../../domain/entities/recipe.dart';
import '../../domain/repositories/recipe_repository.dart';

const _recipeFavoritesKey = 'recipe_favorites';
const _recipeRecentKey = 'recipe_recently_viewed';
const _recipeCookCountsKey = 'recipe_cook_counts';
const _recipeCustomKey = 'recipe_custom_recipes';

String _recipeUserKey(String base) => StorageHelper.userScopedKey(base);

const Map<String, List<String>> _searchSynonyms = {
  'snack': ['atistirmalik', 'ara ogun'],
  'ara ogun': ['atistirmalik', 'snack'],
  'kahvalti': ['kahvaltilik', 'breakfast'],
  'breakfast': ['kahvaltilik', 'kahvalti'],
  'ogle': ['ana yemek', 'lunch'],
  'lunch': ['ogle', 'ana yemek'],
  'aksam': ['ana yemek', 'dinner'],
  'dinner': ['aksam', 'ana yemek'],
  'yogurt': ['yogurt', 'yoğurt'],
  'glutensiz': ['gluten free'],
  'gluten free': ['glutensiz'],
  'vejetaryen': ['vegetarian'],
  'vegetarian': ['vejetaryen'],
  'hizli': ['pratik', 'fast'],
  'fast': ['hizli', 'pratik'],
};

String _normalizeForSearch(String input) {
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

enum SortMode { none, highProtein, lowCalorie, fastestFirst, difficultyAsc }

extension SortModeLabel on SortMode {
  String get label {
    switch (this) {
      case SortMode.none:
        return 'Varsayılan';
      case SortMode.highProtein:
        return 'En Yüksek Protein';
      case SortMode.lowCalorie:
        return 'En Az Kalori';
      case SortMode.fastestFirst:
        return 'En Hızlı';
      case SortMode.difficultyAsc:
        return 'En Kolay';
    }
  }

  String get emoji {
    switch (this) {
      case SortMode.none:
        return '🔀';
      case SortMode.highProtein:
        return '💪';
      case SortMode.lowCalorie:
        return '🔥';
      case SortMode.fastestFirst:
        return '⏱️';
      case SortMode.difficultyAsc:
        return '⭐';
    }
  }
}

class RecipeFilter {
  final double? maxKcal;
  final double? minProtein;
  final int? maxMinutes;
  final bool veganOnly;
  final bool vegetarianOnly;
  final bool glutenFreeOnly;

  const RecipeFilter({
    this.maxKcal,
    this.minProtein,
    this.maxMinutes,
    this.veganOnly = false,
    this.vegetarianOnly = false,
    this.glutenFreeOnly = false,
  });

  bool get isActive =>
      maxKcal != null ||
      minProtein != null ||
      maxMinutes != null ||
      veganOnly ||
      vegetarianOnly ||
      glutenFreeOnly;

  int get activeCount {
    var count = 0;
    if (maxKcal != null) count++;
    if (minProtein != null) count++;
    if (maxMinutes != null) count++;
    if (veganOnly) count++;
    if (vegetarianOnly) count++;
    if (glutenFreeOnly) count++;
    return count;
  }

  RecipeFilter copyWith({
    Object? maxKcal = _sentinel,
    Object? minProtein = _sentinel,
    Object? maxMinutes = _sentinel,
    bool? veganOnly,
    bool? vegetarianOnly,
    bool? glutenFreeOnly,
  }) {
    return RecipeFilter(
      maxKcal: maxKcal == _sentinel ? this.maxKcal : maxKcal as double?,
      minProtein: minProtein == _sentinel
          ? this.minProtein
          : minProtein as double?,
      maxMinutes: maxMinutes == _sentinel
          ? this.maxMinutes
          : maxMinutes as int?,
      veganOnly: veganOnly ?? this.veganOnly,
      vegetarianOnly: vegetarianOnly ?? this.vegetarianOnly,
      glutenFreeOnly: glutenFreeOnly ?? this.glutenFreeOnly,
    );
  }

  static const _sentinel = Object();
}

class RecipeProvider extends ChangeNotifier {
  final RecipeRepository _repository;
  final RecipeApiService _api = RecipeApiService();

  RecipeProvider({RecipeRepository? repository})
    : _repository = repository ?? LocalRecipeRepository();

  List<Recipe> _all = [];
  bool _loading = false;
  String _searchQuery = '';
  String _selectedCategory = 'tümü';
  SortMode _sortMode = SortMode.none;
  Set<String> _favoriteIds = {};
  bool _showOnlyFavorites = false;
  String? _errorMessage;
  RecipeFilter _filter = const RecipeFilter();
  List<String> _recentlyViewedIds = [];
  Map<String, int> _cookCounts = {};
  List<Recipe> _customRecipes = [];

  bool get loading => _loading;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  SortMode get sortMode => _sortMode;
  bool get showOnlyFavorites => _showOnlyFavorites;
  List<Recipe> get all => _all;
  String? get errorMessage => _errorMessage;
  RecipeFilter get filter => _filter;

  List<Recipe> get recentlyViewed =>
      _recentlyViewedIds.map(_findRecipeById).whereType<Recipe>().toList();

  int cookCountFor(String recipeId) => _cookCounts[recipeId] ?? 0;

  int countFor(String categoryId) {
    if (categoryId == 'tümü') return _all.length;
    return _all.where((recipe) => recipe.category == categoryId).length;
  }

  Recipe? _findRecipeById(String recipeId) {
    for (final recipe in _all) {
      if (recipe.id == recipeId) return recipe;
    }
    return null;
  }

  Recipe? get todaysFeatured {
    if (_all.isEmpty) return null;
    final now = DateTime.now();
    final seed = now.day + now.month * 31 + now.year * 12;
    return _all[seed % _all.length];
  }

  List<Recipe> get filtered {
    var list = List<Recipe>.from(_all);

    if (_showOnlyFavorites) {
      list = list.where((recipe) => _favoriteIds.contains(recipe.id)).toList();
    }

    if (_selectedCategory != 'tümü') {
      list = list
          .where((recipe) => recipe.category == _selectedCategory)
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      list = list
          .where((recipe) => _matchesQuery(recipe, _searchQuery))
          .toList();
    }

    if (_filter.isActive) {
      list = list.where(_matchesFilter).toList();
    }

    switch (_sortMode) {
      case SortMode.highProtein:
        list.sort((a, b) => b.proteinPerServing.compareTo(a.proteinPerServing));
        break;
      case SortMode.lowCalorie:
        list.sort((a, b) => a.kcalPerServing.compareTo(b.kcalPerServing));
        break;
      case SortMode.fastestFirst:
        list.sort((a, b) => a.totalTimeMinutes.compareTo(b.totalTimeMinutes));
        break;
      case SortMode.difficultyAsc:
        list.sort((a, b) => a.difficultyRank.compareTo(b.difficultyRank));
        break;
      case SortMode.none:
        break;
    }

    return list;
  }

  bool _matchesQuery(Recipe recipe, String query) {
    final blob = recipe.searchableText;
    final normalizedQuery = _normalizeForSearch(query);
    if (normalizedQuery.isEmpty) return true;

    final queryVariants = _queryVariants(normalizedQuery);
    if (queryVariants.any(blob.contains)) return true;

    final tokens = normalizedQuery
        .split(' ')
        .where((token) => token.isNotEmpty);
    return tokens.every((token) {
      final tokenVariants = _queryVariants(token);
      return tokenVariants.any(blob.contains);
    });
  }

  bool _matchesFilter(Recipe recipe) {
    if (_filter.maxKcal != null && recipe.kcalPerServing > _filter.maxKcal!) {
      return false;
    }
    if (_filter.minProtein != null &&
        recipe.proteinPerServing < _filter.minProtein!) {
      return false;
    }
    if (_filter.maxMinutes != null &&
        recipe.totalTimeMinutes > _filter.maxMinutes!) {
      return false;
    }
    if (_filter.veganOnly && !recipe.isVegan) return false;
    if (_filter.vegetarianOnly && !recipe.isVegetarian) return false;
    if (_filter.glutenFreeOnly && !recipe.isGlutenFree) return false;
    return true;
  }

  Set<String> _queryVariants(String query) {
    final normalized = _normalizeForSearch(query);
    if (normalized.isEmpty) return const <String>{};

    final variants = <String>{normalized};
    final direct = _searchSynonyms[normalized];
    if (direct != null) {
      variants.addAll(direct.map(_normalizeForSearch));
    }

    for (final entry in _searchSynonyms.entries) {
      if (entry.value.any(
        (variant) => _normalizeForSearch(variant) == normalized,
      )) {
        variants.add(_normalizeForSearch(entry.key));
      }
    }

    final tokens = normalized.split(' ').where((token) => token.isNotEmpty);
    for (final token in tokens) {
      variants.add(token);
      final tokenDirect = _searchSynonyms[token];
      if (tokenDirect != null) {
        variants.addAll(tokenDirect.map(_normalizeForSearch));
      }
    }

    return variants.where((variant) => variant.isNotEmpty).toSet();
  }

  Recipe? featuredFor({double? remainingKcal}) {
    final picks = recommendedFor(remainingKcal: remainingKcal, limit: 1);
    if (picks.isNotEmpty) return picks.first;
    final defaultFeatured = todaysFeatured;
    if (defaultFeatured != null &&
        filtered.any((recipe) => recipe.id == defaultFeatured.id)) {
      return defaultFeatured;
    }
    return filtered.isNotEmpty ? filtered.first : null;
  }

  List<Recipe> recommendedFor({
    double? remainingKcal,
    int limit = 6,
    Iterable<String> excludeIds = const [],
  }) {
    final excluded = excludeIds.toSet();
    final candidates = filtered
        .where((recipe) => !excluded.contains(recipe.id))
        .toList();
    candidates.sort(
      (a, b) => _recommendationScore(
        b,
        remainingKcal: remainingKcal,
      ).compareTo(_recommendationScore(a, remainingKcal: remainingKcal)),
    );
    return candidates.take(limit).toList();
  }

  List<Recipe> quickPicks({
    int limit = 6,
    Iterable<String> excludeIds = const [],
  }) {
    final excluded = excludeIds.toSet();
    final picks = filtered
        .where((recipe) => !excluded.contains(recipe.id))
        .toList();
    picks.sort((a, b) {
      final byTime = a.totalTimeMinutes.compareTo(b.totalTimeMinutes);
      if (byTime != 0) return byTime;
      return b.proteinPerServing.compareTo(a.proteinPerServing);
    });
    return picks.take(limit).toList();
  }

  List<Recipe> similarTo(Recipe recipe, {int limit = 6}) {
    final candidates = _all.where((item) => item.id != recipe.id).toList();
    candidates.sort(
      (a, b) =>
          _similarityScore(b, recipe).compareTo(_similarityScore(a, recipe)),
    );
    return candidates.take(limit).toList();
  }

  double _recommendationScore(Recipe recipe, {double? remainingKcal}) {
    var score = 0.0;

    if (_favoriteIds.contains(recipe.id)) {
      score += 12;
    }

    final recentIndex = _recentlyViewedIds.indexOf(recipe.id);
    if (recentIndex != -1) {
      score += (8 - recentIndex).clamp(1, 8).toDouble();
    }

    score += cookCountFor(recipe.id).clamp(0, 4) * 2.5;
    score += _preferenceAffinity(recipe);

    final proteinDensity =
        recipe.proteinPerServing /
        (recipe.kcalPerServing <= 0 ? 1 : recipe.kcalPerServing);
    score += proteinDensity * 180;

    if (recipe.goalTags.contains(RecipeGoalTag.highProtein)) score += 3;
    if (recipe.goalTags.contains(RecipeGoalTag.fast)) score += 2;
    if (recipe.goalTags.contains(RecipeGoalTag.mealPrep)) score += 1.5;

    if (remainingKcal != null && remainingKcal > 0) {
      final delta = remainingKcal - recipe.kcalPerServing;
      if (delta >= 0) {
        final closenessPenalty = ((delta / remainingKcal).clamp(0.0, 1.0)) * 6;
        score += 14 - closenessPenalty;
      } else {
        final overflowPenalty =
            (((-delta) / remainingKcal).clamp(0.0, 2.0)) * 6;
        score -= 8 + overflowPenalty;
      }
      if (recipe.kcalPerServing <= remainingKcal &&
          recipe.proteinPerServing >= 20) {
        score += 4;
      }
    }

    if (_filter.maxMinutes != null &&
        recipe.totalTimeMinutes <= _filter.maxMinutes!) {
      score += 1.5;
    }

    return score;
  }

  double _preferenceAffinity(Recipe recipe) {
    final historyRecipes = <Recipe>[
      ..._favoriteIds.map(_findRecipeById).whereType<Recipe>(),
      ...recentlyViewed.take(4),
    ];

    if (historyRecipes.isEmpty) return 0;

    var score = 0.0;
    final recipeTags = recipe.goalTags;
    final recipeDietaryFlags = recipe.dietaryFlags;

    for (final history in historyRecipes) {
      if (history.category == recipe.category) {
        score += 2.5;
      }
      score += history.goalTags.intersection(recipeTags).length * 1.4;
      score +=
          history.dietaryFlags.intersection(recipeDietaryFlags).length * 1.2;
      final ingredientMatches = history.ingredients
          .map((ingredient) => ingredient.normalizedName)
          .toSet()
          .intersection(
            recipe.ingredients
                .map((ingredient) => ingredient.normalizedName)
                .toSet(),
          )
          .length;
      score += ingredientMatches * 0.5;
    }

    return score;
  }

  double _similarityScore(Recipe candidate, Recipe anchor) {
    var score = 0.0;
    if (candidate.category == anchor.category) score += 4;
    score += candidate.goalTags.intersection(anchor.goalTags).length * 2;
    score +=
        candidate.dietaryFlags.intersection(anchor.dietaryFlags).length * 1.5;
    score +=
        candidate.ingredients
            .map((ingredient) => ingredient.normalizedName)
            .toSet()
            .intersection(
              anchor.ingredients
                  .map((ingredient) => ingredient.normalizedName)
                  .toSet(),
            )
            .length *
        0.6;
    final kcalGap = (candidate.kcalPerServing - anchor.kcalPerServing).abs();
    score -= (kcalGap / 100).clamp(0.0, 4.0);
    return score;
  }

  void addToRecentlyViewed(String recipeId) {
    _recentlyViewedIds.remove(recipeId);
    _recentlyViewedIds.insert(0, recipeId);
    if (_recentlyViewedIds.length > 8) {
      _recentlyViewedIds = _recentlyViewedIds.take(8).toList();
    }
    _saveRecent();
    notifyListeners();
  }

  Future<void> addCustomRecipe(Recipe recipe) async {
    _customRecipes.add(recipe);
    _all = [..._all, recipe];
    await _saveCustomRecipes();
    notifyListeners();
    _api.upsertRecipe(recipe);
  }

  Future<void> deleteCustomRecipe(String recipeId) async {
    _customRecipes.removeWhere((r) => r.id == recipeId);
    _all = _all.where((r) => r.id != recipeId).toList();
    _favoriteIds.remove(recipeId);
    _recentlyViewedIds.remove(recipeId);
    await _saveCustomRecipes();
    notifyListeners();
    _api.deleteRecipe(recipeId);
  }

  void markCooked(String recipeId) {
    _cookCounts[recipeId] = (_cookCounts[recipeId] ?? 0) + 1;
    _saveCookCounts();
    notifyListeners();
  }

  bool isFavorite(String recipeId) => _favoriteIds.contains(recipeId);

  void toggleFavorite(String recipeId) {
    if (_favoriteIds.contains(recipeId)) {
      _favoriteIds.remove(recipeId);
    } else {
      _favoriteIds.add(recipeId);
    }
    _saveFavorites();
    notifyListeners();
  }

  int get favoriteCount => _favoriteIds.length;

  void setShowOnlyFavorites(bool value) {
    _showOnlyFavorites = value;
    if (value) _selectedCategory = 'tümü';
    notifyListeners();
  }

  Future<void> init({bool force = false}) async {
    if (_all.isNotEmpty && !force) return;

    _loading = true;
    _errorMessage = null;
    if (force) {
      _all = [];
      LocalRecipeRepository.clearCache();
    }
    notifyListeners();

    try {
      await Future.wait([
        _loadFavorites(),
        _loadRecent(),
        _loadCookCounts(),
        _loadCustomRecipes(),
      ]);
      final repoRecipes = await _repository.getAllRecipes();

      // Backend'den özel tarifleri al, local'dekilerle birleştir
      final remoteRecipes = await _api.fetchCustomRecipes();
      if (remoteRecipes.isNotEmpty) {
        final localIds = _customRecipes.map((r) => r.id).toSet();
        final newRemote = remoteRecipes
            .where((r) => !localIds.contains(r.id))
            .toList();
        _customRecipes = [..._customRecipes, ...newRemote];
        if (newRemote.isNotEmpty) await _saveCustomRecipes();
      }

      _all = [...repoRecipes, ..._customRecipes];
    } catch (e) {
      debugPrint('RecipeProvider init error: $e');
      _all = [];
      _errorMessage = 'Tarifler şu an yüklenemedi. Lütfen tekrar dene.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> retry() => init(force: true);

  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _showOnlyFavorites = false;
    notifyListeners();
  }

  void setSortMode(SortMode mode) {
    _sortMode = mode;
    notifyListeners();
  }

  void setFilter(RecipeFilter filter) {
    _filter = filter;
    notifyListeners();
  }

  void clearFilter() {
    _filter = const RecipeFilter();
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recipeUserKey(_recipeFavoritesKey),
      _favoriteIds.toList(),
    );
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    _favoriteIds =
        (prefs.getStringList(_recipeUserKey(_recipeFavoritesKey)) ?? [])
            .toSet();
  }

  Future<void> _saveRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _recipeUserKey(_recipeRecentKey),
      _recentlyViewedIds,
    );
  }

  Future<void> _loadRecent() async {
    final prefs = await SharedPreferences.getInstance();
    _recentlyViewedIds =
        prefs.getStringList(_recipeUserKey(_recipeRecentKey)) ?? [];
  }

  Future<void> _saveCookCounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recipeUserKey(_recipeCookCountsKey),
      jsonEncode(_cookCounts),
    );
  }

  Future<void> _loadCookCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recipeUserKey(_recipeCookCountsKey));
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _cookCounts = decoded.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
    } catch (e) {
      debugPrint('RecipeProvider cook count decode error: $e');
      _cookCounts = {};
    }
  }

  Future<void> _saveCustomRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = _customRecipes.map((r) => r.toJson()).toList();
    await prefs.setString(
      _recipeUserKey(_recipeCustomKey),
      jsonEncode(jsonList),
    );
  }

  Future<void> _loadCustomRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recipeUserKey(_recipeCustomKey));
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as List;
      _customRecipes = decoded
          .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('RecipeProvider custom recipe decode error: $e');
      _customRecipes = [];
    }
  }

  @visibleForTesting
  void seedStateForTesting({
    required List<Recipe> recipes,
    Set<String> favoriteIds = const {},
    List<String> recentlyViewedIds = const [],
    Map<String, int> cookCounts = const {},
    String searchQuery = '',
    String selectedCategory = 'tümü',
    SortMode sortMode = SortMode.none,
    bool showOnlyFavorites = false,
    RecipeFilter filter = const RecipeFilter(),
  }) {
    _all = recipes;
    _favoriteIds = favoriteIds;
    _recentlyViewedIds = recentlyViewedIds;
    _cookCounts = cookCounts;
    _searchQuery = searchQuery;
    _selectedCategory = selectedCategory;
    _sortMode = sortMode;
    _showOnlyFavorites = showOnlyFavorites;
    _filter = filter;
    _loading = false;
    _errorMessage = null;
  }

  static const List<Map<String, String>> categories = [
    {'id': 'tümü', 'label': 'Tümü', 'emoji': '🍽️'},
    {'id': 'bowl', 'label': 'Bowl', 'emoji': '🥣'},
    {'id': 'ana_yemek', 'label': 'Ana Yemek', 'emoji': '🍲'},
    {'id': 'salata', 'label': 'Salata', 'emoji': '🥗'},
    {'id': 'smoothie', 'label': 'Smoothie', 'emoji': '🥤'},
    {'id': 'atistirmalik', 'label': 'Atıştırmalık', 'emoji': '⚡'},
  ];
}
