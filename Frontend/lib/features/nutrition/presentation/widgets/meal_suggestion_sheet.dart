import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// "Bana öner" / "Eksik makroyu tamamla" bottom sheet:
/// Kalan makro özeti, öğün seçimi, kalan kaloriye uygun yemek listesi → tıkla → porsiyon sayfası.
void showMealSuggestionSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusL)),
          border: Border.all(color: AppColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHandle(),
            Expanded(
              child: _MealSuggestionContent(scrollController: scrollController),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildHandle() {
  return Container(
    margin: const EdgeInsets.only(top: 12, bottom: 4),
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

class _MealSuggestionContent extends StatefulWidget {
  final ScrollController? scrollController;
  const _MealSuggestionContent({this.scrollController});

  @override
  State<_MealSuggestionContent> createState() => _MealSuggestionContentState();
}

class _MealSuggestionContentState extends State<_MealSuggestionContent> {
  MealType _mealType = MealType.lunch;
  List<SuggestedFoodInsight> _suggestions = [];
  String? _aiReasoning;
  bool _loading = true;
  bool _refreshingReasoning = false;
  bool _reasoningExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const _debounceMs = 400;

  // Porsiyon ayarı
  FoodItem? _selectedFood;
  double _adjustmentGrams = 100.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final provider = Provider.of<DietProvider>(context, listen: false);
    final query = _searchQuery.trim().isEmpty ? null : _searchQuery.trim();
    final list = await provider.getSuggestedFoodInsights(_mealType, limit: 28, query: query);
    final reasoning = await provider.getAISuggestionReasoning(
      list.map((e) => e.item).toList(),
    );
    if (mounted) {
      setState(() {
        _suggestions = list;
        _aiReasoning = reasoning;
        _loading = false;
      });
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

  Color _scoreColor(double score) {
    if (score >= 70) return AppColors.chartGreen;
    if (score >= 45) return AppColors.secondary;
    return Colors.white38;
  }

  /// Yiyeceğin öne çıkan özelliklerine göre badge listesi döner.
  List<({String label, Color color})> _badges(FoodItem food) {
    final badges = <({String label, Color color})>[];
    if (food.proteinPer100g >= 20) badges.add((label: 'Yüksek Protein', color: AppColors.chartBlue));
    if (food.carbPer100g < 5) badges.add((label: 'Düşük Karb', color: AppColors.chartGreen));
    if (food.fatPer100g < 3) badges.add((label: 'Düşük Yağ', color: const Color(0xFF8BC34A)));
    if (food.kcalPer100g < 50) badges.add((label: 'Hafif', color: Colors.white60));
    if (food.proteinPer100g >= 12 && food.carbPer100g < 30 && food.fatPer100g < 15) {
      if (badges.isEmpty) badges.add((label: 'Dengeli', color: AppColors.chartGreen));
    }
    return badges.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DietProvider>(context);
    final targets = provider.macroTargets;
    final t = provider.totals;
    final remKcal = provider.remainingKcal.round();
    final remP = (targets.protein - t.totalProtein).clamp(0.0, double.infinity).round();
    final remC = (targets.carb - t.totalCarb).clamp(0.0, double.infinity).round();
    final remF = (targets.fat - t.totalFat).clamp(0.0, double.infinity).round();

    final sorted = _suggestions;
    final topPicks = sorted.take(3).toList();
    final remainingPicks = sorted.length > 3 ? sorted.skip(3).toList() : <SuggestedFoodInsight>[];

    return Stack(
      children: [
        CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(
              child: _buildRemainingSummary(remKcal: remKcal, remP: remP, remC: remC, remF: remF),
            ),
            SliverToBoxAdapter(
              child: _buildControlPanel(provider),
            ),
            if (_aiReasoning != null && _aiReasoning!.isNotEmpty && !_loading)
              SliverToBoxAdapter(child: _buildAIReasoning(_aiReasoning!)),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _CenteredContent(child: _LoadingContent()),
              )
            else if (sorted.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CenteredContent(child: _buildEmptyState()),
              )
            else ...[
              SliverToBoxAdapter(
                child: _buildTopPicks(
                  provider,
                  topPicks,
                  remKcal: remKcal,
                  remP: remP,
                  remC: remC,
                  remF: remF,
                ),
              ),
              if (remainingPicks.isNotEmpty)
                SliverToBoxAdapter(child: _buildMoreTitle()),
              _buildFoodList(
                provider,
                remainingPicks.isEmpty ? topPicks : remainingPicks,
                remKcal: remKcal,
                remP: remP,
                remC: remC,
                remF: remF,
              ),
            ],
          ],
        ),
        if (_selectedFood != null) _buildPortionAdjustmentOverlay(provider),
      ],
    );
  }

  Widget _buildSmartChips() {
    final Map<MealType, List<String>> allChips = {
      MealType.breakfast: ['Yumurta', 'Yulaf', 'Peynir', 'Zeytin', 'Omlet', 'Meyve'],
      MealType.lunch: ['Tavuk', 'Salata', 'Çorba', 'Pilav', 'Makarna', 'Köfte'],
      MealType.dinner: ['Izgara', 'Sebze', 'Balık', 'Zeytinyağlı', 'Et', 'Çorba'],
      MealType.snack: ['Kuruyemiş', 'Meyve', 'Yoğurt', 'Kahve', 'Bisküvi', 'Muz'],
    };

    final chips = allChips[_mealType] ?? [];

    return Container(
      height: 40,
      margin: EdgeInsets.zero,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final chip = chips[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(chip),
              onPressed: () {
                _searchController.text = chip;
                _onSearchChanged(chip);
              },
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              labelStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlPanel(DietProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.sm, AppSpacing.m, AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildMealTypeSelector(provider),
            const SizedBox(height: 10),
            _buildModeChips(context, provider),
            const SizedBox(height: 8),
            _buildSmartChips(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.xs),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ne ekleyeyim?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kalan makrolarına en uygun yemekler',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPicks(
    DietProvider provider,
    List<SuggestedFoodInsight> picks, {
    required int remKcal,
    required int remP,
    required int remC,
    required int remF,
  }) {
    if (picks.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'En iyi eşleşmeler',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Kalan hedeflerine en iyi uyan ilk öneriler.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ...picks.map(
            (pick) => _buildFoodCard(
              pick,
              provider,
              remP: remP,
              remC: remC,
              remF: remF,
              featured: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.xs),
      child: Text(
        'Diğer uygun seçenekler',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.82),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRemainingSummary({
    required int remKcal,
    required int remP,
    required int remC,
    required int remF,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _remainingTile('Kalori', '$remKcal\nkcal', AppColors.secondary, Icons.local_fire_department_rounded),
            _vertDivider(),
            _remainingTile('Protein', '${remP}g', AppColors.chartBlue, Icons.fitness_center_rounded),
            _vertDivider(),
            _remainingTile('Karb', '${remC}g', AppColors.chartGreen, Icons.grain_rounded),
            _vertDivider(),
            _remainingTile('Yağ', '${remF}g', const Color(0xFFFFB74D), Icons.water_drop_rounded),
          ],
        ),
      ),
    );
  }

  Widget _remainingTile(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.9)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _vertDivider() => Container(
        width: 1,
        height: 38,
        color: Colors.white.withValues(alpha: 0.07),
      );

  Widget _buildSearchBar() {
    return TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Örn: lavaş, tavuk, makarna...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.5), size: 22),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear_rounded, size: 20, color: Colors.white.withValues(alpha: 0.6)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                    _load();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );
  }

  Widget _buildMealTypeSelector(DietProvider provider) {
    final types = [
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _mealType = type);
                    _load();
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: selected ? AppColors.primaryLight : Colors.white54),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: selected ? AppColors.primaryLight : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
  }

  Widget _buildModeChips(BuildContext context, DietProvider provider) {
    final modes = [
      (SuggestionMode.balanced, 'Dengeli'),
      (SuggestionMode.highProtein, 'Yüksek Protein'),
      (SuggestionMode.lowCarb, 'Düşük Karb'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: modes.map((e) {
          final mode = e.$1;
          final label = e.$2;
          final selected = provider.suggestionMode == mode;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                provider.setSuggestionMode(mode);
                _load();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AppColors.primaryLight : Colors.white70,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAIReasoning(String text) {
    const maxLines = 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.xs, AppSpacing.m, AppSpacing.xs),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.14),
              AppColors.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 0),
              child: Row(
                children: [
                  _PulsingDot(color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'AI Koç',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _refreshingReasoning
                      ? const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          onPressed: _refreshReasoning,
                          icon: Icon(Icons.refresh_rounded,
                              size: 16, color: AppColors.primary.withValues(alpha: 0.6)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: 'Yorumu yenile',
                        ),
                ],
              ),
            ),
            // Text body (expandable)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
              child: Text(
                text,
                maxLines: _reasoningExpanded ? null : maxLines,
                overflow: _reasoningExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Expand / collapse toggle
            GestureDetector(
              onTap: () => setState(() => _reasoningExpanded = !_reasoningExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
                child: Row(
                  children: [
                    Text(
                      _reasoningExpanded ? 'Daha az göster' : 'Devamını göster',
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _reasoningExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 14,
                      color: AppColors.primary.withValues(alpha: 0.75),
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

  Widget _buildEmptyState() {
    final hasQuery = _searchQuery.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasQuery ? Icons.search_off_rounded : Icons.check_circle_outline_rounded,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery
                  ? '"$_searchQuery" ile eşleşen yemek bulunamadı.'
                  : 'Bugünkü hedefe çok yakınsın veya zaten doldurdun.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Farklı bir kelime yaz veya aramayı temizle.'
                  : 'Kalan kalori veya makro kaldığında burada öneriler görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodList(
    DietProvider provider,
    List<SuggestedFoodInsight> foods, {
    required int remKcal,
    required int remP,
    required int remC,
    required int remF,
  }) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, 32),
      sliver: SliverList.builder(
        itemCount: foods.length,
        itemBuilder: (_, i) {
          final food = foods[i];
          return _buildFoodCard(
            food,
            provider,
            remP: remP,
            remC: remC,
            remF: remF,
          );
        },
      ),
    );
  }

  Widget _buildFoodCard(
    SuggestedFoodInsight suggestion,
    DietProvider provider, {
    required int remP,
    required int remC,
    required int remF,
    bool featured = false,
  }) {
    final food = suggestion.item;
    final score = suggestion.score;
    final badges = _badges(food);
    final scoreColor = _scoreColor(score);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFood = food;
              _adjustmentGrams = suggestion.suggestedPortionG;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: featured
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: featured
                    ? AppColors.primary.withValues(alpha: 0.22)
                    : Colors.white.withValues(alpha: 0.07),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row 1: name + fit score
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        food.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Fit score circle
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withValues(alpha: 0.1),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.4), width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            score.round().toString(),
                            style: TextStyle(color: scoreColor, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'uyum',
                            style: TextStyle(color: scoreColor.withValues(alpha: 0.7), fontSize: 7, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Row 2: macro pills
                Row(
                  children: [
                    _macroPill('${food.kcalPer100g.round()} kcal', AppColors.secondary),
                    const SizedBox(width: 6),
                    _macroPill('P ${food.proteinPer100g.round()}g', AppColors.chartBlue),
                    const SizedBox(width: 6),
                    _macroPill('K ${food.carbPer100g.round()}g', AppColors.chartGreen),
                    const SizedBox(width: 6),
                    _macroPill('Y ${food.fatPer100g.round()}g', const Color(0xFFFFB74D)),
                  ],
                ),

                if (badges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: badges.map((b) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: b.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(b.label,
                            style: TextStyle(color: b.color, fontSize: 9, fontWeight: FontWeight.w800)),
                      ),
                    )).toList(),
                  ),
                ],

                if (suggestion.reasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: suggestion.reasons
                        .map(
                          (reason) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.18),
                              ),
                            ),
                            child: Text(
                              reason,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.84),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                const SizedBox(height: 10),

                // Row 3: macro fill bars
                _macroBars(food, remP: remP, remC: remC, remF: remF),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.scale_rounded,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Önerilen porsiyon: ${suggestion.suggestedPortionG.round()} g',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (suggestion.isFavoriteLike) ...[
                      const Spacer(),
                      Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: AppColors.secondary.withValues(alpha: 0.9),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _macroBars(FoodItem food, {required int remP, required int remC, required int remF}) {
    final List<(String, double, Color)> bars = [
      ('Protein', remP > 0 ? (food.proteinPer100g / remP).clamp(0.0, 1.0) : 0.0, AppColors.chartBlue),
      ('Karb', remC > 0 ? (food.carbPer100g / remC).clamp(0.0, 1.0) : 0.0, AppColors.chartGreen),
      ('Yağ', remF > 0 ? (food.fatPer100g / remF).clamp(0.0, 1.0) : 0.0, const Color(0xFFFFB74D)),
    ];

    return Row(
      children: bars.map((b) {
        final label = b.$1;
        final fill = b.$2;
        final color = b.$3;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.w600)),
                    Text('${(fill * 100).round()}%',
                        style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 9, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: fill,
                    minHeight: 4,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPortionAdjustmentOverlay(DietProvider provider) {
    if (_selectedFood == null) return const SizedBox.shrink();

    final food = _selectedFood!;
    final grams = _adjustmentGrams;
    final factor = grams / 100.0;

    // Gerçek gram değerleri
    final realKcal = (food.kcalPer100g * factor).round();
    final realProt = (food.proteinPer100g * factor).round();
    final realCarb = (food.carbPer100g * factor).round();
    final realFat = (food.fatPer100g * factor).round();

    // Hedef katkı yüzdeleri
    final impact = provider.calculateMacroImpact(food, grams);

    return GestureDetector(
      onTap: () => setState(() => _selectedFood = null),
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
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
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Food name
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _selectedFood = null),
                          icon: const Icon(Icons.close_rounded, color: Colors.white54),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Gram slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Porsiyon', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${grams.round()} g',
                            style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800),
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
                      onChanged: (val) => setState(() => _adjustmentGrams = val),
                    ),

                    const SizedBox(height: 12),

                    // Macro breakdown — gram değerleri + hedef katkı %
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _macroDetailTile('Kalori', '$realKcal kcal', impact['kcal']!, AppColors.secondary),
                          _macroDetailTile('Protein', '${realProt}g', impact['protein']!, AppColors.chartBlue),
                          _macroDetailTile('Karb', '${realCarb}g', impact['carb']!, AppColors.chartGreen),
                          _macroDetailTile('Yağ', '${realFat}g', impact['fat']!, const Color(0xFFFFB74D)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          await provider.addEntry(
                            food: food,
                            grams: grams,
                            mealType: _mealType,
                            date: provider.selectedDate,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${food.name} eklendi!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Öğüne Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
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

  /// Gram değeri + dairesel hedef katkı % gösteren tile.
  Widget _macroDetailTile(String label, String grams, double percent, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                strokeWidth: 3.5,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text(
              '%${(percent * 100).round()}',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          grams,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 10),
        ),
      ],
    );
  }

  Widget _macroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
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
            BoxShadow(color: widget.color.withValues(alpha: _anim.value * 0.5), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}

class _CenteredContent extends StatelessWidget {
  final Widget child;

  const _CenteredContent({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: child,
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Senin için uygun yemekler aranıyor...',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
        ),
      ],
    );
  }
}
