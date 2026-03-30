import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/recipe.dart';
import '../state/recipe_provider.dart';
import '../../../nutrition/presentation/state/diet_provider.dart';
import '../../../nutrition/domain/entities/meal_type.dart';

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

// ─── Detail Page ─────────────────────────────────────────────────────────────

class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});
  final Recipe recipe;
  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final Set<int> _checkedIngredients = {};
  int _portions = 1;
  bool _addingToMeal = false;

  @override
  void initState() {
    super.initState();
    _portions = widget.recipe.servings;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<RecipeProvider>().addToRecentlyViewed(widget.recipe.id);
      }
    });
  }

  void _openShoppingList() {
    Navigator.of(context).pushNamed(
      'smart_grocery_list',
      arguments: {
        'seedGroceryItems': widget.recipe.toGroceryItems(
          portions: _portions,
          linkedMealName: widget.recipe.name,
        ),
        'seedReason':
            '${widget.recipe.name} tarifi için malzemeler ($_portions porsiyon) listelendi.',
        'seedMealName': widget.recipe.name,
      },
    );
  }

  void _openCookMode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CookModePage(recipe: widget.recipe),
      ),
    );
  }

  // ─── Add to Meal ──────────────────────────────────────────────────────────

  void _showAddToMealSheet() {
    final recipe = widget.recipe;
    final color = _catColor(recipe.category);
    final factor = _portions / recipe.servings;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Hangi Öğüne Ekleyelim?',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(recipe.kcalPerServing * factor).toInt()} kcal · ${(recipe.proteinPerServing * factor).toInt()}g protein · $_portions porsiyon',
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),
            ...MealType.values.map((mealType) {
              final icons = {
                MealType.breakfast: '🌅',
                MealType.lunch: '☀️',
                MealType.dinner: '🌙',
                MealType.snack: '⚡',
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _addToMeal(mealType, factor);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          icons[mealType]!,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          mealType.label,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white.withValues(alpha: 0.3),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _addToMeal(MealType mealType, double factor) async {
    final recipe = widget.recipe;
    setState(() => _addingToMeal = true);
    try {
      await context.read<DietProvider>().addAiMealToDiary(
        mealName: recipe.name,
        kcal: recipe.kcalPerServing * factor,
        protein: recipe.proteinPerServing * factor,
        carbs: recipe.carbPerServing * factor,
        fat: recipe.fatPerServing * factor,
        mealType: mealType,
        date: DateTime.now(),
        grams: 100,
      );
      if (mounted) {
        context.read<RecipeProvider>().markCooked(recipe.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A1D25),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Text('✅', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Text(
                  '${recipe.name} ${mealType.label} öğününe eklendi',
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eklenemedi: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _addingToMeal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final color = _catColor(recipe.category);
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final factor = _portions / recipe.servings;

    return Consumer2<RecipeProvider, DietProvider>(
      builder: (context, recipeProvider, dietProvider, _) {
        final isFav = recipeProvider.isFavorite(recipe.id);

        // Hedef uyumluluğu
        final target = dietProvider.dailyTargetKcal ?? 2000;
        final remaining = target - dietProvider.totals.totalKcal;
        final recipeKcal = recipe.kcalPerServing * factor;
        final GoalCompatibility goalCompat = remaining <= 0
            ? GoalCompatibility.exceeded
            : recipeKcal <= remaining
            ? GoalCompatibility.fits
            : GoalCompatibility.high;

        final similar = recipeProvider.similarTo(recipe);

        return Scaffold(
          backgroundColor: const Color(0xFF08090C),
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildHeroSliver(
                    context,
                    recipe,
                    color,
                    topPad,
                    isFav,
                    recipeProvider,
                  ),
                  SliverToBoxAdapter(
                    child: _buildRecipeSnapshot(recipe, color, factor)
                        .animate(delay: 40.ms)
                        .fadeIn(duration: 280.ms)
                        .slideY(begin: 0.05, end: 0),
                  ),
                  SliverToBoxAdapter(
                    child: _buildGoalBadge(
                      goalCompat,
                      recipeKcal,
                      remaining,
                    ).animate(delay: 80.ms).fadeIn(duration: 280.ms),
                  ),
                  SliverToBoxAdapter(
                    child: _buildPortionBar(recipe, color, factor)
                        .animate(delay: 120.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.06, end: 0),
                  ),
                  SliverToBoxAdapter(
                    child: _buildMacroBar(recipe, color, factor)
                        .animate(delay: 160.ms)
                        .fadeIn(duration: 320.ms)
                        .slideY(begin: 0.06, end: 0),
                  ),
                  SliverToBoxAdapter(
                    child: _buildTimeTagRow(
                      recipe,
                      color,
                    ).animate(delay: 200.ms).fadeIn(duration: 320.ms),
                  ),
                  SliverToBoxAdapter(
                    child: _buildIngredients(
                      recipe,
                      color,
                    ).animate(delay: 240.ms).fadeIn(duration: 320.ms),
                  ),
                  SliverToBoxAdapter(
                    child: _buildSteps(
                      recipe,
                      color,
                    ).animate(delay: 280.ms).fadeIn(duration: 320.ms),
                  ),
                  if (similar.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildSimilarRecipes(
                        context,
                        similar,
                        recipeProvider,
                      ).animate(delay: 320.ms).fadeIn(duration: 320.ms),
                    ),
                  SliverToBoxAdapter(child: SizedBox(height: bottomPad + 100)),
                ],
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(color, bottomPad),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Hero ─────────────────────────────────────────────────────────────────

  Widget _buildHeroSliver(
    BuildContext context,
    Recipe recipe,
    Color color,
    double topPad,
    bool isFav,
    RecipeProvider provider,
  ) {
    final cookCount = provider.cookCountFor(recipe.id);
    return SliverToBoxAdapter(
      child: Container(
        height: 260 + topPad,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.55, 1.0],
            colors: [
              color.withValues(alpha: 0.28),
              color.withValues(alpha: 0.08),
              const Color(0xFF08090C),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: _RecipeHeroImage(recipe: recipe, overlayColor: color),
              ),
            ),
            Positioned(
              top: topPad,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.04),
                ),
              ),
            ),
            // Back
            Positioned(
              top: topPad + 8,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: _GlassButton(
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            // Favorite
            Positioned(
              top: topPad + 8,
              right: 16,
              child: GestureDetector(
                onTap: () => provider.toggleFavorite(recipe.id),
                child: AnimatedContainer(
                  duration: 250.ms,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isFav
                        ? const Color(0x33FF4D6D)
                        : Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isFav
                          ? const Color(0xAAFF4D6D)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: AnimatedSwitcher(
                        duration: 250.ms,
                        transitionBuilder: (child, anim) =>
                            ScaleTransition(scale: anim, child: child),
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          key: ValueKey(isFav),
                          color: isFav
                              ? const Color(0xFFFF4D6D)
                              : Colors.white.withValues(alpha: 0.7),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Cook mode button
            Positioned(
              top: topPad + 8,
              right: 112,
              child: GestureDetector(
                onTap: _openCookMode,
                child: _GlassButton(
                  child: const Text('👨‍🍳', style: TextStyle(fontSize: 16)),
                ),
              ),
            ),
            // Share button
            Positioned(
              top: topPad + 8,
              right: 64,
              child: GestureDetector(
                onTap: () {
                  final text = 'Harika bir tarif buldum: ${recipe.name}! 🍲\n\n'
                      'Sadece ${recipe.kcalPerServing.toInt()} kcal ve ${recipe.proteinPerServing.toInt()}g protein içeriyor.\n\n'
                      'Hemen FitMentor\'da dene!';
                  Share.share(text);
                },
                child: _GlassButton(
                  child: const Icon(
                    Icons.ios_share_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            // Cook count badge
            if (cookCount > 0)
              Positioned(
                top: topPad + 8,
                left: 64,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('👨‍🍳', style: TextStyle(fontSize: 11)),
                          const SizedBox(width: 4),
                          Text(
                            '$cookCount kez',
                            style: GoogleFonts.dmSans(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Title
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Column(
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
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.15,
                        ),
                      )
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideX(begin: -0.03, end: 0),
                  if (recipe.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      recipe.description,
                      style: GoogleFonts.dmSans(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 13,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ).animate(delay: 60.ms).fadeIn(duration: 300.ms),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Goal Badge ───────────────────────────────────────────────────────────

  Widget _buildRecipeSnapshot(Recipe recipe, Color color, double factor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111318),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (recipe.description.isNotEmpty) ...[
              Text(
                'Tarif Özeti',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.42),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                recipe.description,
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Row(
              children: [
                Expanded(
                  child: _SnapshotStat(
                    icon: Icons.timer_outlined,
                    label: 'Toplam Süre',
                    value: '${recipe.totalTimeMinutes} dk',
                    accent: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SnapshotStat(
                    icon: Icons.shopping_basket_outlined,
                    label: 'Malzeme',
                    value: '${recipe.ingredients.length} ürün',
                    accent: const Color(0xFF4FACFE),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _SnapshotStat(
                    icon: Icons.local_fire_department_outlined,
                    label: 'Zorluk',
                    value: recipe.difficulty,
                    accent: recipe.difficulty == 'kolay'
                        ? AppColors.primaryLight
                        : recipe.difficulty == 'zor'
                        ? AppColors.error
                        : Colors.orange,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SnapshotStat(
                    icon: Icons.people_outline_rounded,
                    label: 'Ölçek',
                    value: '${(factor * 100).round()}%',
                    accent: const Color(0xFFFFD166),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalBadge(
    GoalCompatibility compat,
    double recipeKcal,
    double remaining,
  ) {
    if (compat == GoalCompatibility.fits) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Günlük hedefinize uyuyor! ${recipeKcal.toInt()} kcal, ${remaining.toInt()} kcal kalan',
                  style: GoogleFonts.dmSans(
                    color: AppColors.primaryLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (compat == GoalCompatibility.high) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kalan kalori hedefinizi (${remaining.toInt()} kcal) aşıyor',
                  style: GoogleFonts.dmSans(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Text('📅', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Bugünkü hedef dolu görünüyor. Bu tarifi alışveriş listesine ekleyip daha sonra planlayabilirsin.',
                style: GoogleFonts.dmSans(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Portion Bar ─────────────────────────────────────────────────────────

  Widget _buildPortionBar(Recipe recipe, Color color, double factor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF161820),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Icon(Icons.people_outline_rounded, color: color, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Porsiyon',
                    style: GoogleFonts.dmSans(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$_portions kişilik',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Besin değerleri ${factor.toStringAsFixed(1)}x ölçekleniyor',
                    style: GoogleFonts.dmSans(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _StepperButton(
                  icon: Icons.remove_rounded,
                  color: color,
                  enabled: _portions > 1,
                  onTap: () {
                    if (_portions > 1) setState(() => _portions--);
                  },
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: 200.ms,
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Text(
                      '$_portions',
                      key: ValueKey(_portions),
                      style: GoogleFonts.dmSans(
                        color: color,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                _StepperButton(
                  icon: Icons.add_rounded,
                  color: color,
                  enabled: _portions < 20,
                  onTap: () {
                    if (_portions < 20) setState(() => _portions++);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Macro bar ────────────────────────────────────────────────────────────

  Widget _buildMacroBar(Recipe recipe, Color color, double factor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161820).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _MacroCell(
                      value: '${(recipe.kcalPerServing * factor).toInt()}',
                      label: 'kcal',
                      color: Colors.orange,
                      icon: Icons.bolt_rounded,
                    ),
                    _vDivider(),
                    _MacroCell(
                      value: '${(recipe.proteinPerServing * factor).toInt()}g',
                      label: 'Protein',
                      color: AppColors.primaryLight,
                      icon: Icons.fitness_center_rounded,
                    ),
                    _vDivider(),
                    _MacroCell(
                      value: '${(recipe.carbPerServing * factor).toInt()}g',
                      label: 'Karb',
                      color: const Color(0xFF4FACFE),
                      icon: Icons.grain_rounded,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.07),
                    height: 1,
                  ),
                ),
                Row(
                  children: [
                    _MacroCell(
                      value: '${(recipe.fatPerServing * factor).toInt()}g',
                      label: 'Yağ',
                      color: const Color(0xFFFFD166),
                      icon: Icons.water_drop_rounded,
                    ),
                    _vDivider(),
                    _MacroCell(
                      value:
                          '${(recipe.fiberPerServing * factor).toStringAsFixed(1)}g',
                      label: 'Lif',
                      color: Colors.greenAccent,
                      icon: Icons.eco_rounded,
                    ),
                    _vDivider(),
                    _MacroCell(
                      value:
                          '${(recipe.sugarPerServing * factor).toStringAsFixed(1)}g',
                      label: 'Şeker',
                      color: Colors.pinkAccent,
                      icon: Icons.cookie_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _vDivider() => Container(
    width: 1,
    height: 40,
    color: Colors.white.withValues(alpha: 0.07),
  );

  // ─── Time + Tags ─────────────────────────────────────────────────────────

  Widget _buildTimeTagRow(Recipe recipe, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _InfoPill(
            icon: Icons.timer_outlined,
            label: [
              if (recipe.prepTimeMinutes > 0)
                '${recipe.prepTimeMinutes}dk hazırlık',
              if (recipe.cookTimeMinutes > 0)
                '${recipe.cookTimeMinutes}dk pişirme',
            ].join('  ·  '),
            color: color,
          ),
          _InfoPill(
            icon: Icons.people_outline_rounded,
            label: '$_portions kişilik tarif',
            color: const Color(0xFF4FACFE),
          ),
          _DifficultyPill(difficulty: recipe.difficulty),
          ...recipe.tags.map((t) => _TagPill(label: t, color: color)),
        ],
      ),
    );
  }

  // ─── Ingredients ─────────────────────────────────────────────────────────

  Widget _buildIngredients(Recipe recipe, Color color) {
    final scaledIngredients = recipe.scaledIngredientsFor(_portions);
    final progress = scaledIngredients.isEmpty
        ? 0.0
        : _checkedIngredients.length / scaledIngredients.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            emoji: '🛒',
            title: 'Malzemeler',
            trailing: '${recipe.ingredients.length} ürün · $_portions porsiyon',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1117),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      _checkedIngredients.isEmpty
                          ? 'Hazırlığa başla'
                          : 'Hazırlık ilerlemesi',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(progress * 100).round()}%',
                      style: GoogleFonts.dmSans(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161820),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              children: scaledIngredients.asMap().entries.map((e) {
                final i = e.key;
                final ing = e.value;
                final checked = _checkedIngredients.contains(i);
                return _IngredientRow(
                  ingredient: ing,
                  isLast: i == scaledIngredients.length - 1,
                  checked: checked,
                  color: color,
                  onTap: () => setState(
                    () => checked
                        ? _checkedIngredients.remove(i)
                        : _checkedIngredients.add(i),
                  ),
                );
              }).toList(),
            ),
          ),
          if (_checkedIngredients.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_checkedIngredients.length}/${recipe.ingredients.length} malzeme hazır',
                style: GoogleFonts.dmSans(
                  color: color.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Steps ───────────────────────────────────────────────────────────────

  Widget _buildSteps(Recipe recipe, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            emoji: '📋',
            title: 'Yapılış',
            trailing: '${recipe.steps.length} adım',
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFF111318),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Adım adım mod hazır',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${recipe.steps.length} adım boyunca zamanlayıcıyla ilerleyebilirsin.',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.48),
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _openCookMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.26)),
                    ),
                    child: Text(
                      'Başlat',
                      style: GoogleFonts.dmSans(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...recipe.steps.asMap().entries.map((e) {
            final i = e.key;
            return _StepRow(
                  stepNumber: i + 1,
                  text: e.value,
                  color: color,
                  isLast: i == recipe.steps.length - 1,
                )
                .animate(delay: Duration(milliseconds: 40 * i))
                .fadeIn(duration: 240.ms)
                .slideX(begin: 0.04, end: 0);
          }),
        ],
      ),
    );
  }

  // ─── Similar Recipes ──────────────────────────────────────────────────────

  Widget _buildSimilarRecipes(
    BuildContext context,
    List<Recipe> similar,
    RecipeProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SectionHeader(
              emoji: '🍴',
              title: 'Benzer Tarifler',
              trailing: '${similar.length} tarif',
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 160,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: similar.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final r = similar[i];
                final c = _catColor(r.category);
                return GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailPage(recipe: r),
                    ),
                  ),
                  child:
                      Container(
                            width: 130,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  c.withValues(alpha: 0.2),
                                  const Color(0xFF0F1015),
                                ],
                              ),
                              border: Border.all(
                                color: c.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      10,
                                      10,
                                      0,
                                    ),
                                    child: _RecipeImageCard(
                                      recipe: r,
                                      borderRadius: 14,
                                      emojiSize: 40,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    6,
                                    8,
                                    8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        r.name,
                                        style: GoogleFonts.dmSans(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${r.kcalPerServing.toInt()} kcal · ${r.totalTimeMinutes}dk',
                                        style: GoogleFonts.dmSans(
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate(delay: Duration(milliseconds: 60 * i))
                          .fadeIn(duration: 250.ms)
                          .slideX(begin: 0.08, end: 0),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(Color color, double bottomPad) {
    final recipe = widget.recipe;
    final factor = _portions / recipe.servings;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
          decoration: BoxDecoration(
            color: const Color(0xFF08090C).withValues(alpha: 0.85),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _BottomMetricChip(
                      icon: Icons.local_fire_department_outlined,
                      label: '${(recipe.kcalPerServing * factor).toInt()} kcal',
                      accent: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _BottomMetricChip(
                      icon: Icons.fitness_center_rounded,
                      label:
                          '${(recipe.proteinPerServing * factor).toInt()}g protein',
                      accent: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: LinearGradient(
                            colors: [
                              color,
                              Color.lerp(color, Colors.black, 0.3)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _addingToMeal ? null : _showAddToMealSheet,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          icon: _addingToMeal
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.black,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 18,
                                  color: Colors.black,
                                ),
                          label: Text(
                            'Öğüne Ekle',
                            style: GoogleFonts.dmSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openShoppingList,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1D25),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                      ),
                      icon: const Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: Text(
                        'Liste',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
    );
  }
}

// ─── Goal Compat enum ────────────────────────────────────────────────────────

enum GoalCompatibility { fits, high, exceeded }

// ─── Glass Button ─────────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _SnapshotStat extends StatelessWidget {
  const _SnapshotStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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

class _RecipeHeroImage extends StatelessWidget {
  const _RecipeHeroImage({required this.recipe, required this.overlayColor});

  final Recipe recipe;
  final Color overlayColor;

  @override
  Widget build(BuildContext context) {
    if (!recipe.hasImageAsset) {
      return Center(
        child: Text(
          recipe.imageEmoji,
          style: const TextStyle(fontSize: 90),
        ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          recipe.imageAsset!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(
            child: Text(
              recipe.imageEmoji,
              style: const TextStyle(fontSize: 90),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.18),
                overlayColor.withValues(alpha: 0.18),
                const Color(0xFF08090C).withValues(alpha: 0.92),
              ],
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _RecipeImageCard extends StatelessWidget {
  const _RecipeImageCard({
    required this.recipe,
    required this.borderRadius,
    required this.emojiSize,
  });

  final Recipe recipe;
  final double borderRadius;
  final double emojiSize;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: recipe.hasImageAsset
            ? Image.asset(
                recipe.imageAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(
                  child: Text(
                    recipe.imageEmoji,
                    style: TextStyle(fontSize: emojiSize),
                  ),
                ),
              )
            : Center(
                child: Text(
                  recipe.imageEmoji,
                  style: TextStyle(fontSize: emojiSize),
                ),
              ),
      ),
    );
  }
}

class _BottomMetricChip extends StatelessWidget {
  const _BottomMetricChip({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stepper Button ───────────────────────────────────────────────────────────

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: 150.ms,
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? color.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Icon(
          icon,
          color: enabled ? color : Colors.white.withValues(alpha: 0.2),
          size: 16,
        ),
      ),
    );
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
    ),
    child: Text(
      label.toUpperCase(),
      style: GoogleFonts.dmSans(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _MacroCell extends StatelessWidget {
  const _MacroCell({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });
  final String value, label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: 200.ms,
          child: Text(
            value,
            key: ValueKey(value),
            style: GoogleFonts.dmSans(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
          ),
        ),
      ],
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.emoji,
    required this.title,
    required this.trailing,
  });
  final String emoji, title, trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(emoji, style: const TextStyle(fontSize: 18)),
      const SizedBox(width: 8),
      Text(
        title,
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      const Spacer(),
      Text(
        trailing,
        style: GoogleFonts.dmSans(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 12,
        ),
      ),
    ],
  );
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _DifficultyPill extends StatelessWidget {
  const _DifficultyPill({required this.difficulty});
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

  String get _flames {
    switch (difficulty) {
      case 'kolay':
        return '🔥';
      case 'orta':
        return '🔥🔥';
      case 'zor':
        return '🔥🔥🔥';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withValues(alpha: 0.2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_flames, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 4),
        Text(
          difficulty,
          style: GoogleFonts.dmSans(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFF161820),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    child: Text(
      label,
      style: GoogleFonts.dmSans(
        color: Colors.white.withValues(alpha: 0.55),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.isLast,
    required this.checked,
    required this.color,
    required this.onTap,
  });
  final RecipeIngredient ingredient;
  final bool isLast, checked;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: 200.ms,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: checked ? color.withValues(alpha: 0.06) : Colors.transparent,
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: 200.ms,
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: checked
                  ? color.withValues(alpha: 0.2)
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: checked
                    ? color.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1.5,
              ),
            ),
            child: checked
                ? Icon(Icons.check_rounded, color: color, size: 13)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ingredient.name,
              style: GoogleFonts.dmSans(
                color: checked
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: checked ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white.withValues(alpha: 0.3),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: 200.ms,
            child: Text(
              ingredient.displayAmount,
              key: ValueKey(ingredient.displayAmount),
              style: GoogleFonts.dmSans(
                color: checked
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.stepNumber,
    required this.text,
    required this.color,
    required this.isLast,
  });
  final int stepNumber;
  final String text;
  final Color color;
  final bool isLast;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.3),
                    color.withValues(alpha: 0.12),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Center(
                child: Text(
                  '$stepNumber',
                  style: GoogleFonts.dmSans(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Expanded(
                child: Container(
                  width: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 5, bottom: isLast ? 0 : 18),
            child: Text(
              text,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── Cook Mode Page ───────────────────────────────────────────────────────────

class _CookModePage extends StatefulWidget {
  const _CookModePage({required this.recipe});
  final Recipe recipe;
  @override
  State<_CookModePage> createState() => _CookModePageState();
}

class _CookModePageState extends State<_CookModePage> {
  int _currentStep = 0;
  late Stopwatch _stopwatch;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      if (_timerRunning) {
        _stopwatch.stop();
        _timerRunning = false;
      } else {
        _stopwatch.start();
        _timerRunning = true;
        _tickTimer();
      }
    });
  }

  void _tickTimer() {
    if (!_timerRunning || !mounted) return;
    setState(() {});
    Future.delayed(const Duration(seconds: 1), _tickTimer);
  }

  void _resetTimer() => setState(() {
    _stopwatch.reset();
    _timerRunning = false;
  });

  void _showCompletionSheet(BuildContext context, Color color) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Tarif tamamlandı!',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.recipe.name,
              style: GoogleFonts.dmSans(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    colors: [color, Color.lerp(color, Colors.black, 0.3)!],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.read<RecipeProvider>().markCooked(widget.recipe.id);
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.black,
                    size: 20,
                  ),
                  label: Text(
                    'Yaptım olarak kaydet',
                    style: GoogleFonts.dmSans(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                child: Text(
                  'Kapat',
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _elapsed {
    final s = _stopwatch.elapsed.inSeconds;
    final m = s ~/ 60;
    return '${m.toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final color = _catColor(recipe.category);
    final step = recipe.steps[_currentStep];
    final isLast = _currentStep == recipe.steps.length - 1;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.06),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1D25),
                            title: Text(
                              'Pişirmeden Çık?',
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: Text(
                              'İlerlemen kaybolacak.',
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Devam Et',
                                  style: GoogleFonts.dmSans(
                                    color: AppColors.primaryLight,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  'Çık',
                                  style: GoogleFonts.dmSans(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                        child: _GlassButton(
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pişirme Modu 👨‍🍳',
                              style: GoogleFonts.dmSans(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              recipe.name,
                              style: GoogleFonts.dmSans(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Step progress
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: Row(
                    children: List.generate(
                      recipe.steps.length,
                      (i) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: i < recipe.steps.length - 1 ? 4 : 0,
                          ),
                          child: AnimatedContainer(
                            duration: 300.ms,
                            height: 4,
                            decoration: BoxDecoration(
                              color: i <= _currentStep
                                  ? color
                                  : Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Step number
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_currentStep + 1}',
                        style: GoogleFonts.dmSans(
                          color: color,
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/${recipe.steps.length}',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Step text (main content)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: AnimatedSwitcher(
                      duration: 350.ms,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.05, 0),
                            end: Offset.zero,
                          ).animate(anim),
                          child: child,
                        ),
                      ),
                      child: Text(
                        step,
                        key: ValueKey(_currentStep),
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ),

                // Timer
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161820),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, color: color, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          _elapsed,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            fontFeatures: [const FontFeature.tabularFigures()],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _toggleTimer,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _timerRunning ? 'Durdur' : 'Başlat',
                              style: GoogleFonts.dmSans(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _resetTimer,
                          child: Icon(
                            Icons.restart_alt_rounded,
                            color: Colors.white.withValues(alpha: 0.35),
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Navigation buttons
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 12),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _currentStep--;
                              _resetTimer();
                            }),
                            child: Container(
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1D25),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chevron_left_rounded,
                                    color: Colors.white.withValues(alpha: 0.6),
                                    size: 20,
                                  ),
                                  Text(
                                    'Önceki',
                                    style: GoogleFonts.dmSans(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 10),
                      Expanded(
                        flex: isLast ? 1 : 2,
                        child: GestureDetector(
                          onTap: () {
                            if (isLast) {
                              _stopwatch.stop();
                              _showCompletionSheet(context, color);
                            } else {
                              setState(() {
                                _currentStep++;
                                _resetTimer();
                              });
                            }
                          },
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                colors: [
                                  color,
                                  Color.lerp(color, Colors.black, 0.3)!,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLast ? '🎉 Tamamla' : 'Sonraki',
                                  style: GoogleFonts.dmSans(
                                    color: Colors.black,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (!isLast) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.black,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
