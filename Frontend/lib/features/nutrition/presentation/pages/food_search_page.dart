import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../../../core/services/ai_safety_helper.dart';
import '../../../../core/utils/storage_helper.dart';
import 'add_custom_food_page.dart';
import '../../ai_scan/presentation/pages/barcode_scan_page.dart';

String _foodDisplayName(FoodItem food) => _shortFoodName(food.name);

bool _isVerifiedFoodData(FoodItem food) {
  final id = food.id.toLowerCase();
  return id.startsWith('off_') ||
      id.startsWith('trverified_') ||
      food.tags.contains('verified-source') ||
      food.tags.contains('open-food-facts') ||
      food.tags.contains('guven-yuksek');
}

String _foodSourceLabel(FoodItem food) {
  final id = food.id.toLowerCase();
  if (id.startsWith('off_') || food.tags.contains('open-food-facts')) {
    return 'Etiket Verisi';
  }
  return 'Doğrulanmış';
}

const List<String> _preferredCategoryOrder = [
  'Kahvaltılık',
  'Kahvaltı',
  'Ara Öğün',
  'Atıştırmalık',
  'Çorba',
  'Yemek',
  'Et / Tavuk',
  'Et Yemeği',
  'Tavuk',
  'Balık',
  'Fast Food',
  'Pilav & Makarna',
  'Meze & Salata',
  'Salata & Meze',
  'Salata',
  'Sebze Yemeği',
  'Hamur İşi',
  'Sokak Yemeği',
  'Tatlı',
  'Tatlı & Atıştırma',
  'Meyve & Sebze',
  'Meyve',
  'Kuru Meyve & Kuruyemiş',
  'İçecek',
  'Süt Ürünleri',
];

class _SearchFilterOption {
  final String key;
  final String label;
  final IconData icon;

  const _SearchFilterOption(this.key, this.label, this.icon);
}

final Map<String, String> _shortFoodNameCache = {};

