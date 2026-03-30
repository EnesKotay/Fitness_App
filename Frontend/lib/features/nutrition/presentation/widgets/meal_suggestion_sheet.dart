import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

void showMealSuggestionSheet(BuildContext context) {
  NavigatorState? tabNav;
  try {
    tabNav = Navigator.of(context, rootNavigator: false);
  } catch (_) {}

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MealSuggestionPage(tabNavigator: tabNav),
      fullscreenDialog: true,
    ),
  );
}

class MealSuggestionPage extends StatelessWidget {
  final NavigatorState? tabNavigator;
  const MealSuggestionPage({super.key, this.tabNavigator});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0C10),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0A0C10).withValues(alpha: 0.92),
                    const Color(0xFF0A0C10).withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          AppColors.primaryLight,
                          AppColors.chartGreen,
                        ],
                      ).createShader(bounds),
                      child: const Text(
                        'AI Öğün Önerisi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.3),
                            AppColors.chartGreen.withValues(alpha: 0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Text(
                        'BETA',
                        style: TextStyle(
                          color: AppColors.primaryLight,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: _MealSuggestionContent(tabNavigator: tabNavigator),
    );
  }
}

enum _SuggestionRefinement { smart, filling, quick, budget, homeStyle }

class _MealComboPlan {
  final String title;
  final String subtitle;
  final String reason;
  final IconData icon;
  final List<SuggestedFoodInsight> items;

  const _MealComboPlan({
    required this.title,
    required this.subtitle,
    required this.reason,
    required this.icon,
    required this.items,
  });

  double get totalKcal => items.fold(
    0,
    (sum, item) =>
        sum + ((item.item.kcalPer100g * item.suggestedPortionG) / 100),
  );

  double get totalProtein => items.fold(
    0,
    (sum, item) =>
        sum + ((item.item.proteinPer100g * item.suggestedPortionG) / 100),
  );

  int get prepMinutes => items.fold<int>(
    0,
    (sum, item) => sum + _MealSuggestionHeuristics.prepMinutes(item.item),
  );
}

class _MealSuggestionHeuristics {
  static final Set<String> _quickTokens = {
    'yoğurt',
    'yogurt',
    'peynir',
    'meyve',
    'muz',
    'elma',
    'yumurta',
    'omlet',
    'yulaf',
    'ayran',
    'salata',
    'çorba',
    'corba',
    'simit',
  };

  static final Set<String> _budgetTokens = {
    'mercimek',
    'nohut',
    'fasulye',
    'pilav',
    'makarna',
    'yulaf',
    'yumurta',
    'çorba',
    'corba',
    'yoğurt',
    'yogurt',
    'peynir',
    'bulgur',
  };

  static final Set<String> _premiumTokens = {
    'biftek',
    'antrikot',
    'kebap',
    'cağ',
    'cag',
    'balık',
    'somon',
    'karides',
    'böryan',
    'buryan',
  };

  static bool _contains(FoodItem food, Set<String> tokens) {
    final haystack = '${food.name} ${food.category} ${food.tags.join(' ')}'
        .toLowerCase();
    return tokens.any(haystack.contains);
  }

  static int prepMinutes(FoodItem food) {
    if (_contains(food, _quickTokens)) {
      return 5;
    }
    if (food.category.contains('Çorba') || food.category.contains('Kahvaltı')) {
      return 10;
    }
    if (food.category.contains('Pilav') || food.category.contains('Makarna')) {
      return 18;
    }
    if (food.category.contains('Et') ||
        food.category.contains('Tavuk') ||
        food.category.contains('Balık')) {
      return 20;
    }
    if (food.category.contains('Hamur')) return 22;
    return 12;
  }

  static String prepLabel(FoodItem food) {
    final minutes = prepMinutes(food);
    if (minutes <= 5) return 'Hemen hazır';
    if (minutes <= 10) return '10 dk';
    if (minutes <= 15) return '15 dk';
    return '$minutes dk';
  }

  static String costLabel(FoodItem food) {
    if (_contains(food, _budgetTokens)) return 'Bütçe dostu';
    if (_contains(food, _premiumTokens)) return 'Daha maliyetli';
    return 'Orta bütçe';
  }

  static String practicalityLabel(FoodItem food) {
    final minutes = prepMinutes(food);
    if (minutes <= 5) return 'Çok pratik';
    if (minutes <= 10) return 'Pratik';
    if (minutes <= 18) return 'Ev tipi';
    return 'Hazırlık ister';
  }

  static String bestUseLabel(FoodItem food, MealType mealType) {
    if (food.proteinPer100g >= 20) return 'Protein odağı';
    if (food.kcalPer100g <= 120) return 'Hafif seçenek';
    if (mealType == MealType.breakfast) return 'Güne başlangıç';
    if (mealType == MealType.snack) return 'Ara öğün uyumlu';
    return 'Dengeli öğün';
  }

  static bool isBudgetFriendly(FoodItem food) => _contains(food, _budgetTokens);
  static bool isQuick(FoodItem food) => prepMinutes(food) <= 10;
  static bool isHomeStyle(FoodItem food) =>
      food.category.contains('Yemek') ||
      food.category.contains('Çorba') ||
      food.category.contains('Sebze') ||
      food.category.contains('Pilav');
  static bool isFilling(FoodItem food) =>
      food.proteinPer100g >= 12 ||
      food.carbPer100g >= 18 ||
      food.fatPer100g >= 8;
}

// ─── State ───────────────────────────────────────────────────────────────────

class _MealSuggestionContent extends StatefulWidget {
  final NavigatorState? tabNavigator;
  const _MealSuggestionContent({this.tabNavigator});

  @override
  State<_MealSuggestionContent> createState() => _MealSuggestionContentState();
}

class _MealSuggestionContentState extends State<_MealSuggestionContent>
    with SingleTickerProviderStateMixin {
  MealType _mealType = MealType.lunch;
  List<SuggestedFoodInsight> _suggestions = [];
  String? _aiReasoning;
  bool _loading = true;
  bool _refreshingReasoning = false;
  bool _reasoningExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _SuggestionRefinement _refinement = _SuggestionRefinement.smart;
  final Set<String> _mutedTokens = <String>{};
  static const _debounceMs = 400;

  // Porsiyon
  FoodItem? _selectedFood;
  double _adjustmentGrams = 100.0;
  bool _showRecipe = false;

  // Hızlı ekle
  String? _quickAddedId;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _detectCurrentMealTime();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _detectCurrentMealTime() {
    final hour = DateTime.now().hour;
    if (hour < 10) {
      _mealType = MealType.breakfast;
    } else if (hour < 14) {
      _mealType = MealType.lunch;
    } else if (hour < 18) {
      _mealType = MealType.snack;
    } else {
      _mealType = MealType.dinner;
    }
  }

  Future<void> _load() async {
    _fadeCtrl.reset();
    setState(() => _loading = true);
    final provider = Provider.of<DietProvider>(context, listen: false);
    final query = _searchQuery.trim().isEmpty ? null : _searchQuery.trim();
    final list = await provider.getSuggestedFoodInsights(
      _mealType,
      limit: query != null ? 80 : 60,
      query: query,
    );
    final reasoning = await provider.getAISuggestionReasoning(
      list.map((e) => e.item).toList(),
    );
    if (mounted) {
      setState(() {
        _suggestions = list;
        _aiReasoning = reasoning;
        _loading = false;
      });
      _fadeCtrl.forward();
    }
  }

  Future<void> _refreshReasoning() async {
    if (_refreshingReasoning || _suggestions.isEmpty) return;
    setState(() => _refreshingReasoning = true);
    final provider = Provider.of<DietProvider>(context, listen: false);
    final reasoning = await provider.getAISuggestionReasoning(
      _suggestions.map((e) => e.item).toList(),
    );
    if (mounted) {
      setState(() {
        _aiReasoning = reasoning;
        _refreshingReasoning = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    final trimmed = value.trim();
    Future.delayed(const Duration(milliseconds: _debounceMs), () {
      if (!mounted) return;
      if (_searchQuery.trim() != trimmed) return;
      _load();
    });
  }

  void _setRefinement(_SuggestionRefinement refinement) {
    HapticFeedback.selectionClick();
    setState(() => _refinement = refinement);
  }

  void _muteKeyword(String token) {
    HapticFeedback.lightImpact();
    setState(() {
      _mutedTokens.add(token.toLowerCase());
    });
  }

  void _clearMutedKeywords() {
    if (_mutedTokens.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(_mutedTokens.clear);
  }

  Future<void> _quickAddCombo(
    _MealComboPlan combo,
    DietProvider provider,
  ) async {
    HapticFeedback.mediumImpact();
    for (final item in combo.items) {
      await provider.addEntry(
        food: item.item,
        grams: item.suggestedPortionG,
        mealType: _mealType,
        date: provider.selectedDate,
      );
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${combo.title} öğüne eklendi',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  Future<void> _quickAdd(
    SuggestedFoodInsight suggestion,
    DietProvider provider,
  ) async {
    if (_quickAddedId != null) return;
    HapticFeedback.lightImpact();
    setState(() => _quickAddedId = suggestion.item.id);
    await provider.addEntry(
      food: suggestion.item,
      grams: suggestion.suggestedPortionG,
      mealType: _mealType,
      date: provider.selectedDate,
    );
    if (mounted) {
      setState(() => _quickAddedId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${suggestion.item.name} eklendi (${suggestion.suggestedPortionG.round()}g)',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  void _openPortionOverlay(SuggestedFoodInsight suggestion) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedFood = suggestion.item;
      _adjustmentGrams = suggestion.suggestedPortionG;
      _showRecipe = false;
    });
  }

  Color _scoreColor(double score) {
    if (score >= 70) return AppColors.chartGreen;
    if (score >= 45) return AppColors.secondary;
    return Colors.white38;
  }

  List<({String label, Color color})> _badges(FoodItem food) {
    final badges = <({String label, Color color})>[];
    if (food.proteinPer100g >= 20) {
      badges.add((label: 'Yüksek Protein', color: AppColors.chartBlue));
    }
    if (food.carbPer100g < 5) {
      badges.add((label: 'Düşük Karb', color: AppColors.chartGreen));
    }
    if (food.fatPer100g < 3) {
      badges.add((label: 'Düşük Yağ', color: const Color(0xFF8BC34A)));
    }
    if (food.kcalPer100g < 50) {
      badges.add((label: 'Hafif', color: Colors.white60));
    }
    if (badges.isEmpty &&
        food.proteinPer100g >= 12 &&
        food.carbPer100g < 30 &&
        food.fatPer100g < 15) {
      badges.add((label: 'Dengeli', color: AppColors.chartGreen));
    }
    return badges.take(2).toList();
  }

  String _mealTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 'Günaydın ☀️  Kahvaltı zamanı';
    if (hour < 14) return 'Öğle yemeği zamanı 🍽️';
    if (hour < 18) return 'Atıştırma molası 🥗';
    return 'Akşam yemeği zamanı 🌙';
  }

  String _mealTypeLabel(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return 'Kahvaltı';
      case MealType.lunch:
        return 'Öğle';
      case MealType.dinner:
        return 'Akşam';
      case MealType.snack:
        return 'Atıştırma';
    }
  }

  String _suggestionModeLabel(SuggestionMode mode) {
    switch (mode) {
      case SuggestionMode.balanced:
        return 'Dengeli';
      case SuggestionMode.highProtein:
        return 'Yüksek protein';
      case SuggestionMode.lowCarb:
        return 'Düşük karb';
    }
  }

  List<String> _priorityMessages({
    required int remKcal,
    required int remP,
    required int remC,
    required int remF,
    required SuggestionMode mode,
  }) {
    final items = <String>[];
    if (remP >= remC && remP >= remF && remP > 0) {
      items.add('Protein açığın önde, bunu kapatan seçenekler öne çıktı.');
    }
    if (remKcal > 0) {
      items.add(
        '$remKcal kcal hedefin kaldı, porsiyonlar buna göre ayarlandı.',
      );
    }
    if (mode == SuggestionMode.highProtein) {
      items.add(
        'Yüksek protein modu aktif, kas korumaya uygun öneriler seçildi.',
      );
    } else if (mode == SuggestionMode.lowCarb) {
      items.add(
        'Düşük karbonhidrat modu aktif, daha hafif seçenekler öne çıktı.',
      );
    } else {
      items.add('Makro dengesini bozmadan günü tamamlaman hedefleniyor.');
    }
    if (_searchQuery.trim().isNotEmpty) {
      items.add(
        '"${_searchQuery.trim()}" aramasıyla eşleşen öğeler filtrelendi.',
      );
    } else {
      items.add(
        '${_mealTypeLabel(_mealType)} için en uygun eşleşmeler sıralandı.',
      );
    }
    return items.take(3).toList();
  }

  List<String> _insightHighlights() {
    final highlights = <String>{};
    for (final suggestion in _suggestions.take(6)) {
      for (final reason in suggestion.reasons.take(2)) {
        final cleaned = reason.trim();
        if (cleaned.isNotEmpty) {
          highlights.add(cleaned);
        }
        if (highlights.length >= 4) return highlights.toList();
      }
    }
    return highlights.toList();
  }

  bool _matchesMutedKeywords(FoodItem food) {
    if (_mutedTokens.isEmpty) return true;
    final haystack = '${food.name} ${food.category} ${food.tags.join(' ')}'
        .toLowerCase();
    for (final token in _mutedTokens) {
      if (haystack.contains(token)) return false;
    }
    return true;
  }

  List<SuggestedFoodInsight> _applyRefinement(
    List<SuggestedFoodInsight> source,
  ) {
    final filtered = source.where((item) {
      if (!_matchesMutedKeywords(item.item)) return false;
      switch (_refinement) {
        case _SuggestionRefinement.smart:
          return true;
        case _SuggestionRefinement.filling:
          return _MealSuggestionHeuristics.isFilling(item.item);
        case _SuggestionRefinement.quick:
          return _MealSuggestionHeuristics.isQuick(item.item);
        case _SuggestionRefinement.budget:
          return _MealSuggestionHeuristics.isBudgetFriendly(item.item);
        case _SuggestionRefinement.homeStyle:
          return _MealSuggestionHeuristics.isHomeStyle(item.item);
      }
    }).toList();

    filtered.sort((a, b) {
      int bonus(SuggestedFoodInsight item) {
        switch (_refinement) {
          case _SuggestionRefinement.smart:
            return 0;
          case _SuggestionRefinement.filling:
            return ((item.item.proteinPer100g * 2) +
                    item.item.carbPer100g +
                    (item.item.fatPer100g * 1.2))
                .round();
          case _SuggestionRefinement.quick:
            return -_MealSuggestionHeuristics.prepMinutes(item.item);
          case _SuggestionRefinement.budget:
            return _MealSuggestionHeuristics.isBudgetFriendly(item.item)
                ? 30
                : 0;
          case _SuggestionRefinement.homeStyle:
            return _MealSuggestionHeuristics.isHomeStyle(item.item) ? 25 : 0;
        }
      }

      return (b.score + bonus(b)).compareTo(a.score + bonus(a));
    });

    return filtered;
  }

  List<String> _dislikeSuggestions(List<SuggestedFoodInsight> suggestions) {
    final tokens = <String>{};
    for (final suggestion in suggestions.take(8)) {
      final words = suggestion.item.name
          .split(RegExp(r'[\s\(\),-]+'))
          .map((word) => word.trim().toLowerCase())
          .where((word) => word.length >= 4)
          .where(
            (word) => !{'ve', 'ile', 'sade', 'tane', 'adet'}.contains(word),
          );
      for (final word in words) {
        tokens.add(word);
        if (tokens.length >= 6) return tokens.toList();
      }
    }
    return tokens.toList();
  }

  List<_MealComboPlan> _buildComboPlans(List<SuggestedFoodInsight> visible) {
    if (visible.length < 2) return const [];

    final used = <String>{};

    // Finds the first unused item (not in `used`) matching the test.
    // Optionally excludes one extra id (useful when the other pair item is not yet added to `used`).
    SuggestedFoodInsight? pick(
      bool Function(SuggestedFoodInsight) test, [
      String? alsoExclude,
    ]) {
      for (final item in visible) {
        if (used.contains(item.item.id)) continue;
        if (alsoExclude != null && item.item.id == alsoExclude) continue;
        if (test(item)) return item;
      }
      return null;
    }

    final combos = <_MealComboPlan>[];

    if (_mealType == MealType.breakfast) {
      // 1. Protein + karbonhidrat
      final p = pick((i) => i.item.proteinPer100g >= 12);
      final c = pick((i) => i.item.carbPer100g >= 18, p?.item.id);
      if (p != null && c != null) {
        combos.add(_MealComboPlan(
          title: 'Güne sağlam başlangıç',
          subtitle: '${p.item.name} + ${c.item.name}',
          reason: 'Protein ve karbonhidratı dengeleyen klasik kahvaltı.',
          icon: Icons.wb_sunny_rounded,
          items: [p, c],
        ));
        used.addAll([p.item.id, c.item.id]);
      }
      // 2. Süt ürünü + hafif seçenek
      final d = pick((i) => i.item.category.contains('Süt'));
      final f = pick((i) => i.item.kcalPer100g <= 90, d?.item.id);
      if (d != null && f != null) {
        combos.add(_MealComboPlan(
          title: 'Hafif ve taze başlangıç',
          subtitle: '${d.item.name} + ${f.item.name}',
          reason: 'Sindirimi kolay, güne ferah başlamak için.',
          icon: Icons.breakfast_dining_rounded,
          items: [d, f],
        ));
        used.addAll([d.item.id, f.item.id]);
      }
      // 3. Yüksek protein seçenek
      final hp = pick((i) => i.item.proteinPer100g >= 18);
      final s = pick((i) => i.item.kcalPer100g <= 160, hp?.item.id);
      if (hp != null && s != null) {
        combos.add(_MealComboPlan(
          title: 'Protein odaklı kahvaltı',
          subtitle: '${hp.item.name} + ${s.item.name}',
          reason: 'Sabah protein ihtiyacını erken karşılar, güne güçlü başlatır.',
          icon: Icons.fitness_center_rounded,
          items: [hp, s],
        ));
      }
    } else if (_mealType == MealType.snack) {
      // 1. Protein + meyve / hafif
      final p = pick((i) => i.item.proteinPer100g >= 8);
      final f = pick(
        (i) => i.item.category.contains('Meyve') || i.item.kcalPer100g <= 70,
        p?.item.id,
      );
      if (p != null && f != null) {
        combos.add(_MealComboPlan(
          title: 'Enerji atıştırması',
          subtitle: '${p.item.name} + ${f.item.name}',
          reason: 'Protein ve doğal şeker — öğünler arası en akıllı seçim.',
          icon: Icons.bolt_rounded,
          items: [p, f],
        ));
        used.addAll([p.item.id, f.item.id]);
      }
      // 2. Süt ürünü + hafif
      final d = pick((i) => i.item.category.contains('Süt'));
      final l = pick((i) => i.item.kcalPer100g <= 100, d?.item.id);
      if (d != null && l != null) {
        combos.add(_MealComboPlan(
          title: 'Hafif mola',
          subtitle: '${d.item.name} + ${l.item.name}',
          reason: 'Doyurucu ama hafif, öğünleri dengelemek için ideal.',
          icon: Icons.spa_rounded,
          items: [d, l],
        ));
      }
    } else {
      // Öğle / Akşam

      // 1. Tam öğün: çorba/sebze/salata + protein + karbonhidrat (3 item)
      final anchor = pick((i) =>
          i.item.category.contains('Çorba') ||
          i.item.category.contains('Sebze') ||
          i.item.category.contains('Salata'));
      final mainP = pick(
        (i) => i.item.proteinPer100g >= 14 && i.item.id != anchor?.item.id,
        anchor?.item.id,
      );
      final mainC = pick(
        (i) =>
            i.item.carbPer100g >= 15 &&
            i.item.proteinPer100g < 14 &&
            i.item.id != anchor?.item.id &&
            i.item.id != mainP?.item.id,
        mainP?.item.id,
      );

      if (anchor != null && mainP != null && mainC != null) {
        combos.add(_MealComboPlan(
          title: _mealType == MealType.lunch ? 'Dolu öğle tabağı' : 'Dolu akşam tabağı',
          subtitle: '${anchor.item.name} · ${mainP.item.name} · ${mainC.item.name}',
          reason: anchor.item.category.contains('Çorba')
              ? 'Çorba + ana protein + enerji — eksiksiz bir öğün.'
              : 'Sebze + protein + karbonhidrat dengesi.',
          icon: Icons.dinner_dining_rounded,
          items: [anchor, mainP, mainC],
        ));
        used.addAll([anchor.item.id, mainP.item.id, mainC.item.id]);
      } else if (mainP != null && mainC != null) {
        combos.add(_MealComboPlan(
          title: _mealType == MealType.lunch ? 'Dengeli öğle' : 'Dengeli akşam',
          subtitle: '${mainP.item.name} + ${mainC.item.name}',
          reason: 'Protein ve enerjiyi tek öğünde dengeler.',
          icon: Icons.dinner_dining_rounded,
          items: [mainP, mainC],
        ));
        used.addAll([mainP.item.id, mainC.item.id]);
      }

      // 2. Hafif ama tok tutar
      final p2 = pick((i) => i.item.proteinPer100g >= 12);
      final l2 = pick(
        (i) =>
            (i.item.kcalPer100g <= 130 ||
                i.item.category.contains('Salata') ||
                i.item.category.contains('Çorba')) &&
            i.item.id != p2?.item.id,
        p2?.item.id,
      );
      if (p2 != null && l2 != null) {
        combos.add(_MealComboPlan(
          title: 'Hafif ama tok tutar',
          subtitle: '${p2.item.name} + ${l2.item.name}',
          reason: 'Protein odağını korurken kaloriyi kontrollü tutar.',
          icon: Icons.spa_rounded,
          items: [p2, l2],
        ));
        used.addAll([p2.item.id, l2.item.id]);
      }

      // 3. Pratik seçenek
      final q1 = pick((i) => _MealSuggestionHeuristics.isQuick(i.item));
      final q2 = pick(
        (i) => i.item.proteinPer100g >= 8 && i.item.id != q1?.item.id,
        q1?.item.id,
      );
      if (q1 != null && q2 != null) {
        combos.add(_MealComboPlan(
          title: 'Pratik seçenek',
          subtitle: '${q1.item.name} + ${q2.item.name}',
          reason: 'Hızlı hazırlanır, makro hedefini destekler.',
          icon: Icons.flash_on_rounded,
          items: [q1, q2],
        ));
      }
    }

    return combos.take(3).toList();
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DietProvider>(context);
    final targets = provider.macroTargets;
    final t = provider.totals;

    final remKcal = provider.remainingKcal.round();
    final remP = (targets.protein - t.totalProtein)
        .clamp(0.0, double.infinity)
        .round();
    final remC = (targets.carb - t.totalCarb)
        .clamp(0.0, double.infinity)
        .round();
    final remF = (targets.fat - t.totalFat).clamp(0.0, double.infinity).round();

    // Progress percentages (how much consumed out of target)
    final targetKcal = provider.effectiveTargetKcal;
    final pKcal = (targetKcal > 0 ? t.totalKcal / targetKcal : 0.0).clamp(
      0.0,
      1.0,
    );
    final pProt = (t.totalProtein / targets.protein).clamp(0.0, 1.0);
    final pCarb = (t.totalCarb / targets.carb).clamp(0.0, 1.0);
    final pFat = (t.totalFat / targets.fat).clamp(0.0, 1.0);

    final visibleSuggestions = _applyRefinement(_suggestions);
    final comboPlans = _buildComboPlans(visibleSuggestions);
    final dislikeSuggestions = _dislikeSuggestions(visibleSuggestions);
    final topPicks = visibleSuggestions.take(6).toList();
    final morePicks = visibleSuggestions.length > 6
        ? visibleSuggestions.skip(6).toList()
        : <SuggestedFoodInsight>[];

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: _buildMacroProgress(
                remKcal: remKcal,
                remP: remP,
                remC: remC,
                remF: remF,
                pKcal: pKcal,
                pProt: pProt,
                pCarb: pCarb,
                pFat: pFat,
              ),
            ),
            SliverToBoxAdapter(child: _buildControlPanel(provider)),
            if (_aiReasoning != null && _aiReasoning!.isNotEmpty && !_loading)
              SliverToBoxAdapter(child: _buildAICard(_aiReasoning!)),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _LoadingContent(),
              )
            else if (visibleSuggestions.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else ...[
              SliverToBoxAdapter(
                child: _buildRefinementBar(dislikeSuggestions),
              ),
              if (comboPlans.isNotEmpty)
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildComboSection(provider, comboPlans),
                  ),
                ),
              if (topPicks.isNotEmpty)
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildCarouselSection(
                      provider,
                      topPicks,
                      remP: remP,
                      remC: remC,
                      remF: remF,
                    ),
                  ),
                ),
              if (morePicks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionTitle('Diğer Uygun Seçenekler'),
                ),
                _buildFoodList(
                  provider,
                  morePicks,
                  remP: remP,
                  remC: remC,
                  remF: remF,
                ),
              ] else if (topPicks.isNotEmpty) ...[
                _buildFoodList(
                  provider,
                  topPicks,
                  remP: remP,
                  remC: remC,
                  remF: remF,
                ),
              ],
            ],
          ],
        ),
        if (_selectedFood != null) _buildPortionOverlay(provider),
      ],
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final provider = Provider.of<DietProvider>(context, listen: false);
    final searchActive = _searchQuery.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 72, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.22),
              const Color(0xFF1A2A1A).withValues(alpha: 0.85),
              const Color(0xFF0D1117),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.18),
              blurRadius: 32,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => LinearGradient(
                                colors: [
                                  Colors.white,
                                  AppColors.primaryLight,
                                ],
                              ).createShader(bounds),
                              child: const Text(
                                'Ne ekleyeyim?',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.0,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _mealTimeGreeting(),
                              style: TextStyle(
                                color: AppColors.primaryLight.withValues(alpha: 0.7),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _heroPill(
                        icon: Icons.schedule_rounded,
                        label: _mealTypeLabel(_mealType),
                        color: AppColors.primaryLight,
                      ),
                      _heroPill(
                        icon: Icons.tune_rounded,
                        label: _suggestionModeLabel(provider.suggestionMode),
                        color: AppColors.chartBlue,
                      ),
                      _heroPill(
                        icon: searchActive
                            ? Icons.search_rounded
                            : Icons.restaurant_menu_rounded,
                        label: searchActive ? 'Arama aktif' : 'Akıllı öneri',
                        color: searchActive
                            ? AppColors.secondary
                            : AppColors.chartGreen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kalan hedeflerine ve seçtiğin öğüne göre en mantıklı seçimleri öne çıkardım.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Macro Progress ──────────────────────────────────────────────────────

  Widget _buildMacroProgress({
    required int remKcal,
    required int remP,
    required int remC,
    required int remF,
    required double pKcal,
    required double pProt,
    required double pCarb,
    required double pFat,
  }) {
    final provider = Provider.of<DietProvider>(context, listen: false);
    final consumedKcal = provider.totals.totalKcal.round();
    final targetKcal = provider.effectiveTargetKcal.round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF111520),
              Color(0xFF0D1014),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top kcal header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kalan kalori hedefi',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.45),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$remKcal',
                              style: TextStyle(
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [
                                      AppColors.secondary,
                                      AppColors.secondaryLight,
                                    ],
                                  ).createShader(
                                    const Rect.fromLTWH(0, 0, 120, 40),
                                  ),
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.5,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'kcal kaldı',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.45),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '$consumedKcal / $targetKcal kcal tüketildi',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          remKcal > 400
                              ? Icons.bolt_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 18,
                          color: AppColors.primaryLight,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          remKcal > 400 ? 'Alan var' : 'Yakınsın',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Macro tiles
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
              child: Row(
                children: [
                  _macroProgressTile(
                    label: 'Kalori',
                    value: '$remKcal',
                    unit: 'kcal',
                    progress: pKcal,
                    color: AppColors.secondary,
                    icon: Icons.local_fire_department_rounded,
                  ),
                  _macroProgressTile(
                    label: 'Protein',
                    value: '$remP',
                    unit: 'g',
                    progress: pProt,
                    color: AppColors.chartBlue,
                    icon: Icons.fitness_center_rounded,
                  ),
                  _macroProgressTile(
                    label: 'Karb',
                    value: '$remC',
                    unit: 'g',
                    progress: pCarb,
                    color: AppColors.chartGreen,
                    icon: Icons.grain_rounded,
                  ),
                  _macroProgressTile(
                    label: 'Yağ',
                    value: '$remF',
                    unit: 'g',
                    progress: pFat,
                    color: const Color(0xFFFFB74D),
                    icon: Icons.water_drop_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroProgressTile({
    required String label,
    required String value,
    required String unit,
    required double progress,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 7),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.65),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Control Panel ───────────────────────────────────────────────────────

  Widget _buildControlPanel(DietProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.manage_search_rounded,
                  size: 14,
                  color: AppColors.primaryLight,
                ),
                const SizedBox(width: 6),
                Text(
                  'Öğün ve tercih seç',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildMealTypeSelector(provider),
            const SizedBox(height: 10),
            _buildSuggestionModeSelector(provider),
            const SizedBox(height: 10),
            Text(
              'Hızlı ara',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.42),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _smartChips()
                    .map(
                      (chip) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(chip),
                          onPressed: () {
                            _searchController.text = chip;
                            _onSearchChanged(chip);
                          },
                          avatar: Icon(
                            Icons.bolt_rounded,
                            size: 14,
                            color: AppColors.primaryLight.withValues(
                              alpha: 0.75,
                            ),
                          ),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionModeSelector(DietProvider provider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...[
            (SuggestionMode.balanced, 'Dengeli', Icons.balance_rounded),
            (
              SuggestionMode.highProtein,
              'Yüksek Protein',
              Icons.fitness_center_rounded,
            ),
            (SuggestionMode.lowCarb, 'Düşük Karb', Icons.eco_rounded),
          ].map((e) {
            final mode = e.$1;
            final label = e.$2;
            final icon = e.$3;
            final selected = provider.suggestionMode == mode;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  provider.setSuggestionMode(mode);
                  _load();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.2),
                              AppColors.primary.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: selected
                        ? null
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.1),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 13,
                        color: selected
                            ? AppColors.primaryLight
                            : Colors.white38,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          color: selected
                              ? AppColors.primaryLight
                              : Colors.white54,
                          fontSize: 11.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<String> _smartChips() {
    const Map<MealType, List<String>> allChips = {
      MealType.breakfast: ['Yumurta', 'Yulaf', 'Peynir', 'Simit', 'Omlet'],
      MealType.lunch: ['Tavuk', 'Salata', 'Çorba', 'Pilav', 'Köfte'],
      MealType.dinner: ['Izgara', 'Sebze', 'Balık', 'Et', 'Çorba'],
      MealType.snack: ['Kuruyemiş', 'Meyve', 'Yoğurt', 'Kahve', 'Muz'],
    };
    return allChips[_mealType] ?? [];
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Örn: lavaş, tavuk, makarna...',
        hintStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 13.5,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          color: Colors.white.withValues(alpha: 0.4),
          size: 20,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: Icon(
                  Icons.clear_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                  _load();
                },
              )
            : Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primaryLight.withValues(alpha: 0.65),
                size: 18,
              ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.055),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
      ),
    );
  }

  Widget _buildRefinementBar(List<String> dislikeSuggestions) {
    final actions = [
      (
        _SuggestionRefinement.smart,
        'Akıllı',
        Icons.auto_awesome_rounded,
        AppColors.primaryLight,
      ),
      (
        _SuggestionRefinement.filling,
        'Tok Tutan',
        Icons.local_fire_department_rounded,
        AppColors.secondary,
      ),
      (
        _SuggestionRefinement.quick,
        'Pratik',
        Icons.flash_on_rounded,
        AppColors.chartBlue,
      ),
      (
        _SuggestionRefinement.budget,
        'Bütçe Dostu',
        Icons.savings_rounded,
        AppColors.chartGreen,
      ),
      (
        _SuggestionRefinement.homeStyle,
        'Ev Tipi',
        Icons.home_rounded,
        const Color(0xFFFFB74D),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: actions.map((entry) {
                final selected = _refinement == entry.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _setRefinement(entry.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? entry.$4.withValues(alpha: 0.15)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? entry.$4.withValues(alpha: 0.45)
                              : Colors.white.withValues(alpha: 0.09),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.$3,
                            size: 14,
                            color: selected ? entry.$4 : Colors.white54,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            entry.$2,
                            style: TextStyle(
                              color: selected ? entry.$4 : Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          if (dislikeSuggestions.isNotEmpty || _mutedTokens.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'İstemediğin şeyleri gizle',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (_mutedTokens.isNotEmpty)
                  GestureDetector(
                    onTap: _clearMutedKeywords,
                    child: Text(
                      'Temizle',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...dislikeSuggestions.map(
                    (token) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        onPressed: () => _muteKeyword(token),
                        backgroundColor: Colors.white.withValues(alpha: 0.045),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        label: Text(
                          '$token istemem',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ..._mutedTokens.map(
                    (token) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Chip(
                        backgroundColor: AppColors.secondary.withValues(
                          alpha: 0.14,
                        ),
                        side: BorderSide(
                          color: AppColors.secondary.withValues(alpha: 0.18),
                        ),
                        deleteIconColor: AppColors.secondary,
                        onDeleted: () {
                          setState(() => _mutedTokens.remove(token));
                        },
                        label: Text(
                          'gizli: $token',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMealTypeSelector(DietProvider provider) {
    const types = [
      (MealType.breakfast, 'Kahvaltı', Icons.wb_sunny_outlined),
      (MealType.lunch, 'Öğle', Icons.restaurant_outlined),
      (MealType.dinner, 'Akşam', Icons.nightlight_round_outlined),
      (MealType.snack, 'Atıştırma', Icons.cookie_outlined),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((e) {
          final type = e.$1;
          final label = e.$2;
          final icon = e.$3;
          final selected = _mealType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _mealType = type);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.1),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: selected
                          ? AppColors.primaryLight
                          : Colors.white.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? AppColors.primaryLight
                            : Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── AI Card ─────────────────────────────────────────────────────────────

  Widget _buildAICard(String text) {
    final provider = Provider.of<DietProvider>(context, listen: false);
    final targets = provider.macroTargets;
    final totals = provider.totals;
    final remP = (targets.protein - totals.totalProtein)
        .clamp(0.0, double.infinity)
        .round();
    final remC = (targets.carb - totals.totalCarb)
        .clamp(0.0, double.infinity)
        .round();
    final remF = (targets.fat - totals.totalFat)
        .clamp(0.0, double.infinity)
        .round();
    final remKcal = provider.remainingKcal.round();
    final priorityMessages = _priorityMessages(
      remKcal: remKcal,
      remP: remP,
      remC: remC,
      remF: remF,
      mode: provider.suggestionMode,
    );
    final highlights = _insightHighlights();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF0F1F12),
              Color(0xFF0A1410),
              Color(0xFF0D1117),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _PulsingDot(color: AppColors.primaryLight),
                          const SizedBox(width: 6),
                          const Text(
                            'AI KOÇ',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kişisel Beslenme Analizi',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _refreshingReasoning
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _refreshReasoning,
                          child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Icon(
                              Icons.refresh_rounded,
                              size: 15,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                ],
              ),
            ),
            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            if (priorityMessages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: priorityMessages
                      .map(
                        (message) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insights_rounded,
                                size: 10,
                                color: AppColors.primaryLight.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                text,
                maxLines: _reasoningExpanded ? null : 3,
                overflow: _reasoningExpanded
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 12.2,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (highlights.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: highlights
                      .map(
                        (item) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.chartGreen.withValues(alpha: 0.15),
                                AppColors.primary.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.chartGreen.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            item,
                            style: const TextStyle(
                              color: AppColors.chartGreen,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            // Expand/collapse
            GestureDetector(
              onTap: () =>
                  setState(() => _reasoningExpanded = !_reasoningExpanded),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _reasoningExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.primaryLight.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _reasoningExpanded ? 'Daha az göster' : 'Devamını göster',
                      style: TextStyle(
                        color: AppColors.primaryLight.withValues(alpha: 0.8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Carousel (Top Picks) ────────────────────────────────────────────────

  Widget _buildCarouselSection(
    DietProvider provider,
    List<SuggestedFoodInsight> picks, {
    required int remP,
    required int remC,
    required int remF,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Bugün En Mantıklı Seçimler',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '${picks.length} öneri',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            itemCount: picks.length,
            itemBuilder: (_, i) => _buildCarouselCard(picks[i], provider),
          ),
        ),
        if (picks.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Kaydırarak daha fazlasını gör →',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildComboSection(
    DietProvider provider,
    List<_MealComboPlan> combos,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.chartBlue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _mealType == MealType.breakfast
                    ? 'Kahvaltı Kombinasyonları'
                    : _mealType == MealType.snack
                        ? 'Atıştırmalık Kombinasyonları'
                        : 'Hazır Öğün Kombinasyonları',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: combos.length,
            itemBuilder: (_, index) => _buildComboCard(combos[index], provider),
          ),
        ),
      ],
    );
  }

  Widget _buildComboCard(_MealComboPlan combo, DietProvider provider) {
    return Container(
      width: 286,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.chartBlue.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.chartBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.chartBlue.withValues(alpha: 0.16),
                ),
                child: Icon(combo.icon, color: AppColors.chartBlue, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      combo.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      combo.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.56),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _comboMeta(
                '${combo.totalKcal.round()} kcal',
                AppColors.secondary,
              ),
              _comboMeta(
                'P ${combo.totalProtein.round()}g',
                AppColors.chartBlue,
              ),
              _comboMeta('${combo.prepMinutes} dk', AppColors.chartGreen),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            combo.reason,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 11.8,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: combo.items
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${item.item.name} ${item.suggestedPortionG.round()}g',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              onPressed: () => _quickAddCombo(combo, provider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.chartBlue.withValues(alpha: 0.18),
                foregroundColor: AppColors.chartBlue,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                side: BorderSide(
                  color: AppColors.chartBlue.withValues(alpha: 0.28),
                ),
              ),
              child: const Text(
                'Bu mini öğünü ekle',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard(
    SuggestedFoodInsight suggestion,
    DietProvider provider,
  ) {
    final food = suggestion.item;
    final score = suggestion.score;
    final scoreColor = _scoreColor(score);
    final badges = _badges(food);
    final isQuickAdding = _quickAddedId == food.id;

    return GestureDetector(
      onTap: () => _openPortionOverlay(suggestion),
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scoreColor.withValues(alpha: 0.18),
              const Color(0xFF111520),
              const Color(0xFF0A0C10),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: scoreColor.withValues(alpha: 0.35),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: scoreColor.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Score badge + favorite
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scoreColor.withValues(alpha: 0.28),
                        scoreColor.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 9,
                        color: scoreColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${score.round()} uyum',
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                if (suggestion.isFavoriteLike)
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 12,
                      color: AppColors.secondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            // Food icon + category
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scoreColor.withValues(alpha: 0.22),
                        scoreColor.withValues(alpha: 0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: scoreColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    size: 20,
                    color: scoreColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.category,
                        style: TextStyle(
                          color: scoreColor.withValues(alpha: 0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _MealSuggestionHeuristics.prepLabel(food),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Food name — prominent
            Text(
              food.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                height: 1.2,
                letterSpacing: -0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            // Macro pills
            Row(
              children: [
                _macroPill(
                  '${food.kcalPer100g.round()} kcal',
                  AppColors.secondary,
                ),
                const SizedBox(width: 4),
                _macroPill(
                  'P ${food.proteinPer100g.round()}g',
                  AppColors.chartBlue,
                ),
              ],
            ),
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: badges.first.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: badges.first.color.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  badges.first.label,
                  style: TextStyle(
                    color: badges.first.color,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Reason + portion info
            if (suggestion.reasons.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                suggestion.reasons.first,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Öneri: ${suggestion.suggestedPortionG.round()}g',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),

            const Spacer(),
            // Glow add button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 38,
              decoration: BoxDecoration(
                gradient: isQuickAdding
                    ? LinearGradient(
                        colors: [
                          AppColors.success.withValues(alpha: 0.3),
                          AppColors.success.withValues(alpha: 0.12),
                        ],
                      )
                    : LinearGradient(
                        colors: [
                          scoreColor.withValues(alpha: 0.28),
                          scoreColor.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isQuickAdding
                      ? AppColors.success.withValues(alpha: 0.5)
                      : scoreColor.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isQuickAdding ? AppColors.success : scoreColor)
                        .withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isQuickAdding
                      ? null
                      : () => _quickAdd(suggestion, provider),
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: isQuickAdding
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                scoreColor,
                              ),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                size: 14,
                                color: scoreColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Hemen ekle',
                                style: TextStyle(
                                  color: scoreColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // ─── Section Title ───────────────────────────────────────────────────────

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryLight, AppColors.chartGreen],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [Colors.white, Colors.white.withValues(alpha: 0.65)],
            ).createShader(bounds),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Food List ───────────────────────────────────────────────────────────

  Widget _buildFoodList(
    DietProvider provider,
    List<SuggestedFoodInsight> foods, {
    required int remP,
    required int remC,
    required int remF,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      sliver: SliverList.builder(
        itemCount: foods.length,
        itemBuilder: (_, i) => _buildFoodCard(
          foods[i],
          provider,
          remP: remP,
          remC: remC,
          remF: remF,
        ),
      ),
    );
  }

  Widget _buildFoodCard(
    SuggestedFoodInsight suggestion,
    DietProvider provider, {
    required int remP,
    required int remC,
    required int remF,
  }) {
    final food = suggestion.item;
    final score = suggestion.score;
    final scoreColor = _scoreColor(score);
    final badges = _badges(food);
    final isQuickAdding = _quickAddedId == food.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _openPortionOverlay(suggestion),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Score accent strip
                  Container(
                    width: 3.5,
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.7),
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(16),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Row 1: name + score dot + quick-add
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      food.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      food.category,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.35,
                                        ),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Quick-add button
                              GestureDetector(
                                onTap: () => isQuickAdding
                                    ? null
                                    : _quickAdd(suggestion, provider),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isQuickAdding
                                        ? AppColors.success.withValues(
                                            alpha: 0.2,
                                          )
                                        : scoreColor.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isQuickAdding
                                          ? AppColors.success.withValues(
                                              alpha: 0.5,
                                            )
                                          : scoreColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: isQuickAdding
                                      ? Padding(
                                          padding: const EdgeInsets.all(9),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  scoreColor,
                                                ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.add_rounded,
                                          size: 18,
                                          color: scoreColor,
                                        ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // Row 2: macro pills
                          Row(
                            children: [
                              _macroPill(
                                '${food.kcalPer100g.round()} kcal',
                                AppColors.secondary,
                              ),
                              const SizedBox(width: 5),
                              _macroPill(
                                'P ${food.proteinPer100g.round()}g',
                                AppColors.chartBlue,
                              ),
                              const SizedBox(width: 5),
                              _macroPill(
                                'K ${food.carbPer100g.round()}g',
                                AppColors.chartGreen,
                              ),
                              const SizedBox(width: 5),
                              _macroPill(
                                'Y ${food.fatPer100g.round()}g',
                                const Color(0xFFFFB74D),
                              ),
                            ],
                          ),

                          // Badges
                          if (badges.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Row(
                              children: badges
                                  .map(
                                    (b) => Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: b.color.withValues(
                                            alpha: 0.14,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          b.label,
                                          style: TextStyle(
                                            color: b.color,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],

                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _microInfoPill(
                                _MealSuggestionHeuristics.prepLabel(food),
                                AppColors.chartBlue,
                              ),
                              _microInfoPill(
                                _MealSuggestionHeuristics.practicalityLabel(
                                  food,
                                ),
                                AppColors.chartGreen,
                              ),
                              _microInfoPill(
                                _MealSuggestionHeuristics.costLabel(food),
                                AppColors.secondary,
                              ),
                            ],
                          ),

                          // Top reason
                          if (suggestion.reasons.isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 11,
                                    color: scoreColor.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      suggestion.reasons.first,
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),
                          Text(
                            _MealSuggestionHeuristics.bestUseLabel(
                              food,
                              _mealType,
                            ),
                            style: TextStyle(
                              color: scoreColor.withValues(alpha: 0.82),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Bottom row: portion + grocery
                          Row(
                            children: [
                              Icon(
                                Icons.scale_rounded,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Önerilen: ${suggestion.suggestedPortionG.round()}g',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              if (suggestion.isFavoriteLike)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Icon(
                                    Icons.favorite_rounded,
                                    size: 12,
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                onTap: () => _navigateToGroceryList(food),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.chartGreen.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: AppColors.chartGreen.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 12,
                                    color: AppColors.chartGreen.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Portion Overlay ─────────────────────────────────────────────────────

  Widget _buildPortionOverlay(DietProvider provider) {
    final food = _selectedFood!;
    final grams = _adjustmentGrams;
    final factor = grams / 100.0;

    final realKcal = (food.kcalPer100g * factor).round();
    final realProt = (food.proteinPer100g * factor).round();
    final realCarb = (food.carbPer100g * factor).round();
    final realFat = (food.fatPer100g * factor).round();
    final impact = provider.calculateMacroImpact(food, grams);

    return GestureDetector(
      onTap: () => setState(() => _selectedFood = null),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _selectedFood = null),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white38,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Porsiyon',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            '${grams.round()} g',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: grams,
                      min: 10,
                      max: 600,
                      divisions: 59,
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.white10,
                      onChanged: (val) =>
                          setState(() => _adjustmentGrams = val),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _macroDetailTile(
                            'Kalori',
                            '$realKcal kcal',
                            impact['kcal']!,
                            AppColors.secondary,
                          ),
                          _macroDetailTile(
                            'Protein',
                            '${realProt}g',
                            impact['protein']!,
                            AppColors.chartBlue,
                          ),
                          _macroDetailTile(
                            'Karb',
                            '${realCarb}g',
                            impact['carb']!,
                            AppColors.chartGreen,
                          ),
                          _macroDetailTile(
                            'Yağ',
                            '${realFat}g',
                            impact['fat']!,
                            const Color(0xFFFFB74D),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => setState(() => _showRecipe = !_showRecipe),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _showRecipe
                              ? AppColors.chartGreen.withValues(alpha: 0.14)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _showRecipe
                                ? AppColors.chartGreen.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu_rounded,
                              size: 14,
                              color: _showRecipe
                                  ? AppColors.chartGreen
                                  : Colors.white.withValues(alpha: 0.45),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showRecipe
                                  ? 'Tarifi Gizle'
                                  : 'Tarif & Hazırlanış',
                              style: TextStyle(
                                color: _showRecipe
                                    ? AppColors.chartGreen
                                    : Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showRecipe
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 15,
                              color: _showRecipe
                                  ? AppColors.chartGreen
                                  : Colors.white30,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showRecipe) _buildRecipeSection(food),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _navigateToGroceryList(food),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.chartGreen.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.chartGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_shopping_cart_rounded,
                                    size: 15,
                                    color: AppColors.chartGreen,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Listeye Ekle',
                                    style: TextStyle(
                                      color: AppColors.chartGreen,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                await provider.addEntry(
                                  food: food,
                                  grams: grams,
                                  mealType: _mealType,
                                  date: provider.selectedDate,
                                );
                                if (mounted) {
                                  setState(() => _selectedFood = null);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${food.name} eklendi!',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      margin: const EdgeInsets.all(12),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Öğüne Ekle',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToGroceryList(FoodItem food) {
    setState(() => _selectedFood = null);
    try {
      widget.tabNavigator?.pushNamed(
        'smart_grocery_list',
        arguments: {
          'seedItems': [food.name],
          'seedReason': 'Öneri listesinden eklendi',
          'seedMealName': food.name,
        },
      );
    } catch (e) {
      debugPrint('grocery navigation: $e');
    }
  }

  // ─── Recipe Tips ─────────────────────────────────────────────────────────

  static List<String> _getRecipeTips(FoodItem food) {
    final n = food.name.toLowerCase();
    if (n.contains('yumurta') || n.contains('egg')) {
      return [
        '🥚 Haşlama: Kaynar suya 6–8 dk. Çıkarınca soğuk suya alın, kolay soyulur.',
        '🍳 Sahanda: Yapışmaz tavada 1 tatlı kaşığı yağ, kısık ateşte 3 dk.',
        '🥗 Protein artırımı: Bol sebzeyle omlet yap, doyma süresi uzar.',
      ];
    }
    if (n.contains('tavuk') || n.contains('chicken') || n.contains('piliç')) {
      return [
        '🔥 Fırında: 180°C\'de 30–40 dk. Üstünü kapatmak nemi korur.',
        '🥗 Marine: Limon + zeytinyağı + sarımsak, 30 dk beklettikten sonra pişir.',
        '⚡ Hızlı: Göğsü ince dilimle, tavada her taraf 4–5 dk.',
      ];
    }
    if (n.contains('yulaf') || n.contains('oat')) {
      return [
        '🥣 Sıcak: 1 ölçü yulafa 2 ölçü süt/su, kısık ateşte 5 dk karıştır.',
        '❄️ Gece: Soğuk süte batır, sabah hazır (overnight oats).',
        '🍌 Lezzet: Muz + tarçın + bal ile makro profili daha dengeli.',
      ];
    }
    if (n.contains('balık') || n.contains('somon') || n.contains('ton')) {
      return [
        '🐟 Fırın: Folyo içinde 200°C\'de 18–22 dk. Omega-3 korunur.',
        '🍋 Izgara: Limon + dereotu ile marine et, 4–5 dk/taraf orta ateş.',
        '🧂 İpucu: Fazla pişirme protein ve omega-3 kaybettirir, içi hafif nemli kalsın.',
      ];
    }
    if (n.contains('yoğurt') || n.contains('yogurt')) {
      return [
        '🥛 Süzme: Protein daha yoğun. Meyveyle veya kuru yemişle tüket.',
        '🥗 Sos: Sarımsak + nane + zeytinyağı ile cacık, hafif ve protein ekler.',
        '🍦 Alternatif: Yoğurt + meyve + bal karıştır, dondurucuda 2 saat.',
      ];
    }
    if (n.contains('pilav') || n.contains('bulgur')) {
      return [
        '🍚 Oran: 1 ölçü tahıl için 1.5–2 ölçü su, tuzu kaynayan suya ekle.',
        '🥦 Besin ekle: Pişerken üstüne sebze koy, nütrient profili zenginleşir.',
        '⚖️ Porsiyon: Pişmiş 150–200 g bir öğün için ideal, tartarak ölç.',
      ];
    }
    if (n.contains('mercimek') ||
        n.contains('fasulye') ||
        n.contains('nohut')) {
      return [
        '♨️ Haşlama: Soğuk suya başlayıp yavaş kaynat, gaz yapma azalır.',
        '🧅 Lezzet: Soğan + sarımsak + kimyon, pişince zeytinyağı gezdirin.',
        '🥗 Soğuk: Haşlanmışı salatayla karıştır, protein + lif kombinasyonu güçlü.',
      ];
    }
    if (n.contains('peynir') || n.contains('cheese')) {
      return [
        '🧀 Çiğ tüketim: En sade haliyle makro değeri en yüksek.',
        '🍳 Fırınla: Tost veya fırın yemeğine ekle, 180°C üstünde erime başlar.',
        '💡 Porsiyon: 30–40 g bir dilim ~100–120 kcal, gramı tartarak tüket.',
      ];
    }
    switch (food.category) {
      case 'Et / Protein':
        return [
          '🔥 Izgara veya fırında az yağlı pişirme tercih et.',
          '🧂 Marine: asit (limon/sirke) + yağ + baharatla 30 dk beklettikten sonra pişir.',
          '🌡️ İç sıcaklık +70°C olduğunda hem güvenli hem de protein korunmuş olur.',
        ];
      case 'Sebze':
        return [
          '🫒 Buharda veya zeytinyağında hafif sotele, vitamin kaybı azalır.',
          '🥗 Çiğ: salatalık ve domates çiğ yendiğinde daha fazla C vitamini içerir.',
          '🧄 Sarımsak + zeytinyağı antioksidan değeri artırır.',
        ];
      case 'Tahıl':
        return [
          '💧 Haşlama suyu oranı genellikle 1:2 (tahıl:su).',
          '🌿 Bütün tahıl tercih et, lif içeriği işlenmiş varyanta göre daha yüksek.',
          '⚖️ Kuru ve pişmiş ağırlıklar farklıdır — pişmiş halde tart.',
        ];
      case 'Süt Ürünleri':
        return [
          '🥛 Düşük yağlı seçenek kalori kısıtlı günlerde avantajlı.',
          '🌡️ Yüksek ısıda ısıtma protein ve kalsiyum yapısını bozabilir.',
          '🍓 Taze meyvelerle birlikte alınca biyoyararlanım artar.',
        ];
      case 'Meyve':
        return [
          '🍎 Mümkünse kabuğuyla ye, lif ve antioksidan içeriği yüksek.',
          '🧃 Meyve suyu yerine taze tercih et, lif kaybı yaşanmaz.',
          '⏰ Antrenman öncesi 30–60 dk hızlı karbonhidrat kaynağı olarak ideal.',
        ];
      default:
        return [
          '🍽️ Pişirme yöntemi besinin kalori ve besin değerini doğrudan etkiler.',
          '⚖️ Porsiyon miktarını tartarak ölç, göz kararı yanıltıcı olabilir.',
          '🥗 Protein + karbonhidrat + sağlıklı yağı bir öğünde dengeli tüket.',
        ];
    }
  }

  Widget _buildRecipeSection(FoodItem food) {
    final tips = _getRecipeTips(food);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1F0F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.chartGreen.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu_rounded,
                size: 13,
                color: AppColors.chartGreen,
              ),
              const SizedBox(width: 6),
              Text(
                'Nasıl Hazırlanır?',
                style: TextStyle(
                  color: AppColors.chartGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                tip,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared Widgets ──────────────────────────────────────────────────────

  Widget _macroDetailTile(
    String label,
    String grams,
    double percent,
    Color color,
  ) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: CircularProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                strokeWidth: 3.5,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '%${(percent * 100).round()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          grams,
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _macroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasQuery = _searchQuery.trim().isNotEmpty;
    final hiddenByRefinement =
        !hasQuery &&
        (_mutedTokens.isNotEmpty || _refinement != _SuggestionRefinement.smart);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasQuery
                    ? Icons.search_off_rounded
                    : Icons.check_circle_outline_rounded,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery
                  ? '"$_searchQuery" ile eşleşen yemek bulunamadı'
                  : hiddenByRefinement
                  ? 'Filtreler sonucu çok daralttı'
                  : 'Günlük hedefe çok yakınsın!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Farklı bir kelime dene veya aramayı temizle.'
                  : hiddenByRefinement
                  ? 'Seçili filtreleri veya gizlediğin seçenekleri gevşetmeyi dene.'
                  : 'Kalan makro hedeflerin doldu veya neredeyse doldu.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _comboMeta(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _microInfoPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _heroPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _anim.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _anim.value * 0.5),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Uygun yemekler aranıyor...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
