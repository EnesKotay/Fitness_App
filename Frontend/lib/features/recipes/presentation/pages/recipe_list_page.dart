import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../nutrition/presentation/state/diet_provider.dart';
import '../../domain/entities/recipe.dart';
import '../state/recipe_provider.dart';
import 'recipe_detail_page.dart';

// ─── Helpers ─────────────────────────────────────────────────────────────────

Color _catColor(String cat) {
  switch (cat) {
    case 'bowl':
      return const Color(0xFF43E97B);
    case 'ana_yemek':
      return const Color(0xFFE06A3A);
    case 'salata':
      return const Color(0xFF4FACFE);
    case 'smoothie':
      return const Color(0xFFB467FF);
    case 'atistirmalik':
      return const Color(0xFFFFD166);
    default:
      return AppColors.secondary;
  }
}

String _catLabel(String cat) {
  switch (cat) {
    case 'bowl':
      return 'Bowl';
    case 'ana_yemek':
      return 'Ana Yemek';
    case 'salata':
      return 'Salata';
    case 'smoothie':
      return 'Smoothie';
    case 'atistirmalik':
      return 'Atıştırmalık';
    default:
      return cat;
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String? _initialLoadIssue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initRecipes();
    });
    _searchCtrl.addListener(() => setState(() {}));
  }

  Future<void> _initRecipes({bool force = false}) async {
    if (mounted && _initialLoadIssue != null) {
      setState(() => _initialLoadIssue = null);
    }

    try {
      final provider = context.read<RecipeProvider>();
      await provider.init(force: force).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      if (provider.errorMessage != null) {
        _showRetrySnackBar(provider.errorMessage!);
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _initialLoadIssue =
            'Tarifler yüklenirken beklenenden uzun sürdü. Lütfen tekrar dene.';
      });
      _showRetrySnackBar('Tarifler yüklenirken bağlantı gecikti.');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _initialLoadIssue = 'Tarifler yüklenemedi. Lütfen tekrar dene.';
      });
      _showRetrySnackBar('Tarifler yüklenemedi: $error');
    }
  }

  void _showRetrySnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        action: SnackBarAction(
          label: 'Tekrar Dene',
          textColor: Colors.white,
          onPressed: () => _initRecipes(force: true),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _navigateTo(BuildContext context, Recipe recipe) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: recipe)));
  }

  void _clearDiscoveryState(RecipeProvider provider) {
    _searchCtrl.clear();
    provider.setSearch('');
    provider.setShowOnlyFavorites(false);
    provider.setCategory('tümü');
    provider.setSortMode(SortMode.none);
    provider.clearFilter();
  }

  // ─── Sort Sheet ──────────────────────────────────────────────────────────

  void _showSortSheet(BuildContext context, RecipeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, _) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 20),
              Text(
                'Sırala',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              ...SortMode.values.map((mode) {
                final selected = provider.sortMode == mode;
                return GestureDetector(
                  onTap: () {
                    provider.setSortMode(mode);
                    Navigator.of(ctx).pop();
                  },
                  child: AnimatedContainer(
                    duration: 180.ms,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : const Color(0xFF1A1D25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : Colors.white.withValues(alpha: 0.07),
                        width: selected ? 1.2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(mode.emoji, style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 12),
                        Text(
                          mode.label,
                          style: GoogleFonts.dmSans(
                            color: selected
                                ? AppColors.primaryLight
                                : Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          Icon(
                            Icons.check_rounded,
                            color: AppColors.primaryLight,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Advanced Filter Sheet ───────────────────────────────────────────────

  void _showFilterSheet(BuildContext context, RecipeProvider provider) {
    RecipeFilter tempFilter = provider.filter;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SheetHandle(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Gelişmiş Filtre',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (tempFilter.isActive)
                    GestureDetector(
                      onTap: () =>
                          setS(() => tempFilter = const RecipeFilter()),
                      child: Text(
                        'Temizle',
                        style: GoogleFonts.dmSans(
                          color: AppColors.primaryLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Max kcal
              _FilterSectionLabel(
                label: '🔥 Maks. Kalori',
                value: tempFilter.maxKcal != null
                    ? '${tempFilter.maxKcal!.toInt()} kcal'
                    : 'Sınır yok',
              ),
              Slider(
                value: tempFilter.maxKcal ?? 800,
                min: 100,
                max: 800,
                divisions: 14,
                activeColor: Colors.orange,
                inactiveColor: Colors.white.withValues(alpha: 0.12),
                onChanged: (v) => setS(
                  () => tempFilter = tempFilter.copyWith(
                    maxKcal: v < 800 ? v : null,
                  ),
                ),
              ),

              // Min protein
              _FilterSectionLabel(
                label: '💪 Min. Protein',
                value: tempFilter.minProtein != null
                    ? '${tempFilter.minProtein!.toInt()}g'
                    : 'Sınır yok',
              ),
              Slider(
                value: tempFilter.minProtein ?? 0,
                min: 0,
                max: 60,
                divisions: 12,
                activeColor: AppColors.primaryLight,
                inactiveColor: Colors.white.withValues(alpha: 0.12),
                onChanged: (v) => setS(
                  () => tempFilter = tempFilter.copyWith(
                    minProtein: v > 0 ? v : null,
                  ),
                ),
              ),

              // Max süre
              const SizedBox(height: 8),
              _FilterSectionLabel(label: '⏱ Hazırlık Süresi', value: ''),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _TimeChip(
                    label: 'Hepsi',
                    selected: tempFilter.maxMinutes == null,
                    onTap: () => setS(
                      () => tempFilter = tempFilter.copyWith(maxMinutes: null),
                    ),
                  ),
                  _TimeChip(
                    label: '≤ 10dk',
                    selected: tempFilter.maxMinutes == 10,
                    onTap: () => setS(
                      () => tempFilter = tempFilter.copyWith(maxMinutes: 10),
                    ),
                  ),
                  _TimeChip(
                    label: '≤ 20dk',
                    selected: tempFilter.maxMinutes == 20,
                    onTap: () => setS(
                      () => tempFilter = tempFilter.copyWith(maxMinutes: 20),
                    ),
                  ),
                  _TimeChip(
                    label: '≤ 45dk',
                    selected: tempFilter.maxMinutes == 45,
                    onTap: () => setS(
                      () => tempFilter = tempFilter.copyWith(maxMinutes: 45),
                    ),
                  ),
                ],
              ),

              // Diet toggles
              const SizedBox(height: 16),
              _FilterSectionLabel(label: '🥦 Beslenme Tercihi', value: ''),
              const SizedBox(height: 8),
              _DietToggle(
                label: 'Vegan',
                emoji: '🌱',
                value: tempFilter.veganOnly,
                onChanged: (v) =>
                    setS(() => tempFilter = tempFilter.copyWith(veganOnly: v)),
              ),
              _DietToggle(
                label: 'Vejetaryen',
                emoji: '🥗',
                value: tempFilter.vegetarianOnly,
                onChanged: (v) => setS(
                  () => tempFilter = tempFilter.copyWith(vegetarianOnly: v),
                ),
              ),
              _DietToggle(
                label: 'Gluten-Free',
                emoji: '🌾',
                value: tempFilter.glutenFreeOnly,
                onChanged: (v) => setS(
                  () => tempFilter = tempFilter.copyWith(glutenFreeOnly: v),
                ),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    provider.setFilter(tempFilter);
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    'Uygula${tempFilter.activeCount > 0 ? ' (${tempFilter.activeCount})' : ''}',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<RecipeProvider, DietProvider>(
      builder: (context, provider, dietProvider, _) {
        final recipes = provider.filtered;
        final isDefault =
            provider.selectedCategory == 'tümü' &&
            !provider.showOnlyFavorites &&
            provider.searchQuery.isEmpty &&
            provider.sortMode == SortMode.none &&
            !provider.filter.isActive;
        final dailyTarget = dietProvider.dailyTargetKcal;
        final remainingKcal = dailyTarget == null
            ? null
            : dailyTarget - dietProvider.totals.totalKcal;
        final featured = isDefault
            ? provider.featuredFor(remainingKcal: remainingKcal)
            : null;
        final excludedIds = {if (featured != null) featured.id};
        final recentRecipes = isDefault
            ? provider.recentlyViewed
                  .where((recipe) => !excludedIds.contains(recipe.id))
                  .take(6)
                  .toList()
            : const <Recipe>[];
        excludedIds.addAll(recentRecipes.map((recipe) => recipe.id));
        final personalizedRecipes = isDefault
            ? provider.recommendedFor(
                remainingKcal: remainingKcal,
                limit: 6,
                excludeIds: excludedIds,
              )
            : const <Recipe>[];
        excludedIds.addAll(personalizedRecipes.map((recipe) => recipe.id));
        final quickRecipes = isDefault
            ? provider.quickPicks(limit: 6, excludeIds: excludedIds)
            : const <Recipe>[];

        final gridItems = recipes
            .where(
              (recipe) =>
                  recipe.id != featured?.id &&
                  !recentRecipes.any((item) => item.id == recipe.id) &&
                  !personalizedRecipes.any((item) => item.id == recipe.id) &&
                  !quickRecipes.any((item) => item.id == recipe.id),
            )
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFF08090C),
          body: CustomScrollView(
            controller: _scrollCtrl,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverHeader(
                context,
                provider,
                remainingKcal: remainingKcal,
                featuredRecipe: featured,
              ),
              SliverToBoxAdapter(child: _buildSearchBar(provider)),
              const SliverToBoxAdapter(child: SizedBox(height: 4)),
              SliverToBoxAdapter(child: _buildFilterRow(context, provider)),
              if (provider.searchQuery.isNotEmpty ||
                  provider.showOnlyFavorites ||
                  provider.selectedCategory != 'tümü' ||
                  provider.sortMode != SortMode.none ||
                  provider.filter.isActive)
                SliverToBoxAdapter(child: _buildActiveStateBar(provider)),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              if (isDefault && provider.recentlyViewed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _buildSectionLabel('SON BAKTIKLARIM'),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 10)),
                SliverToBoxAdapter(
                  child: _buildRecentlyViewed(context, provider),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],

              if (_initialLoadIssue != null)
                SliverFillRemaining(
                  child: _buildErrorState(
                    message: _initialLoadIssue!,
                    onRetry: () => _initRecipes(force: true),
                  ),
                )
              else if (provider.loading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                      strokeWidth: 2,
                    ),
                  ),
                )
              else if (provider.errorMessage != null)
                SliverFillRemaining(
                  child: _buildErrorState(
                    message: provider.errorMessage ?? '',
                    onRetry: () => _initRecipes(force: true),
                  ),
                )
              else if (recipes.isEmpty)
                SliverFillRemaining(child: _buildEmpty(provider))
              else ...[
                if (featured != null) ...[
                  SliverToBoxAdapter(
                    child: _buildFeaturedLabel(
                      hasPersonalization: remainingKcal != null,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _buildFeaturedCard(context, featured, provider),
                  ),
                  if (recentRecipes.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: _buildHorizontalSection(
                        title: 'Tekrar Göz At',
                        subtitle: 'Son baktığın tarifler burada.',
                        recipes: recentRecipes,
                      ),
                    ),
                  ],
                  if (personalizedRecipes.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: _buildHorizontalSection(
                        title: 'Senin İçin Seçildi',
                        subtitle: remainingKcal != null
                            ? 'Kalan hedefin ve alışkanlıkların dikkate alındı.'
                            : 'Favorilerin ve geçmiş seçimlerin baz alındı.',
                        recipes: personalizedRecipes,
                      ),
                    ),
                  ],
                  if (quickRecipes.isNotEmpty) ...[
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: _buildHorizontalSection(
                        title: 'Hızlı Seçimler',
                        subtitle:
                            'Kısa sürede hazırlanabilecek güçlü tarifler.',
                        recipes: quickRecipes,
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  if (gridItems.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildSectionLabel('Tüm Tarifler'),
                    ),
                ],
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          childAspectRatio: 0.71,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _RecipeCard(
                        recipe: gridItems[i],
                        index: i,
                        isFavorite: provider.isFavorite(gridItems[i].id),
                        onTap: () => _navigateTo(context, gridItems[i]),
                        onFavoriteTap: () =>
                            provider.toggleFavorite(gridItems[i].id),
                      ),
                      childCount: gridItems.length,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────

  Widget _buildSliverHeader(
    BuildContext context,
    RecipeProvider provider, {
    double? remainingKcal,
    Recipe? featuredRecipe,
  }) {
    final isSorted = provider.sortMode != SortMode.none;
    final isFiltered = provider.filter.isActive;
    final subtitle = remainingKcal != null
        ? '${provider.filtered.length} tarif · ${remainingKcal.toInt()} kcal kalan'
        : '${provider.filtered.length} sağlıklı tarif';
    final headline = provider.searchQuery.isNotEmpty
        ? '"${provider.searchQuery}" için tarifler'
        : provider.showOnlyFavorites
        ? 'Kaydettiğin favoriler'
        : featuredRecipe?.name ?? 'Bugün ne pişirelim?';
    final supportingText = provider.searchQuery.isNotEmpty
        ? 'Malzeme, kategori ve hedef etiketlerine göre eşleşen sonuçlar.'
        : provider.showOnlyFavorites
        ? 'Tek dokunuşla tekrar açabileceğin tariflerin burada.'
        : remainingKcal != null
        ? 'Kalan hedefin ve geçmiş seçimlerinle uyumlu önerileri öne çıkarıyoruz.'
        : 'Protein, süre ve kategoriye göre hızlıca en uygun tarifi bul.';
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F1015), Color(0xFF08090C)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -42,
              right: -12,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              top: 46,
              left: -36,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4FACFE).withValues(alpha: 0.07),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tarifler',
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Text(
                            subtitle,
                            style: GoogleFonts.dmSans(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showFilterSheet(context, provider),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: 200.ms,
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isFiltered
                                  ? const Color(
                                      0xFF4FACFE,
                                    ).withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isFiltered
                                    ? const Color(
                                        0xFF4FACFE,
                                      ).withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.1),
                                width: isFiltered ? 1.2 : 1,
                              ),
                            ),
                            child: Icon(
                              Icons.tune_rounded,
                              color: isFiltered
                                  ? const Color(0xFF4FACFE)
                                  : Colors.white,
                              size: 18,
                            ),
                          ),
                          if (isFiltered)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4FACFE),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showSortSheet(context, provider),
                      child: AnimatedContainer(
                        duration: 200.ms,
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: isSorted
                              ? AppColors.primary.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSorted
                                ? AppColors.primary.withValues(alpha: 0.5)
                                : Colors.white.withValues(alpha: 0.1),
                            width: isSorted ? 1.2 : 1,
                          ),
                        ),
                        child: Icon(
                          Icons.sort_rounded,
                          color: isSorted
                              ? AppColors.primaryLight
                              : Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.22,
                                  ),
                                ),
                              ),
                              child: Text(
                                remainingKcal != null
                                    ? 'Kişiselleştirilmiş keşif'
                                    : 'Sağlıklı tarif koleksiyonu',
                                style: GoogleFonts.dmSans(
                                  color: AppColors.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              headline,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 22,
                                height: 1.15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              supportingText,
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 12.5,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _HeaderStatCard(
                                    label: 'Görünen',
                                    value: '${provider.filtered.length}',
                                    accent: AppColors.primaryLight,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _HeaderStatCard(
                                    label: 'Favori',
                                    value: '${provider.favoriteCount}',
                                    accent: const Color(0xFFFF6B81),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _HeaderStatCard(
                                    label: remainingKcal != null
                                        ? 'Kalan'
                                        : 'Filtre',
                                    value: remainingKcal != null
                                        ? '${remainingKcal.toInt()}'
                                        : '${provider.filter.activeCount}',
                                    suffix: remainingKcal != null
                                        ? 'kcal'
                                        : 'aktif',
                                    accent: const Color(0xFF4FACFE),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  // ─── Search ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar(RecipeProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF161820),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              color: Colors.white.withValues(alpha: 0.35),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: provider.setSearch,
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Tarif veya malzeme ara…',
                  hintStyle: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            if (_searchCtrl.text.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  provider.setSearch('');
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 18,
                  ),
                ),
              ),
            ] else ...[
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  '${provider.filtered.length} sonuç',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.48),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActiveStateBar(RecipeProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (provider.showOnlyFavorites)
            const _StateChip(
              icon: Icons.favorite_rounded,
              label: 'Favoriler açık',
              accent: Color(0xFFFF6B81),
            ),
          if (provider.selectedCategory != 'tümü')
            _StateChip(
              icon: Icons.category_rounded,
              label: _catLabel(provider.selectedCategory),
              accent: _catColor(provider.selectedCategory),
            ),
          if (provider.searchQuery.isNotEmpty)
            _StateChip(
              icon: Icons.search_rounded,
              label: provider.searchQuery,
              accent: const Color(0xFF4FACFE),
            ),
          if (provider.sortMode != SortMode.none)
            _StateChip(
              icon: Icons.sort_rounded,
              label: provider.sortMode.label,
              accent: AppColors.primaryLight,
            ),
          if (provider.filter.isActive)
            _StateChip(
              icon: Icons.tune_rounded,
              label: '${provider.filter.activeCount} filtre aktif',
              accent: const Color(0xFF4FACFE),
            ),
          GestureDetector(
            onTap: () => _clearDiscoveryState(provider),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                'Temizle',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Filter row ──────────────────────────────────────────────────────────

  Widget _buildFilterRow(BuildContext context, RecipeProvider provider) {
    return SizedBox(
      height: 40,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        children: [
          _FavoriteChip(
            count: provider.favoriteCount,
            isActive: provider.showOnlyFavorites,
            onTap: () =>
                provider.setShowOnlyFavorites(!provider.showOnlyFavorites),
          ),
          const SizedBox(width: 8),
          ...RecipeProvider.categories.map((cat) {
            final selected =
                !provider.showOnlyFavorites &&
                provider.selectedCategory == cat['id'];
            final color = _catColor(cat['id']!);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => provider.setCategory(cat['id']!),
                child: AnimatedContainer(
                  duration: 200.ms,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              color.withValues(alpha: 0.3),
                              color.withValues(alpha: 0.12),
                            ],
                          )
                        : null,
                    color: selected ? null : const Color(0xFF161820),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? color.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.08),
                      width: selected ? 1.2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(cat['emoji']!, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 5),
                      Text(
                        cat['label']!,
                        style: GoogleFonts.dmSans(
                          color: selected
                              ? color
                              : Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (cat['id'] != 'tümü') ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${provider.countFor(cat['id']!)}',
                            style: GoogleFonts.dmSans(
                              color: selected
                                  ? color
                                  : Colors.white.withValues(alpha: 0.35),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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

  // ─── Day label ───────────────────────────────────────────────────────────

  Widget _buildFeaturedLabel({required bool hasPersonalization}) {
    final title = hasPersonalization ? 'Bugün Sana Uygun' : 'Günün Tarifi';
    final subtitle = hasPersonalization
        ? 'Kalori hedefin ve tarif alışkanlıkların baz alındı.'
        : 'Bugün için öne çıkan tarif.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                hasPersonalization ? '✨' : '☀️',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.32),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSection({
    required String title,
    required String subtitle,
    required List<Recipe> recipes,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 134,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: recipes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) => _StripRecipeCard(
              recipe: recipes[index],
              onTap: () => _navigateTo(context, recipes[index]),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Featured card ───────────────────────────────────────────────────────

  Widget _buildFeaturedCard(
    BuildContext context,
    Recipe recipe,
    RecipeProvider provider,
  ) {
    final color = _catColor(recipe.category);
    final isFav = provider.isFavorite(recipe.id);
    return GestureDetector(
      onTap: () => _navigateTo(context, recipe),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.25), const Color(0xFF0F1015)],
          ),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: _RecipeImagePanel(
                  recipe: recipe,
                  emojiSize: 80,
                  overlay: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color.withValues(alpha: 0.28),
                      const Color(0xFF0F1015).withValues(alpha: 0.78),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: 20,
              top: 20,
              bottom: 20,
              right: 120,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CategoryBadge(
                        label: _catLabel(recipe.category),
                        color: color,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        recipe.name,
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _MiniStat(
                            icon: Icons.bolt_rounded,
                            value: '${recipe.kcalPerServing.toInt()} kcal',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          _MiniStat(
                            icon: Icons.fitness_center_rounded,
                            value:
                                '${recipe.proteinPerServing.toInt()}g protein',
                            color: AppColors.primaryLight,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            color: Colors.white.withValues(alpha: 0.4),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe.totalTimeMinutes} dakika',
                            style: GoogleFonts.dmSans(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.04, end: 0),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => provider.toggleFavorite(recipe.id),
                child: AnimatedContainer(
                  duration: 200.ms,
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isFav
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFav
                          ? Colors.red.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Icon(
                    isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isFav
                        ? Colors.red
                        : Colors.white.withValues(alpha: 0.6),
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // ─── Recently Viewed ─────────────────────────────────────────────────────

  Widget _buildRecentlyViewed(BuildContext context, RecipeProvider provider) {
    final recents = provider.recentlyViewed;
    return SizedBox(
      height: 112,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: recents.length,
        separatorBuilder: (_, i) => const SizedBox(width: 10),
        itemBuilder: (ctx, i) {
          final recipe = recents[i];
          final color = _catColor(recipe.category);
          return GestureDetector(
            onTap: () => _navigateTo(context, recipe),
            child: Container(
              width: 130,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.18),
                    const Color(0xFF161820),
                  ],
                ),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 8,
                    top: 8,
                    child: SizedBox(
                      width: 42,
                      height: 42,
                      child: _RecipeImagePanel(
                        recipe: recipe,
                        borderRadius: 12,
                        emojiSize: 32,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    right: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          recipe.name,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${recipe.kcalPerServing.toInt()} kcal',
                          style: GoogleFonts.dmSans(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 180.ms).slideX(begin: 0.03, end: 0),
          );
        },
      ),
    );
  }

  // ─── Error state ─────────────────────────────────────────────────────────

  Widget _buildErrorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 44)),
          const SizedBox(height: 14),
          Text(
            'Tarifler yüklenemedi',
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'Tekrar Dene',
                style: GoogleFonts.dmSans(
                  color: AppColors.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(RecipeProvider provider) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            provider.showOnlyFavorites ? '💔' : '🔍',
            style: const TextStyle(fontSize: 44),
          ),
          const SizedBox(height: 14),
          Text(
            provider.showOnlyFavorites
                ? 'Henüz favorin yok'
                : 'Tarif bulunamadı',
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            provider.showOnlyFavorites
                ? 'Tarifleri favorilere eklemek için ❤️ simgesine dokun'
                : provider.filter.isActive
                ? 'Filtreleri değiştirmeyi dene'
                : 'Farklı bir arama dene',
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.25),
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          if (provider.filter.isActive) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: provider.clearFilter,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF4FACFE).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4FACFE).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'Filtreleri Temizle',
                  style: GoogleFonts.dmSans(
                    color: const Color(0xFF4FACFE),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Favorite Chip ────────────────────────────────────────────────────────────

class _FavoriteChip extends StatelessWidget {
  const _FavoriteChip({
    required this.count,
    required this.isActive,
    required this.onTap,
  });
  final int count;
  final bool isActive;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0x44FF4D6D), Color(0x22FF4D6D)],
                )
              : null,
          color: isActive ? null : const Color(0xFF161820),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xAAFF4D6D)
                : Colors.white.withValues(alpha: 0.08),
            width: isActive ? 1.2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isActive
                  ? const Color(0xFFFF4D6D)
                  : Colors.white.withValues(alpha: 0.5),
              size: 14,
            ),
            const SizedBox(width: 5),
            Text(
              count > 0 ? 'Favoriler ($count)' : 'Favoriler',
              style: GoogleFonts.dmSans(
                color: isActive
                    ? const Color(0xFFFF4D6D)
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recipe Card ─────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.index,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });
  final Recipe recipe;
  final int index;
  final bool isFavorite;
  final VoidCallback onTap, onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final color = _catColor(recipe.category);
    return GestureDetector(
      onTap: onTap,
      child:
          Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.18),
                      const Color(0xFF0F1015),
                    ],
                  ),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                            child: _RecipeImagePanel(
                              recipe: recipe,
                              borderRadius: 14,
                              emojiSize: 52,
                            ),
                          ),
                        ),
                        _CardInfoPanel(recipe: recipe, color: color),
                      ],
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _CategoryBadge(
                        label: _catLabel(recipe.category),
                        color: color,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _DifficultyDot(difficulty: recipe.difficulty),
                    ),
                    Positioned(
                      bottom: 72,
                      right: 8,
                      child: GestureDetector(
                        onTap: onFavoriteTap,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: AnimatedSwitcher(
                            duration: 250.ms,
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              key: ValueKey(isFavorite),
                              color: isFavorite
                                  ? const Color(0xFFFF4D6D)
                                  : Colors.white.withValues(alpha: 0.35),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 180.ms)
              .slideY(begin: 0.03, end: 0, curve: Curves.easeOut),
    );
  }
}

class _StripRecipeCard extends StatelessWidget {
  const _StripRecipeCard({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _catColor(recipe.category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 176,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.22), const Color(0xFF111318)],
          ),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 34,
                  height: 34,
                  child: _RecipeImagePanel(
                    recipe: recipe,
                    borderRadius: 11,
                    emojiSize: 28,
                  ),
                ),
                const Spacer(),
                _CategoryBadge(label: _catLabel(recipe.category), color: color),
              ],
            ),
            const Spacer(),
            Text(
              recipe.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _TinyBadge(
                  label: '${recipe.kcalPerServing.toInt()}',
                  sublabel: 'kcal',
                  color: Colors.orange,
                ),
                const SizedBox(width: 4),
                _TinyBadge(
                  label: '${recipe.proteinPerServing.toInt()}g',
                  sublabel: 'P',
                  color: AppColors.primaryLight,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${recipe.totalTimeMinutes} dk · ${recipe.difficulty}',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeImagePanel extends StatelessWidget {
  const _RecipeImagePanel({
    required this.recipe,
    required this.emojiSize,
    this.borderRadius = 0,
    this.overlay,
  });

  final Recipe recipe;
  final double emojiSize;
  final double borderRadius;
  final Gradient? overlay;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(recipe.imageEmoji, style: TextStyle(fontSize: emojiSize)),
    );

    Widget content;
    if (recipe.hasImageAsset) {
      content = Image.asset(
        recipe.imageAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      content = fallback;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black.withValues(alpha: 0.16)),
          content,
          if (overlay != null)
            DecoratedBox(decoration: BoxDecoration(gradient: overlay)),
        ],
      ),
    );
  }
}

class _CardInfoPanel extends StatelessWidget {
  const _CardInfoPanel({required this.recipe, required this.color});
  final Recipe recipe;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            border: Border(
              top: BorderSide(color: color.withValues(alpha: 0.12)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.name,
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (recipe.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  recipe.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.42),
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  _TinyBadge(
                    label: '${recipe.kcalPerServing.toInt()}',
                    sublabel: 'kcal',
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  _TinyBadge(
                    label: '${recipe.proteinPerServing.toInt()}g',
                    sublabel: 'P',
                    color: AppColors.primaryLight,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: Colors.white.withValues(alpha: 0.35),
                        size: 10,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${recipe.totalTimeMinutes}dk',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStatCard extends StatelessWidget {
  const _HeaderStatCard({
    required this.label,
    required this.value,
    required this.accent,
    this.suffix,
  });

  final String label;
  final String value;
  final String? suffix;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.42),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.dmSans(
                    color: accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (suffix != null)
                  TextSpan(
                    text: ' $suffix',
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 13),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Sheet helpers ────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (value.isNotEmpty)
          Text(
            value,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
      ],
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 180.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.2)
              : const Color(0xFF1A1D25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
            width: selected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            color: selected
                ? AppColors.primaryLight
                : Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _DietToggle extends StatelessWidget {
  const _DietToggle({
    required this.label,
    required this.emoji,
    required this.value,
    required this.onChanged,
  });
  final String label, emoji;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.dmSans(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primaryLight,
            activeTrackColor: AppColors.primaryLight.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }
}

// ─── Tiny shared widgets ──────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _DifficultyDot extends StatelessWidget {
  const _DifficultyDot({required this.difficulty});
  final String difficulty;
  Color get _color {
    switch (difficulty) {
      case 'kolay':
        return AppColors.primaryLight;
      case 'orta':
        return Colors.orange;
      case 'zor':
        return AppColors.error;
      default:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        difficulty,
        style: GoogleFonts.dmSans(
          color: _color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({
    required this.label,
    required this.sublabel,
    required this.color,
  });
  final String label, sublabel;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 3),
        Text(
          value,
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