String _shortFoodName(String raw) {
  final originalTrimmed = raw.trim();
  if (originalTrimmed.isEmpty) return raw;

  if (_shortFoodNameCache.containsKey(originalTrimmed)) {
    return _shortFoodNameCache[originalTrimmed]!;
  }

  var text = originalTrimmed;

  final replacements = <RegExp, String>{
    RegExp(r'^Yumurta Omlet veya Scrambled Yumurta', caseSensitive: false):
        'Omlet',
    RegExp(r'\bveya Scrambled\b', caseSensitive: false): '',
    RegExp(r'\bScrambled\b', caseSensitive: false): '',
    RegExp(r'\bAs Ingredient In\b.*$', caseSensitive: false): '',
    RegExp(r'\bMade (With|From)\b.*$', caseSensitive: false): '',
    RegExp(r'\bFrom (Konserve|Kurutulmuş)\b.*$', caseSensitive: false): '',
    RegExp(r'\bNo Added Fat\b.*$', caseSensitive: false): '',
    RegExp(r'\bSkin (Eaten|Not Eaten)\b.*$', caseSensitive: false): '',
    RegExp(r'\bSeparable Lean( and Fat)?\b.*$', caseSensitive: false): '',
    RegExp(r'\s+ve\s+Dar.*$', caseSensitive: false): '',
  };

  replacements.forEach((pattern, replacement) {
    text = text.replaceAll(pattern, replacement);
  });

  text = text
      .replaceAll(RegExp(r'\s*,\s*'), ', ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .replaceAll(RegExp(r',\s*,'), ', ')
      .trim();

  final segments = text
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();

  if (segments.isEmpty) return raw;

  if (text.toLowerCase().contains('omlet')) {
    final descriptors = <String>[];
    for (final segment in segments.skip(1)) {
      final lower = segment.toLowerCase();
      if (lower.contains('peynir')) descriptors.add('Peynirli');
      if (lower.contains('domates')) descriptors.add('Domatesli');
      if (lower.contains('biber')) descriptors.add('Biberli');
      if (lower.contains('mantar')) descriptors.add('Mantarlı');
      if (lower.contains('ıspanak') || lower.contains('ispanak')) {
        descriptors.add('Ispanakli');
      }
    }

    final prefix = descriptors.toSet().take(2).join(' ');
    return prefix.isEmpty ? 'Omlet' : '$prefix Omlet';
  }

  var display = segments.first
      .split(RegExp(r'\s+veya\s+', caseSensitive: false))
      .first
      .trim();

  if (segments.length > 1) {
    final extra = segments
        .skip(1)
        .firstWhere((segment) => segment.length <= 16, orElse: () => '');
    if (extra.isNotEmpty && display.length + extra.length + 2 <= 34) {
      display = '$display, $extra';
    }
  }

  if (display.length <= 34) return display;

  final words = display.split(' ');
  final buffer = StringBuffer();
  for (final word in words) {
    final candidate = buffer.isEmpty ? word : '${buffer.toString()} $word';
    if (candidate.length > 30) break;
    if (buffer.isNotEmpty) buffer.write(' ');
    buffer.write(word);
  }

  final shortened = buffer.toString().trim();
  if (shortened.isEmpty) {
    final result = '${display.substring(0, 30).trimRight()}...';
    _shortFoodNameCache[originalTrimmed] = result;
    return result;
  }

  final result = shortened.length == display.length
      ? shortened
      : '$shortened...';
  _shortFoodNameCache[originalTrimmed] = result;
  return result;
}

/// Yemek arama: Premium tasarım, Glassmorphic search bar, hızlı öneriler.
class FoodSearchPage extends StatefulWidget {
  final MealType? selectedMealType;

  const FoodSearchPage({super.key, this.selectedMealType});

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  Timer? _debounce;
  final _query = ValueNotifier<String>('');
  final _searchController = TextEditingController();
  List<FoodItem> _recentFoods = [];
  List<FoodItem> _frequentFoods = [];
  List<FoodItem> _favoriteFoods = [];
  List<FoodItem> _recommendedFoods = [];
  List<FoodItem> _list = [];
  List<String> _availableCategories = const [];
  bool _loading = false;
  bool _isSearchPending = false;
  bool _isAISearch = false;
  bool _backendReady = false;

  bool _isMultiAddMode = false;
  final Set<FoodItem> _selectedFoods = {};

  /// Seçili kategori (null = Tümü). Popüler Besinler bu kategoriye göre filtrelenir.
  String? _selectedCategory;
  String? _selectedSmartFilter;

  @override
  void initState() {
    super.initState();
    _determineSmartMealType();
    _query.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialData();
    });
    // Backend sağlık kontrolü (arka planda)
    AiSafetyHelper.instance.checkBackendHealth().then((ready) {
      if (mounted) setState(() => _backendReady = ready);
    });
  }

  Future<void> _loadInitialData() async {
    await _loadRecommendations();
    if (!mounted) return;
    unawaited(_loadRecents());
    unawaited(_loadFrequents());
    unawaited(_loadFavorites());
  }

  void _determineSmartMealType() {
    if (widget.selectedMealType != null) {
      return; // Zaten seçili geldiyse dokunma
    }

    final hour = DateTime.now().hour;
    MealType smartType;
    if (hour >= 5 && hour < 11) {
      smartType = MealType.breakfast;
    } else if (hour >= 11 && hour < 15) {
      smartType = MealType.lunch;
    } else if (hour >= 17 && hour < 22) {
      smartType = MealType.dinner;
    } else {
      smartType = MealType.snack;
    }

    // Hack: Widget state'ini güncellememiz lazım ama parent'tan gelen parametreyi değiştiremeyiz.
    // Bu yüzden UI'da widget.selectedMealType ?? _smartMealType kullanacağız.
    // Ancak state içinde _smartMealType tutmalıyız.
    _smartMealType = smartType;
  }

  MealType? _smartMealType;

  MealType get _effectiveMealType =>
      widget.selectedMealType ?? _smartMealType ?? MealType.snack;

  Future<void> _loadRecents() async {
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final recents = await provider.loadRecentFoods();
      if (mounted) {
        setState(() => _recentFoods = recents);
      }
    } catch (e) {
      debugPrint('FoodSearchPage _loadRecents error: $e');
    }
  }

  Future<void> _loadFrequents() async {
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final frequents = await provider.loadFrequentFoods();
      if (mounted) {
        setState(() => _frequentFoods = frequents);
      }
    } catch (e) {
      debugPrint('FoodSearchPage _loadFrequents error: $e');
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final favs = await provider.loadFavorites();
      if (mounted) {
        setState(() => _favoriteFoods = favs);
      }
    } catch (e) {
      debugPrint('FoodSearchPage _loadFavorites error: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final fullPool = await provider.searchFoods('', category: null);
      final recs = _selectedCategory == null
          ? fullPool
          : fullPool
                .where((item) => item.category == _selectedCategory)
                .toList();
      final categories =
          fullPool
              .map((item) => item.category.trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
            ..sort((a, b) {
              final ai = _preferredCategoryOrder.indexOf(a);
              final bi = _preferredCategoryOrder.indexOf(b);
              if (ai == -1 && bi == -1) return a.compareTo(b);
              if (ai == -1) return 1;
              if (bi == -1) return -1;
              return ai.compareTo(bi);
            });
      if (mounted) {
        final filtered = _applySmartFilter(recs);
        final items = _selectedCategory != null
            ? filtered
            : filtered.take(20).toList();
        setState(() {
          _availableCategories = categories;
          _recommendedFoods = items;
        });
      }
    } catch (e) {
      debugPrint('FoodSearchPage _loadRecommendations error: $e');
    }
  }

  void _onQueryChanged() {
    if (!mounted) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final trimmedQuery = _query.value.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _isSearchPending = false;
        _loading = false;
      });
      return;
    }
    setState(() => _isSearchPending = true);
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _search();
    });
  }

  Future<void> _search() async {
    if (!mounted) return;
    final trimmedQuery = _query.value.trim();
    if (trimmedQuery.isEmpty) {
      setState(() {
        _list = [];
        _loading = false;
        _isSearchPending = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _isSearchPending = false;
    });
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final list = _isAISearch
          ? await provider.aiSearch(trimmedQuery)
          : await provider.searchFoods(
              trimmedQuery,
              category: _selectedCategory,
            );
      if (mounted) {
        setState(() {
          _list = _applySmartFilter(list);
          _loading = false;
          _isSearchPending = false;
        });
      }
    } catch (e) {
      debugPrint('FoodSearchPage._search hatası: $e');
      if (mounted) {
        setState(() {
          _list = [];
          _loading = false;
          _isSearchPending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: _isMultiAddMode ? _buildMultiAddFab() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: AppGradientBackground(
        imagePath: 'assets/images/nutrition_bg_dark.png',
        child: Column(
          children: [
            // Custom Glass Header
            _buildGlassHeader(context),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0.03, 0),
                    end: Offset.zero,
                  ).animate(animation);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(position: slide, child: child),
                  );
                },
                child: _buildAnimatedBodyContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(FoodItem food) {
    try {
      Navigator.of(context, rootNavigator: false)
          .pushNamed(
            'portion',
            arguments: {'food': food, 'mealType': _effectiveMealType},
          )
          .then((_) {
            if (mounted && _query.value.isEmpty) _loadInitialData();
          });
    } catch (e) {
      debugPrint('FoodSearchPage portion navigation hatası: $e');
    }
  }

  Widget _buildAnimatedBodyContent() {
    if (_loading) {
      return Center(
        key: const ValueKey('food-search-loading'),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aranıyor...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_query.value.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('food-search-initial'),
        child: _buildInitialContent(),
      );
    }

    if (_list.isEmpty) {
      return KeyedSubtree(
        key: const ValueKey('food-search-empty'),
        child: _buildEmptyState(_query.value.trim().isEmpty),
      );
    }

    return ListView.builder(
      key: const ValueKey('food-search-results'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.m,
        vertical: AppSpacing.s,
      ),
      itemCount: _list.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildSearchResultsHeader();
        }
        final food = _list[index - 1];
        final isSelected = _selectedFoods.contains(food);
        return _isMultiAddMode
            ? _buildMultiSelectTile(food, isSelected)
            : _FoodListTile(
                food: food,
                selectedMealType: _effectiveMealType,
                onTap: () => _openDetail(food),
                onAddTap: () => _openPortion(food),
                onQuickAdd: (grams) => _quickAdd(food, grams),
              );
      },
    );
  }

  Widget _buildMultiSelectTile(FoodItem food, bool isSelected) {
    final kcal = food.kcalPer100g;
    final portion = DietProvider.getDefaultPortionForFood(food);
    final kcalPortion = kcal * portion / 100;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedFoods.remove(food);
          } else {
            _selectedFoods.add(food);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4CD1A3).withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.40),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4CD1A3)
                : Colors.white.withValues(alpha: 0.10),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? const Color(0xFF4CD1A3)
                    : Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF4CD1A3)
                      : Colors.white.withValues(alpha: 0.25),
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _foodDisplayName(food),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${portion.round()}g • ${kcalPortion.round()} kcal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${kcal.round()} kcal/100g',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPortion(FoodItem food) {
    try {
      Navigator.of(context, rootNavigator: false)
          .pushNamed(
            'portion',
            arguments: {'food': food, 'mealType': _effectiveMealType},
          )
          .then((_) {
            // Geri dönünce recent listesi güncellenmeli
            if (mounted && _query.value.isEmpty) _loadInitialData();
          });
    } catch (e) {
      debugPrint('FoodSearchPage portion navigation hatası: $e');
    }
  }

  void _quickAdd(FoodItem food, double grams) {
    try {
      // Hızlı ekleme için direkt porsiyon sayfasına yönlendir, ama gramajı hazır ver
      Navigator.of(context, rootNavigator: false)
          .pushNamed(
            'portion',
            arguments: {
              'food': food,
              'mealType': _effectiveMealType,
              'initialGrams': grams,
            },
          )
          .then((_) {
            if (mounted && _query.value.isEmpty) _loadInitialData();
          });
    } catch (e) {
      debugPrint('Quick add error: $e');
    }
  }

  void _showSavedMealOptions(SavedMeal meal) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded, color: AppColors.primary),
              title: const Text('Bu Öğünü Ekle', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _addSavedMeal(meal);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Öğünü Sil', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteSavedMeal(meal);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteSavedMeal(SavedMeal meal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Öğünü Sil', style: TextStyle(color: Colors.white)),
        content: Text(
          '${meal.name} silinecek. Emin misin?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<DietProvider>().deleteSavedMeal(meal.id);
            },
            child: const Text('Sil', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _addSavedMeal(SavedMeal meal) async {
    final provider = context.read<DietProvider>();
    await provider.addSavedMealToDay(
      meal: meal,
      mealType: _effectiveMealType,
      date: provider.selectedDate,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${meal.name} günlüğe eklendi.'),
        backgroundColor: AppColors.success,
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Section header helper (dashboard-style: left accent bar + icon + text)
  // ---------------------------------------------------------------------------
  Widget _buildSectionHeader(String title, IconData icon, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 16, color: accentColor.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Kategoriler ---
          _buildSectionHeader(
            'Kategoriler',
            Icons.grid_view_rounded,
            AppColors.primaryLight,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('Tümü', Icons.apps_rounded),
                  ..._availableCategories.map(
                    (category) =>
                        _buildCategoryChip(category, _categoryIcon(category)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSmartFilterRow(),
          ),
          const SizedBox(height: 24),

          // --- Kalan Kalori Bandı ---
          Consumer<DietProvider>(
            builder: (context, diet, _) {
              final remaining = diet.remainingKcal;
              final target = diet.effectiveTargetKcal;
              final consumed = target - remaining;
              final progress = target > 0
                  ? (consumed / target).clamp(0.0, 1.0)
                  : 0.0;
              final isOver = remaining < 0;
              final color = isOver
                  ? const Color(0xFFFF6B6B)
                  : remaining < target * 0.15
                  ? const Color(0xFFFFB74D)
                  : const Color(0xFF4CD1A3);
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.28)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isOver
                                ? Icons.warning_amber_rounded
                                : Icons.local_fire_department_rounded,
                            color: color,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOver
                                ? '${(-remaining).round()} kcal aşıldı'
                                : '${remaining.round()} kcal kaldı',
                            style: GoogleFonts.inter(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${consumed.round()} / ${target.round()} kcal',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // --- Favoriler (Ribbon) ---
          if (_favoriteFoods.isNotEmpty) ...[
            _buildSectionHeader(
              'Favorilerim',
              Icons.favorite_rounded,
              const Color(0xFFFF6B6B),
            ),
            _buildRibbonSection(
              'Favorilerim',
              _favoriteFoods,
              isFavorite: true,
            ),
          ],

          // --- Sık Yenenler (Ribbon) ---
          if (_frequentFoods.isNotEmpty) ...[
            _buildSectionHeader(
              'Sık Yenenler',
              Icons.repeat_rounded,
              const Color(0xFF43E97B),
            ),
            _buildRibbonSection(
              'Sık Yenenler',
              _frequentFoods,
              isFrequent: true,
            ),
          ],

          // --- Son Eklenenler (Ribbon) ---
          if (_recentFoods.isNotEmpty) ...[
            _buildSectionHeader(
              'Son Eklenenler',
              Icons.history_rounded,
              AppColors.secondary,
            ),
            _buildRibbonSection('Son Eklenenler', _recentFoods),
          ],

          // --- Popüler Besinler ---
          if (_recommendedFoods.isNotEmpty) ...[
            _buildSectionHeader(
              _selectedCategory ?? "Turkiye'de One Cikanlar",
              Icons.local_fire_department_rounded,
              AppColors.primary,
            ),
            ..._recommendedFoods.map(
              (food) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FoodListTile(
                  food: food,
                  selectedMealType: _effectiveMealType,
                  onTap: () => _openDetail(food),
                  onAddTap: () => _openPortion(food),
                  onQuickAdd: (grams) => _quickAdd(food, grams),
                ),
              ),
            ),
          ],

          // --- Kayıtlı Öğünlerim ---
          Consumer<DietProvider>(
            builder: (context, diet, _) {
              final savedMeals = diet.getSavedMeals();
              if (savedMeals.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    'Kayıtlı Öğünlerim',
                    Icons.bookmark_rounded,
                    const Color(0xFFA78BFA),
                  ),
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 16, right: 8, bottom: 8, top: 4),
                      itemCount: savedMeals.length,
                      itemBuilder: (context, i) {
                        final meal = savedMeals[i];
                        return GestureDetector(
                          onTap: () => _showSavedMealOptions(meal),
                          onLongPress: () => _confirmDeleteSavedMeal(meal),
                          child: Container(
                            width: 160,
                            margin: const EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFA78BFA).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.bookmark_rounded, size: 14, color: Color(0xFFA78BFA)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          meal.name,
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${meal.items.length} ürün',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFA78BFA).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Ekle',
                                      style: TextStyle(
                                        color: const Color(0xFFA78BFA),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildRibbonSection(
    String title,
    List<FoodItem> items, {
    bool isFrequent = false,
    bool isFavorite = false,
  }) {
    final Color accent = isFavorite
        ? const Color(0xFFFF6B6B)
        : isFrequent
        ? const Color(0xFF43E97B)
        : AppColors.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 136,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(
              left: 16,
              right: 8,
              bottom: 8,
              top: 4,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final food = items[index];
              final kcal = food.kcalPer100g;
              final p = food.proteinPer100g;
              final c = food.carbPer100g;
              final f = food.fatPer100g;
              final displayName = _foodDisplayName(food);
              final letter = displayName.isNotEmpty
                  ? displayName[0].toUpperCase()
                  : '?';

              return GestureDetector(
                onTap: () => _openDetail(food),
                child: Container(
                  width: 152,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: accent.withValues(alpha: 0.30)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        // Watermark letter in background
                        Positioned(
                          right: -12,
                          bottom: -10,
                          child: Text(
                            letter,
                            style: TextStyle(
                              color: accent.withValues(alpha: 0.08),
                              fontSize: 88,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        // Top accent bar
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent,
                                  accent.withValues(alpha: 0.40),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Content
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 8, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Food name
                              Text(
                                displayName,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              // Macro row (compact)
                              Row(
                                children: [
                                  Text(
                                    'P:${p.round()}',
                                    style: TextStyle(
                                      color: const Color(0xFF5B9BFF),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'K:${c.round()}',
                                    style: TextStyle(
                                      color: const Color(0xFF4CD1A3),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Y:${f.round()}',
                                    style: TextStyle(
                                      color: const Color(0xFFFFB74D),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              // Bottom: kcal + add button
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: accent.withValues(alpha: 0.30),
                                      ),
                                    ),
                                    child: Text(
                                      '${kcal.round()} kcal',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => _openPortion(food),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: accent.withValues(alpha: 0.20),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: accent.withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.add_rounded,
                                        size: 16,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildCategoryChip(String label, IconData icon) {
    final isTumu = label == 'Tümü';
    final isSelected = isTumu
        ? _selectedCategory == null
        : _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedCategory = isTumu ? null : label;
            });
            if (_query.value.trim().isNotEmpty) {
              _search();
            } else {
              _loadRecommendations();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected ? AppColors.primaryLight : Colors.white54,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? AppColors.primaryLight : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmartFilterRow() {
    final filters = _smartFiltersForMeal(_effectiveMealType);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildSmartFilterChip(
              label: 'Hepsi',
              icon: Icons.tune_rounded,
              selected: _selectedSmartFilter == null,
              onTap: () {
                setState(() => _selectedSmartFilter = null);
                _refreshVisibleContent();
              },
            );
          }
          final filter = filters[index - 1];
          return _buildSmartFilterChip(
            label: filter.label,
            icon: filter.icon,
            selected: _selectedSmartFilter == filter.key,
            onTap: () {
              setState(() {
                _selectedSmartFilter = _selectedSmartFilter == filter.key
                    ? null
                    : filter.key;
              });
              _refreshVisibleContent();
            },
          );
        },
      ),
    );
  }

  Widget _buildSmartFilterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? AppColors.primaryLight : Colors.white54,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: selected ? AppColors.primaryLight : Colors.white70,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResultsHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            '${_list.length} sonuç bulundu',
            Icons.manage_search_rounded,
            AppColors.primaryLight,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildSmartFilterRow(),
          ),
        ],
      ),
    );
  }

  void _refreshVisibleContent() {
    if (_query.value.trim().isNotEmpty) {
      _search();
    } else {
      _loadRecommendations();
    }
  }

  List<_SearchFilterOption> _smartFiltersForMeal(MealType mealType) {
    final base = <_SearchFilterOption>[
      const _SearchFilterOption(
        'yuksek_protein',
        'Yüksek Protein',
        Icons.bolt_rounded,
      ),
      const _SearchFilterOption(
        'hafif',
        'Hafif',
        Icons.local_fire_department_rounded,
      ),
      const _SearchFilterOption(
        'bolgesel',
        'Bölgesel',
        Icons.travel_explore_rounded,
      ),
      const _SearchFilterOption(
        'guvenli',
        'Güvenli Veri',
        Icons.verified_rounded,
      ),
    ];

    switch (mealType) {
      case MealType.breakfast:
        return [
          const _SearchFilterOption(
            'kahvaltilik',
            'Kahvaltılık',
            Icons.egg_alt_rounded,
          ),
          ...base,
        ];
      case MealType.lunch:
      case MealType.dinner:
        return [
          const _SearchFilterOption(
            'ev_yemegi',
            'Ev Yemeği',
            Icons.restaurant_rounded,
          ),
          const _SearchFilterOption(
            'corba',
            'Çorba',
            Icons.soup_kitchen_rounded,
          ),
          ...base,
        ];
      case MealType.snack:
        return [
          const _SearchFilterOption('tatli', 'Tatlı', Icons.cake_rounded),
          const _SearchFilterOption('pratik', 'Pratik', Icons.flash_on_rounded),
          ...base,
        ];
    }
  }

  List<FoodItem> _applySmartFilter(List<FoodItem> input) {
    final filter = _selectedSmartFilter;
    if (filter == null) return input;

    bool hasTag(FoodItem item, String prefix) =>
        item.tags.any((tag) => tag.startsWith(prefix));

    bool matches(FoodItem item) {
      switch (filter) {
        case 'yuksek_protein':
          return item.proteinPer100g >= 15;
        case 'hafif':
          return item.kcalPer100g <= 180;
        case 'bolgesel':
          return hasTag(item, 'bolge-');
        case 'guvenli':
          return _isVerifiedFoodData(item);
        case 'kahvaltilik':
          return item.category == 'Kahvaltılık';
        case 'ev_yemegi':
          return {
            'Yemek',
            'Sebze Yemeği',
            'Et Yemeği',
            'Tavuk',
            'Balık',
          }.contains(item.category);
        case 'corba':
          return item.category == 'Çorba';
        case 'tatli':
          return item.category == 'Tatlı';
        case 'pratik':
          return item.servings.isNotEmpty &&
              item.servings.first.grams <= 200 &&
              item.kcalPer100g <= 350;
      }
      return true;
    }

    final filtered = input.where(matches).toList();
    filtered.sort((a, b) {
      switch (filter) {
        case 'yuksek_protein':
          return b.proteinPer100g.compareTo(a.proteinPer100g);
        case 'hafif':
          return a.kcalPer100g.compareTo(b.kcalPer100g);
        default:
          return 0;
      }
    });
    return filtered;
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Kahvaltılık':
      case 'Kahvaltı':
        return Icons.egg_alt_outlined;
      case 'Yemek':
      case 'Et Yemeği':
      case 'Tavuk':
      case 'Et / Tavuk':
      case 'Balık':
        return Icons.restaurant_outlined;
      case 'Pilav & Makarna':
        return Icons.rice_bowl_outlined;
      case 'Meze & Salata':
      case 'Salata & Meze':
      case 'Salata':
        return Icons.eco_outlined;
      case 'Sebze Yemeği':
      case 'Sebze & Meyve':
      case 'Sebze':
        return Icons.spa_outlined;
      case 'Tatlı':
      case 'Tatlı & Atıştırma':
        return Icons.cake_outlined;
      case 'Çorba':
        return Icons.soup_kitchen_outlined;
      case 'Hamur İşi':
        return Icons.bakery_dining_outlined;
      case 'Ara Öğün':
      case 'Atıştırmalık':
        return Icons.cookie_outlined;
      case 'İçecek':
        return Icons.local_cafe_outlined;
      case 'Meyve':
      case 'Meyve & Sebze':
        return Icons.apple_outlined;
      case 'Kuru Meyve & Kuruyemiş':
        return Icons.grain_outlined;
      case 'Fast Food':
      case 'Sokak Yemeği':
        return Icons.fastfood_outlined;
      case 'Süt Ürünleri':
        return Icons.water_drop_outlined;
      default:
        return Icons.label_outline_rounded;
    }
  }

  // ---------------------------------------------------------------------------
  // _buildGlassHeader — redesigned (3 rows)
  // ---------------------------------------------------------------------------
  Widget _buildGlassHeader(BuildContext context) {
    // Meal type helpers
    Color mealColorFor(MealType type) {
      switch (type) {
        case MealType.breakfast:
          return const Color(0xFFFF9800); // orange
        case MealType.lunch:
          return const Color(0xFF4CAF50); // green
        case MealType.dinner:
          return const Color(0xFF2196F3); // blue
        case MealType.snack:
          return const Color(0xFF9C27B0); // purple
      }
    }

    String mealEmojiFor(MealType type) {
      switch (type) {
        case MealType.breakfast:
          return '🌅';
        case MealType.lunch:
          return '☀️';
        case MealType.dinner:
          return '🌙';
        case MealType.snack:
          return '🍎';
      }
    }

    final meal = _effectiveMealType;
    final mealColor = mealColorFor(meal);
    final mealEmoji = mealEmojiFor(meal);
    final mealLabel = meal.label;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Row 1: back | meal chip | new food chip ──────────────────────
          Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  try {
                    Navigator.of(context, rootNavigator: false).pop();
                  } catch (e) {
                    Navigator.of(context).pop();
                  }
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Meal type chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: mealColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: mealColor.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mealEmoji, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      mealLabel,
                      style: GoogleFonts.inter(
                        color: mealColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),

          // ── Row 2: Search bar with barcode + AI + clear ───────────────────
          ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) {
              return Container(
                height: 50,
                decoration: BoxDecoration(
                  color: _isAISearch
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAISearch
                        ? AppColors.primary.withValues(alpha: 0.40)
                        : Colors.white.withValues(alpha: 0.10),
                    width: _isAISearch ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(
                      _isAISearch
                          ? Icons.psychology_rounded
                          : Icons.search_rounded,
                      color: _isAISearch
                          ? AppColors.primary
                          : AppColors.textTertiary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => _query.value = v,
                        autofocus: true,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: _isAISearch
                              ? 'Örn: 1 yumurta ve yarım simit'
                              : 'Yulaf, Yumurta, Elma...',
                          hintStyle: TextStyle(
                            color: _isAISearch
                                ? AppColors.primary.withValues(alpha: 0.50)
                                : AppColors.textTertiary,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),


                    // AI toggle
                    GestureDetector(
                      onTap: () async {
                        if (!_backendReady) {
                          _showOfflineWarning(context);
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        final canMakeRequest = await AiSafetyHelper.instance
                            .canMakeRequest();
                        if (!mounted) return;

                        if (!canMakeRequest) {
                          final remaining =
                              await AiSafetyHelper.instance.remainingRequests;
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Günlük AI istek limiti ($remaining kaldı) doldu. Yarın tekrar dene.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        setState(() => _isAISearch = !_isAISearch);
                        if (_query.value.isNotEmpty) _search();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: _isAISearch && _backendReady
                                ? AppColors.primary
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: !_backendReady
                                ? Colors.white.withValues(alpha: 0.20)
                                : (_isAISearch
                                      ? Colors.white
                                      : AppColors.textTertiary),
                            size: 18,
                          ),
                        ),
                      ),
                    ),

                    // Clear button
                    if (query.isNotEmpty) ...[
                      if (_isSearchPending || _loading) ...[
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isAISearch
                                  ? AppColors.primaryLight
                                  : Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 2),
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _query.value = '';
                        },
                        child: Icon(
                          Icons.close_rounded,
                          color: AppColors.textTertiary,
                          size: 18,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildQuickActionsRow(context),
          const SizedBox(height: 10),
          ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) {
              if (query.trim().isEmpty || (!_isSearchPending && !_loading)) {
                return const SizedBox.shrink();
              }

              final statusText = _loading
                  ? 'Aranıyor...'
                  : 'Arama hazırlanıyor...';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isAISearch
                                  ? AppColors.primaryLight
                                  : Colors.white.withValues(alpha: 0.80),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.80),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Row 3: quick suggestions OR internet search switch ────────────
          ValueListenableBuilder<String>(
            valueListenable: _query,
            builder: (context, query, _) {
              return Consumer<DietProvider>(
                builder: (context, provider, _) {
                  if (query.isEmpty && !provider.useRemoteSearch) {
                    return _buildQuickSuggestions();
                  }
                  // Show internet search switch when there's a query or remote is on
                  if (query.isNotEmpty || provider.useRemoteSearch) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Etiket verisi',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.60),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 24,
                          child: Switch(
                            value: provider.useRemoteSearch,
                            onChanged: (v) {
                              provider.setUseRemoteSearch(v);
                              _search();
                            },
                            activeThumbColor: AppColors.primary,
                            activeTrackColor: AppColors.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return _buildQuickSuggestions();
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSuggestions() {
    // emoji, label — Türkiye'ye özgü sık tüketilen gıdalar
    const suggestions = [
      ('🥨', 'Simit'),
      ('🧀', 'Beyaz Peynir'),
      ('🫒', 'Zeytin'),
      ('🥚', 'Yumurta'),
      ('☕', 'Çay'),
      ('🥛', 'Ayran'),
      ('🍗', 'Tavuk'),
      ('🌾', 'Bulgur'),
      ('🍲', 'Mercimek'),
      ('🥩', 'Köfte'),
      ('🍚', 'Pilav'),
      ('🍌', 'Muz'),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (emoji, label) = suggestions[index];
          return GestureDetector(
            onTap: () {
              _searchController.text = label;
              _query.value = label;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isQueryEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isQueryEmpty ? Icons.search_rounded : Icons.inbox_rounded,
              size: 72,
              color: AppColors.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              isQueryEmpty ? 'Aramaya başla' : 'Sonuç bulunamadı',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isQueryEmpty
                  ? 'Yukarıya yemek adı yaz veya hızlı önerilere tıkla'
                  : 'Bu arama için kayıt yok. Farklı bir kelime dene veya özel yemek ekle.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBarcodeScan(BuildContext context) async {
    final currentContext = context;
    try {
      final food = await Navigator.push(
        currentContext,
        MaterialPageRoute(
          builder: (_) => BarcodeScanPage(
            initialMealType: widget.selectedMealType ?? MealType.snack,
          ),
        ),
      );
      if (!currentContext.mounted) return;
      if (food != null) {
        Navigator.of(currentContext, rootNavigator: false)
            .pushNamed(
              'portion',
              arguments: {'food': food, 'mealType': widget.selectedMealType},
            )
            .then((_) {
              if (!currentContext.mounted) return;
              Navigator.of(currentContext, rootNavigator: false).pop();
            });
      }
    } catch (e) {
      debugPrint('Barcode scan error: $e');
    }
  }

  void _showOfflineWarning(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Backend bağlantısı yok. AI özellikleri kullanılamıyor.\nNormal arama ve barkod tarama çalışmaya devam eder.',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange.shade800,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildActionChip(
            label: 'Barkod Okut',
            icon: Icons.qr_code_scanner_rounded,
            color: Colors.white,
            onTap: () => _handleBarcodeScan(context),
          ),
          const SizedBox(width: 8),
          _buildActionChip(
            label: 'Hızlı Kalori',
            icon: Icons.bolt_rounded,
            color: Colors.orange,
            onTap: () => _showQuickAddDialog(context),
          ),
          const SizedBox(width: 8),
          _buildActionChip(
            label: 'Özel Besin Ekle',
            icon: Icons.add_rounded,
            color: AppColors.primaryLight,
            onTap: () async {
              try {
                final added = await Navigator.of(context, rootNavigator: false).pushNamed<bool>('add_custom_food');
                if (added == true && mounted) _search();
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AddCustomFoodPage()));
              }
            },
          ),
          const SizedBox(width: 8),
          _buildActionChip(
            label: _isMultiAddMode ? 'İptal Et' : 'Çoklu Ekleme',
            icon: _isMultiAddMode ? Icons.close_rounded : Icons.checklist_rounded,
            color: const Color(0xFF4CD1A3),
            onTap: () {
              setState(() {
                _isMultiAddMode = !_isMultiAddMode;
                if (!_isMultiAddMode) _selectedFoods.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final kcalController = TextEditingController();
        final nameController = TextEditingController();
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Hızlı Kalori Ekle', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'İsim (Opsiyonel)',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: kcalController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Kalori (kcal)',
                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  suffixText: 'kcal',
                  suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (kcalController.text.trim().isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hızlı kalori eklendi (Demo)')));
                }
                Navigator.pop(context);
              },
              child: const Text('Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      }
    );
  }

  Widget _buildMultiAddFab() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            if (_selectedFoods.isEmpty) return;
            setState(() {
              _isMultiAddMode = false;
              _selectedFoods.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seçilen öğeler eklendi (Demo)')));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_selectedFoods.length} Ürün Seçildi',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'Hepsini Ekle',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// _FoodListTile — compact ~76px row card (no BackdropFilter)
// =============================================================================
class _FoodListTile extends StatefulWidget {
  final FoodItem food;
  final MealType? selectedMealType;
  final VoidCallback onTap;
  final VoidCallback onAddTap;
  final void Function(double grams) onQuickAdd;

  const _FoodListTile({
    required this.food,
    required this.selectedMealType,
    required this.onTap,
    required this.onAddTap,
    required this.onQuickAdd,
  });

  @override
  State<_FoodListTile> createState() => _FoodListTileState();
}

class _FoodListTileState extends State<_FoodListTile> {
  /// Returns a stable color based on the category string.
  static Color _categoryColor(String category) {
    const palette = [
      Color(0xFF5B9BFF),
      Color(0xFF4CD1A3),
      Color(0xFFFF8A65),
      Color(0xFFCE93D8),
      Color(0xFF80DEEA),
      Color(0xFFFFB74D),
      Color(0xFFEF9A9A),
      Color(0xFFA5D6A7),
    ];
    final hash = category.codeUnits.fold(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  bool _isFav = false;

  @override
  void initState() {
    super.initState();
    _isFav = StorageHelper.isFavorite(widget.food.id);
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionsSheet(
        food: widget.food,
        isFav: _isFav,
        onFavToggled: () {
          setState(() => _isFav = !_isFav);
        },
        onQuickAdd: widget.onQuickAdd,
        onOpenDetail: widget.onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kcal = widget.food.kcalPer100g;
    final p = widget.food.proteinPer100g;
    final c = widget.food.carbPer100g;
    final f = widget.food.fatPer100g;
    final displayName = _foodDisplayName(widget.food);

    // Smart badge — max 1
    String? badge;
    Color? badgeColor;
    final hasVerifiedData = _isVerifiedFoodData(widget.food);

    if (p >= 20) {
      badge = 'Yüksek Protein';
      badgeColor = const Color(0xFF5B9BFF);
    } else if (f < 3) {
      badge = 'Düşük Yağ';
      badgeColor = const Color(0xFF8BC34A);
    } else if (kcal < 50) {
      badge = 'Hafif';
      badgeColor = Colors.white54;
    }

    final accent = _categoryColor(widget.food.category);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: () => _showOptions(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── ÜST ALAN: Kcal dairesi + isim/detay ──────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Kcal dairesi
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.10),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${kcal.round()}',
                              style: GoogleFonts.inter(
                                color: AppColors.secondary,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'kcal',
                              style: TextStyle(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.65,
                                ),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Sağ: isim + kategori + badge
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                if (_isFav)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 6),
                                    child: Icon(
                                      Icons.favorite_rounded,
                                      size: 13,
                                      color: Color(0xFFFF6B8A),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: accent.withValues(alpha: 0.28),
                                    ),
                                  ),
                                  child: Text(
                                    widget.food.category,
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (hasVerifiedData)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4CD1A3,
                                      ).withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF4CD1A3,
                                        ).withValues(alpha: 0.24),
                                      ),
                                    ),
                                    child: Text(
                                      _foodSourceLabel(widget.food),
                                      style: const TextStyle(
                                        color: Color(0xFF4CD1A3),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (badge != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: badgeColor!.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      badge,
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── AYRAÇ ────────────────────────────────────────
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.08),
                ),

                // ── ALT ALAN: Makro grid + Ekle butonu ───────────
                SizedBox(
                  height: 52,
                  child: Row(
                    children: [
                      _macroCol('Protein', p, const Color(0xFF5B9BFF)),
                      _vSep(),
                      _macroCol('Karb', c, const Color(0xFF4CD1A3)),
                      _vSep(),
                      _macroCol('Yağ', f, const Color(0xFFFFB74D)),
                      _vSep(),

                      // Ekle butonu
                      GestureDetector(
                        onTap: widget.onAddTap,
                        child: SizedBox(
                          width: 64,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_rounded,
                                size: 20,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Ekle',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _macroCol(String label, double g, Color color) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '${g.round()}g',
          style: GoogleFonts.inter(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _vSep() => Container(
    width: 1,
    height: 28,
    color: Colors.white.withValues(alpha: 0.10),
  );
}

// =============================================================================
// _OptionsSheet — long-press bottom sheet with quick actions
// =============================================================================
class _OptionsSheet extends StatefulWidget {
  final FoodItem food;
  final bool isFav;
  final VoidCallback onFavToggled;
  final void Function(double grams) onQuickAdd;
  final VoidCallback onOpenDetail;

  const _OptionsSheet({
    required this.food,
    required this.isFav,
    required this.onFavToggled,
    required this.onQuickAdd,
    required this.onOpenDetail,
  });

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late bool _isFav;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFav;
  }

  double get _defaultQuickAddGrams =>
      DietProvider.getDefaultPortionForFood(widget.food);

  double get _secondaryQuickAddGrams {
    final base = _defaultQuickAddGrams;
    if (base <= 80) return base * 2;
    if (base <= 160) return base * 1.5;
    return base * 2;
  }

  String _quickAddLabel(double grams) {
    final normalizedServings = widget.food.servings
        .where((item) => item.isDefault)
        .toList();
    final serving = normalizedServings.isNotEmpty
        ? normalizedServings.first
        : (widget.food.servings.isNotEmpty ? widget.food.servings.first : null);

    if (serving != null && (serving.grams - grams).abs() < 1) {
      return 'Hızlı Ekle — ${serving.label}';
    }

    final unit = DietProvider.getSmartUnit(
      widget.food.name,
      widget.food.category,
    );
    final count =
        grams / (_defaultQuickAddGrams > 0 ? _defaultQuickAddGrams : 100);
    final countStr = count == 1.0
        ? '1'
        : (count == 0.5
              ? 'Yarım'
              : count
                    .toStringAsFixed(1)
                    .replaceAll('.0', '')
                    .replaceAll('.', ','));

    return 'Hızlı Ekle — $countStr $unit (${grams.round()}g)';
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String label,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.30)),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.58),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.38),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip({
    required String text,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kcal = widget.food.kcalPer100g;
    final p = widget.food.proteinPer100g;
    final c = widget.food.carbPer100g;
    final f = widget.food.fatPer100g;
    final displayName = _foodDisplayName(widget.food);
    final quickAddGrams = _defaultQuickAddGrams;
    final secondQuickAddGrams = _secondaryQuickAddGrams;
    final media = MediaQuery.of(context);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.78),
        padding: EdgeInsets.fromLTRB(20, 16, 20, media.padding.bottom + 16),
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _infoChip(
                              text: '${kcal.round()} kcal',
                              color: const Color(0xFFFFB067),
                              icon: Icons.local_fire_department_rounded,
                            ),
                            _infoChip(
                              text: 'P:${p.round()}g',
                              color: AppColors.secondary,
                            ),
                            _infoChip(
                              text: 'K:${c.round()}g',
                              color: AppColors.chartGreen,
                            ),
                            _infoChip(
                              text: 'Y:${f.round()}g',
                              color: const Color(0xFFFFC857),
                            ),
                            _infoChip(text: '100g baz', color: Colors.white70),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _actionTile(
                icon: Icons.restaurant_rounded,
                color: AppColors.secondary,
                label: 'Porsiyon Seç & Ekle',
                subtitle: 'Gram veya porsiyon miktarı gir',
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpenDetail();
                },
              ),
              _actionTile(
                icon: Icons.flash_on_rounded,
                color: AppColors.chartGreen,
                label: _quickAddLabel(quickAddGrams),
                subtitle:
                    '${(kcal * (quickAddGrams / 100)).round()} kcal · P:${(p * (quickAddGrams / 100)).round()}g',
                onTap: () {
                  Navigator.pop(context);
                  widget.onQuickAdd(quickAddGrams);
                },
              ),
              _actionTile(
                icon: Icons.flash_on_rounded,
                color: const Color(0xFF43E97B),
                label: _quickAddLabel(secondQuickAddGrams),
                subtitle:
                    '${(kcal * (secondQuickAddGrams / 100)).round()} kcal · P:${(p * (secondQuickAddGrams / 100)).round()}g',
                onTap: () {
                  Navigator.pop(context);
                  widget.onQuickAdd(secondQuickAddGrams);
                },
              ),
              _actionTile(
                icon: _isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: const Color(0xFFFF6B6B),
                label: _isFav ? 'Favorilerden Çıkar' : 'Favorilere Ekle',
                subtitle: _isFav
                    ? 'Tek dokunuşla favorilerden kaldır'
                    : 'Bu besini daha sonra hızlıca bul',
                onTap: () async {
                  await StorageHelper.toggleFavorite(widget.food.id);
                  setState(() => _isFav = !_isFav);
                  widget.onFavToggled();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
