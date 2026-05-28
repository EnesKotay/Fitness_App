import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../state/diet_provider.dart';
import '../../../tasks/controllers/daily_tasks_controller.dart';
import '../../../tasks/models/daily_task.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../../../core/utils/app_snack.dart';

// Widgets
import '../widgets/portion/portion_utils.dart';
import '../widgets/portion/food_hero_card.dart';
import '../widgets/portion/quick_portion_card.dart';
import '../widgets/portion/advanced_adjustments_card.dart';
import '../widgets/portion/macro_and_meal_cards.dart';

class PortionAddPage extends StatefulWidget {
  final FoodItem food;
  final MealType? selectedMealType;
  final double? initialGrams;

  const PortionAddPage({
    super.key,
    required this.food,
    this.selectedMealType,
    this.initialGrams,
  });

  @override
  State<PortionAddPage> createState() => _PortionAddPageState();
}

class _PortionAddPageState extends State<PortionAddPage>
    with SingleTickerProviderStateMixin {
  late TextEditingController _gramController;
  MealType _mealType = MealType.breakfast;
  double _calculatedKcal = 0;
  double _protein = 0;
  double _carb = 0;
  double _fat = 0;
  double _sliderValue = 100;
  bool _isAdding = false;

  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut);

    final initial = widget.initialGrams ?? 100.0;
    _gramController = TextEditingController(
      text: initial.roundToDouble().toStringAsFixed(
        initial == initial.roundToDouble() ? 0 : 1,
      ),
    );
    _sliderValue = initial.clamp(0, double.infinity);
    if (widget.selectedMealType != null) _mealType = widget.selectedMealType!;
    _gramController.addListener(_recalc);
    _recalc();
  }

  void _recalc() {
    final g = double.tryParse(_gramController.text.replaceAll(',', '.')) ?? 0;
    final ratio = g / 100;
    if (mounted) {
      setState(() {
        _calculatedKcal = widget.food.kcalPer100g * ratio;
        _protein = widget.food.proteinPer100g * ratio;
        _carb = widget.food.carbPer100g * ratio;
        _fat = widget.food.fatPer100g * ratio;
        final clamped = g.clamp(0.0, _sliderMax);
        if ((_sliderValue - clamped).abs() > 1) _sliderValue = clamped;
      });
    }
  }

  void _setGrams(double g) {
    HapticFeedback.selectionClick();
    _gramController.text = g == g.roundToDouble()
        ? g.toInt().toString()
        : g.toStringAsFixed(1);
    setState(() => _sliderValue = g.clamp(0, _sliderMax));
    _recalc();
  }

  double get _sliderMax {
    final maxServing = widget.food.servings.isNotEmpty
        ? widget.food.servings
              .map((s) => s.grams)
              .reduce((a, b) => a > b ? a : b)
        : 0.0;
    return [
      500.0,
      maxServing * 2,
      _defaultPortionGrams * 3,
    ].reduce((a, b) => a > b ? a : b);
  }

  double get _defaultPortionGrams {
    return DietProvider.getDefaultPortionForFood(widget.food);
  }

  double get _currentGrams {
    return double.tryParse(_gramController.text.replaceAll(',', '.')) ?? 0;
  }

  @override
  void dispose() {
    _gramController.removeListener(_recalc);
    _gramController.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: Padding(
          padding: const EdgeInsets.all(10),
          child: GestureDetector(
            onTap: () {
              try {
                Navigator.of(context, rootNavigator: false).pop();
              } catch (_) {
                Navigator.of(context).pop();
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Text(
          widget.food.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AppGradientBackground(
        imagePath: 'assets/images/nutrition_bg_dark.png',
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FoodHeroCard(
                        food: widget.food,
                        ringAnim: _ringAnim,
                        currentGrams: _currentGrams,
                        calculatedKcal: _calculatedKcal,
                        calculatedProtein: _protein,
                        calculatedCarb: _carb,
                        calculatedFat: _fat,
                      ),
                      if (_calculatedKcal > 0) ...[
                        const SizedBox(height: 10),
                        _GoalContributionRow(
                          kcal: _calculatedKcal,
                          protein: _protein,
                        ),
                      ],
                      const SizedBox(height: 14),
                      QuickPortionCard(
                        food: widget.food,
                        currentGrams: _currentGrams,
                        calculatedKcal: _calculatedKcal,
                        defaultPortionGrams: _defaultPortionGrams,
                        onGramsSelected: _setGrams,
                      ),
                      const SizedBox(height: 14),
                      AdvancedAdjustmentsCard(
                        gramController: _gramController,
                        currentGrams: _currentGrams,
                        sliderValue: _sliderValue,
                        sliderMax: _sliderMax,
                        onGramsSelected: _setGrams,
                      ),

                      MealTypeCard(
                        selectedMealType: _mealType,
                        onMealTypeSelected: (type) => setState(() => _mealType = type),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              _buildAddButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Add to diary ──────────────────────────────────────────────
  Widget _buildAddButton() {
    // Generate selected friendly title to put into Add Button
    String amountTitle = 'Bilinmiyor';
    final current = _currentGrams;
    bool found = false;

    // attempt preset titles
    final presets = PortionUtils.buildUserFriendlyPresets(widget.food, _defaultPortionGrams);
    for (final preset in presets) {
      if ((preset.$3 - current).abs() < 1) {
        amountTitle = PortionUtils.displayPresetTitle(preset.$1, widget.food);
        found = true;
        break;
      }
    }

    if (!found) {
      for (final serving in widget.food.servings) {
        if ((serving.grams - current).abs() < 1) {
          amountTitle = PortionUtils.displayServingLabel(serving.label);
          found = true;
          break;
        }
      }
    }

    if (!found) {
      final unit = DietProvider.getSmartUnit(widget.food.name, widget.food.category);
      if (current <= 0) {
        amountTitle = 'Miktar seç';
      } else {
        final ratio = current / (_defaultPortionGrams <= 0 ? 100 : _defaultPortionGrams);
        if ((ratio - 0.5).abs() < 0.1) {
          amountTitle = 'Yarım $unit';
        } else if ((ratio - 1).abs() < 0.1) {
          amountTitle = '1 $unit';
        } else if ((ratio - 1.5).abs() < 0.1) {
          amountTitle = '1,5 $unit';
        } else if ((ratio - 2).abs() < 0.15) {
          amountTitle = '2 $unit';
        } else {
          amountTitle = '${ratio.toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')} $unit';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.background.withValues(alpha: 0.9),
            AppColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.4, 1.0],
        ),
      ),
      child: GestureDetector(
        onTap: _isAdding ? null : _addToDiary,
        child: AnimatedOpacity(
          opacity: _isAdding ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF27AE60).withValues(alpha: 0.40),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _isAdding
              ? const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Günlüğe Ekle',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$amountTitle • ${_calculatedKcal.round()} kcal',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  Future<void> _addToDiary() async {
    if (_isAdding) return;
    final grams = double.tryParse(_gramController.text.replaceAll(',', '.'));
    if (grams == null || grams <= 0 || grams.isNaN || grams.isInfinite) {
      AppSnack.showError(context, 'Lütfen bir porsiyon veya miktar seç.');
      return;
    }
    setState(() => _isAdding = true);
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final entryId = await provider.addEntry(
        food: widget.food,
        grams: grams,
        mealType: _mealType,
        date: provider.selectedDate,
      );
      if (mounted) {
        unawaited(
          context.read<DailyTasksController>().autoCompleteFirstUndoneByCategory(TaskCategory.nutrition),
        );
        final messenger = ScaffoldMessenger.of(context);
        try {
          Navigator.of(context, rootNavigator: false).pop();
        } catch (_) {
          Navigator.of(context).pop();
        }
        if (entryId.isNotEmpty) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                '${widget.food.name} eklendi',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              backgroundColor: const Color(0xFF27AE60),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Geri Al',
                textColor: Colors.white,
                onPressed: () {
                  provider.deleteEntry(entryId);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdding = false);
        AppSnack.showError(context, 'Eklenirken hata oluştu: ${e.toString()}');
      }
    }
  }
}

/// Günlük kalori ve protein hedefine bu porsiyonun katkısını gösteren küçük şerit.
class _GoalContributionRow extends StatelessWidget {
  final double kcal;
  final double protein;

  const _GoalContributionRow({required this.kcal, required this.protein});

  @override
  Widget build(BuildContext context) {
    final diet = context.watch<DietProvider>();
    final targetKcal = diet.effectiveTargetKcal.clamp(1.0, double.infinity);
    final targetProtein = diet.macroTargets.protein.clamp(1.0, double.infinity);
    final alreadyKcal = diet.totals.totalKcal;

    final kcalPct = (kcal / targetKcal * 100).clamp(0.0, 999.0);
    final proteinPct = (protein / targetProtein * 100).clamp(0.0, 999.0);
    final remainKcal = (targetKcal - alreadyKcal - kcal).clamp(0.0, targetKcal);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ContribChip(
              label: 'Kalori',
              pct: kcalPct,
              color: const Color(0xFFFF6B6B),
              suffix: '${kcal.round()} kcal',
            ),
          ),
          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: _ContribChip(
              label: 'Protein',
              pct: proteinPct,
              color: const Color(0xFF5B9BFF),
              suffix: '${protein.toStringAsFixed(1)}g',
            ),
          ),
          Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.08)),
          Expanded(
            child: _ContribChip(
              label: 'Kalan',
              pct: null,
              color: const Color(0xFF4CD1A3),
              suffix: '${remainKcal.round()} kcal',
            ),
          ),
        ],
      ),
    );
  }
}

class _ContribChip extends StatelessWidget {
  final String label;
  final double? pct;
  final Color color;
  final String suffix;

  const _ContribChip({
    required this.label,
    required this.pct,
    required this.color,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          pct != null ? '%${pct!.round()}' : suffix,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (pct != null) ...[
          const SizedBox(height: 3),
          Text(
            suffix,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.30),
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
