import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../../../core/utils/app_snack.dart';

/// Porsiyon gir: gram, öğün seçimi, makro önizleme, Günlüğe ekle.
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

class _PortionAddPageState extends State<PortionAddPage> {
  late TextEditingController _gramController;
  MealType _mealType = MealType.breakfast;
  double _calculatedKcal = 0;
  double _protein = 0;
  double _carb = 0;
  double _fat = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialGrams ?? 100.0;
    _gramController = TextEditingController(text: initial.roundToDouble().toStringAsFixed(initial == initial.roundToDouble() ? 0 : 1));
    if (widget.selectedMealType != null) _mealType = widget.selectedMealType!;
    _gramController.addListener(_recalc);
    _recalc();
  }

  void _recalc() {
    final g = double.tryParse(_gramController.text.replaceAll(',', '.')) ?? 0;
    final ratio = g / 100;
    if (mounted) {
      setState(() {
        _calculatedKcal = (widget.food.kcalPer100g * ratio);
        _protein = widget.food.proteinPer100g * ratio;
        _carb = widget.food.carbPer100g * ratio;
        _fat = widget.food.fatPer100g * ratio;
      });
    }
  }

  void _setGrams(double g) {
    _gramController.text = g == g.roundToDouble() ? g.toInt().toString() : g.toStringAsFixed(1);
  }

  /// Varsayılan 1 porsiyon gramı (serving'deki default veya ilk, yoksa 100g).
  double get _defaultPortionGrams {
    if (widget.food.servings.isEmpty) {
      // Kategori bazlı varsayılan kullan
      final category = widget.food.tags.isNotEmpty ? widget.food.tags.first : null;
      return DietProvider.getCategoryDefaultGrams(category);
    }
    final def = widget.food.servings.where((s) => s.isDefault).toList();
    return (def.isNotEmpty ? def.first : widget.food.servings.first).grams;
  }

  @override
  void dispose() {
    _gramController.removeListener(_recalc);
    _gramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            try {
              Navigator.of(context, rootNavigator: false).pop();
            } catch (e) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          widget.food.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      extendBodyBehindAppBar: true,
      body: AppGradientBackground(
        imagePath: 'assets/images/nutrition_bg.jpg',
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                _buildGramSection(),
                const SizedBox(height: 14),
                _buildPortionEstimateChips(),
                const SizedBox(height: 14),
                _buildQuickGramChips(),
                if (widget.food.servings.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildServingsChips(),
                ],
                const SizedBox(height: 20),
                _buildMacroPreview(),
                const SizedBox(height: 24),
                Text(
                  'Öğün',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _buildMealTypeChips(),
                const Spacer(),
                SizedBox(
                  height: 52,
                  child: AppButton.primary(
                    onPressed: _addToDiary,
                    text: 'Günlüğe ekle',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGramSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              final g = (double.tryParse(_gramController.text) ?? 0) - 25;
              _setGrams(g < 0 ? 0 : g);
              _recalc();
            },
            icon: const Icon(Icons.remove_circle_outline, color: Colors.white70),
          ),
          Expanded(
            child: TextField(
              controller: _gramController,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => _recalc(),
            ),
          ),
          IconButton(
            onPressed: () {
              final g = (double.tryParse(_gramController.text) ?? 0) + 25;
              _setGrams(g);
              _recalc();
            },
            icon: const Icon(Icons.add_circle_outline, color: Colors.white70),
          ),
          const SizedBox(width: 8),
          Text(
            'gram',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionEstimateChips() {
    final base = _defaultPortionGrams;
    
    // Eğer adet varsa "1 Adet" yazdır
    String defaultLabel = 'Normal';
    final adets = widget.food.servings.where((s) => s.label.toLowerCase().contains('adet')).toList();
    if (adets.isNotEmpty) {
      defaultLabel = '1 Adet (${adets.first.grams.round()}g)';
    }

    final options = [
      (0.5, 'Yarım', base * 0.5),
      (1.0, defaultLabel, base),
      (2.0, 'Çift', base * 2),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Porsiyon tahmini',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final (_, label, grams) = opt;
            final g = grams.roundToDouble();
            final current = double.tryParse(_gramController.text.replaceAll(',', '.')) ?? 0;
            final isSelected = (current - g).abs() < 1 || current == g;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _setGrams(g),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    '$label (${g.toInt()}g)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primaryLight : Colors.white70,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildQuickGramChips() {
    const values = [50.0, 100.0, 150.0, 200.0];
    return Row(
      children: values.map((v) {
        final isSelected = (double.tryParse(_gramController.text.replaceAll(',', '.')) ?? 0) == v;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _setGrams(v),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  '${v.toInt()}g',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primaryLight : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildServingsChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.food.servings.map((s) {
        return ActionChip(
          label: Text(s.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
          onPressed: () {
            _setGrams(s.grams.toDouble());
          },
          backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
          side: BorderSide(color: AppColors.secondary.withValues(alpha: 0.4)),
        );
      }).toList(),
    );
  }

  Widget _buildMacroPreview() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _macroItem('Kalori', '${_calculatedKcal.round()}', 'kcal', AppColors.secondary),
          _macroItem('Protein', _protein.toStringAsFixed(1), 'g', const Color(0xFF5B9BFF)),
          _macroItem('Karb.', _carb.toStringAsFixed(1), 'g', const Color(0xFF4CD1A3)),
          _macroItem('Yağ', _fat.toStringAsFixed(1), 'g', const Color(0xFFFFB74D)),
        ],
      ),
    );
  }

  Widget _macroItem(String label, String value, String unit, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value $unit',
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMealTypeChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: MealType.values.map((type) {
          final isSelected = _mealType == type;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _mealType = type),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primaryLight : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _addToDiary() async {
    final grams = double.tryParse(_gramController.text.replaceAll(',', '.'));
    if (grams == null || grams <= 0 || grams.isNaN || grams.isInfinite) {
      AppSnack.showError(context, 'Geçerli bir gram girin.');
      return;
    }
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final date = provider.selectedDate;
      await provider.addEntry(food: widget.food, grams: grams, mealType: _mealType, date: date);
      if (mounted) {
        AppSnack.showSuccess(context, 'Günlüğe eklendi.');
        try {
          Navigator.of(context, rootNavigator: false).pop();
        } catch (e) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnack.showError(context, 'Eklenirken hata oluştu: ${e.toString()}');
      }
    }
  }
}
