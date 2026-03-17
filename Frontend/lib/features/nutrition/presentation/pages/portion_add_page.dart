import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../../../core/utils/app_snack.dart';

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

  late AnimationController _ringCtrl;
  late Animation<double> _ringAnim;

  static const _proteinColor = Color(0xFF5B9BFF);
  static const _carbColor = Color(0xFF4CD1A3);
  static const _fatColor = Color(0xFFFFB74D);

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
                      _buildFoodHeroCard(),
                      const SizedBox(height: 14),
                      _buildAmountCard(),
                      const SizedBox(height: 14),
                      if (widget.food.servings.isNotEmpty) ...[
                        _buildServingsCard(),
                        const SizedBox(height: 14),
                      ],
                      _buildPortionPresetsCard(),
                      const SizedBox(height: 14),
                      _buildMacroCard(),
                      const SizedBox(height: 14),
                      _buildMealTypeCard(),
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

  // ─── Food Hero Card ────────────────────────────────────────────
  Widget _buildFoodHeroCard() {
    final food = widget.food;
    final badges = <(String, Color)>[];
    if (food.proteinPer100g >= 20) {
      badges.add(('Yüksek Protein', _proteinColor));
    }
    if (food.carbPer100g < 5) badges.add(('Düşük Karb', _carbColor));
    if (food.fatPer100g < 3) badges.add(('Düşük Yağ', const Color(0xFF8BC34A)));
    if (food.kcalPer100g < 50) badges.add(('Hafif', Colors.white70));

    return _glass(
      radius: 24,
      accentBorder: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated kcal ring
                AnimatedBuilder(
                  animation: _ringAnim,
                  builder: (context2, child2) => SizedBox(
                    width: 80,
                    height: 80,
                    child: CustomPaint(
                      painter: _RingPainter(
                        color: AppColors.secondary,
                        strokeWidth: 3.5,
                        glowOpacity: 0.08 + _ringAnim.value * 0.14,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${food.kcalPer100g.round()}',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                height: 1,
                                letterSpacing: -0.8,
                              ),
                            ),
                            Text(
                              'kcal',
                              style: TextStyle(
                                color: AppColors.secondary.withValues(
                                  alpha: 0.8,
                                ),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '/ 100g',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 5,
                        children: [
                          _badge(
                            food.category.isEmpty ? 'Besin' : food.category,
                            Colors.white.withValues(alpha: 0.5),
                          ),
                          ...badges.map((b) => _badge(b.$1, b.$2)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Macro row
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _macroCol('Protein', food.proteinPer100g, _proteinColor),
                _sep(),
                _macroCol('Karb', food.carbPer100g, _carbColor),
                _sep(),
                _macroCol('Yağ', food.fatPer100g, _fatColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Amount Card ──────────────────────────────────────────────
  Widget _buildAmountCard() {
    return _glass(
      radius: 24,
      accentBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.tune_rounded, 'Miktar Ayarla'),
          const SizedBox(height: 18),

          // Hero gram display
          Row(
            children: [
              _stepBtn(Icons.remove_rounded, () {
                final g = (double.tryParse(_gramController.text) ?? 0) - 25;
                _setGrams(g < 0 ? 0 : g);
              }),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 180),
                          child: TextField(
                            controller: _gramController,
                            textAlign: TextAlign.center,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2.2,
                              height: 1,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (_) => _recalc(),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 6, bottom: 6),
                          child: Text(
                            'g',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.34),
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_calculatedKcal.round()} kcal',
                      style: GoogleFonts.inter(
                        color: AppColors.secondary.withValues(alpha: 0.94),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _stepBtn(Icons.add_rounded, () {
                final g = (double.tryParse(_gramController.text) ?? 0) + 25;
                _setGrams(g);
              }),
            ],
          ),

          const SizedBox(height: 18),
          _buildSlider(),
          const SizedBox(height: 14),
          _buildGramChips(),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.22),
            AppColors.primary.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: AppColors.primaryLight, size: 22),
    ),
  );

  Widget _buildSlider() {
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: AppColors.secondary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.10),
            thumbColor: Colors.white,
            overlayColor: AppColors.secondary.withValues(alpha: 0.15),
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
          ),
          child: Slider(
            value: _sliderValue,
            min: 0,
            max: _sliderMax,
            divisions: (_sliderMax / 5).round().clamp(20, 200),
            onChanged: (v) {
              final rounded = (v / 5).round() * 5.0;
              _setGrams(rounded);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dimText('0g'),
              _dimText('${(_sliderMax / 2).round()}g'),
              _dimText('${_sliderMax.round()}g'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGramChips() {
    const values = [50.0, 100.0, 150.0, 200.0, 250.0, 300.0];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: values.map((v) {
          final isSelected =
              (double.tryParse(_gramController.text.replaceAll(',', '.')) ??
                  0) ==
              v;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _setGrams(v),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppColors.secondary.withValues(alpha: 0.30),
                            AppColors.secondary.withValues(alpha: 0.12),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.secondary
                        : Colors.white.withValues(alpha: 0.10),
                    width: isSelected ? 1.5 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '${v.toInt()}g',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.secondary : Colors.white60,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Standart Ölçüler ──────────────────────────────────────────
  Widget _buildServingsCard() {
    return _glass(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.straighten_rounded, 'Standart Ölçüler'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.food.servings.map((s) {
              final current =
                  double.tryParse(_gramController.text.replaceAll(',', '.')) ??
                  0;
              final isSelected = (current - s.grams).abs() < 1;
              return GestureDetector(
                onTap: () => _setGrams(s.grams.toDouble()),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.secondary.withValues(alpha: 0.28),
                              AppColors.secondary.withValues(alpha: 0.10),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected
                        ? null
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary
                          : Colors.white.withValues(alpha: 0.09),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s.label,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? AppColors.secondary
                              : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${s.grams.round()}g',
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? AppColors.secondary.withValues(alpha: 0.65)
                              : Colors.white.withValues(alpha: 0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── Hızlı Porsiyonlar ─────────────────────────────────────────
  Widget _buildPortionPresetsCard() {
    final presets = _buildUserFriendlyPresets();
    return _glass(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.restaurant_rounded, 'Hızlı Porsiyonlar'),
          const SizedBox(height: 12),
          GridView.builder(
            itemCount: presets.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 2.8,
            ),
            itemBuilder: (context, index) {
              final (label, icon, grams) = presets[index];
              final g = grams.roundToDouble();
              final current =
                  double.tryParse(_gramController.text.replaceAll(',', '.')) ??
                  0;
              final isSelected = (current - g).abs() < 1;

              return GestureDetector(
                onTap: () => _setGrams(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.30),
                              AppColors.primary.withValues(alpha: 0.12),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.05),
                              Colors.white.withValues(alpha: 0.03),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.22)
                              : Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: isSelected
                              ? AppColors.primaryLight
                              : Colors.white54,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '${g.toInt()} g',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : Colors.white.withValues(alpha: 0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─── Macro Card ────────────────────────────────────────────────
  Widget _buildMacroCard() {
    final total = _protein + _carb + _fat;
    final protPct = total > 0 ? (_protein / total * 100).round() : 0;
    final carbPct = total > 0 ? (_carb / total * 100).round() : 0;
    final fatPct = total > 0 ? (_fat / total * 100).round() : 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.22),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated kcal ring
                  AnimatedBuilder(
                    animation: _ringAnim,
                    builder: (c2, ch2) => SizedBox(
                      width: 90,
                      height: 90,
                      child: CustomPaint(
                        painter: _RingPainter(
                          color: AppColors.secondary,
                          strokeWidth: 4,
                          glowOpacity: 0.10 + _ringAnim.value * 0.18,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_calculatedKcal.round()}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                'kcal',
                                style: TextStyle(
                                  color: AppColors.secondary.withValues(
                                    alpha: 0.85,
                                  ),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        if (total > 0) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              children: [
                                if (_protein > 0)
                                  Flexible(
                                    flex: (_protein * 100).round(),
                                    child: Container(
                                      height: 8,
                                      color: _proteinColor,
                                    ),
                                  ),
                                if (_carb > 0)
                                  Flexible(
                                    flex: (_carb * 100).round(),
                                    child: Container(
                                      height: 8,
                                      color: _carbColor,
                                    ),
                                  ),
                                if (_fat > 0)
                                  Flexible(
                                    flex: (_fat * 100).round(),
                                    child: Container(
                                      height: 8,
                                      color: _fatColor,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _macroDetailCol(
                              'Protein',
                              _protein,
                              protPct,
                              _proteinColor,
                            ),
                            _sep(),
                            _macroDetailCol('Karb', _carb, carbPct, _carbColor),
                            _sep(),
                            _macroDetailCol('Yağ', _fat, fatPct, _fatColor),
                          ],
                        ),
                      ],
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

  Widget _macroDetailCol(String label, double grams, int pct, Color color) =>
      Column(
        children: [
          Text(
            '${grams.toStringAsFixed(1)}g',
            style: GoogleFonts.inter(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.50),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$pct%',
            style: TextStyle(
              color: color.withValues(alpha: 0.55),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );

  // ─── Meal Type Card ────────────────────────────────────────────
  Widget _buildMealTypeCard() {
    final items = [
      (MealType.breakfast, Icons.wb_sunny_rounded, 'Kahvaltı'),
      (MealType.lunch, Icons.wb_cloudy_rounded, 'Öğle'),
      (MealType.dinner, Icons.nights_stay_rounded, 'Akşam'),
      (MealType.snack, Icons.cookie_rounded, 'Ara'),
    ];
    return _glass(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(Icons.schedule_rounded, 'Öğün Seç'),
          const SizedBox(height: 12),
          Row(
            children: items.map((item) {
              final (type, icon, label) = item;
              final isSelected = _mealType == type;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _mealType = type),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary.withValues(alpha: 0.32),
                                  AppColors.primary.withValues(alpha: 0.14),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: isSelected
                            ? null
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.65)
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 20,
                            color: isSelected
                                ? AppColors.primaryLight
                                : Colors.white.withValues(alpha: 0.45),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? AppColors.primaryLight
                                  : Colors.white.withValues(alpha: 0.6),
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
        ],
      ),
    );
  }

  // ─── Add Button ────────────────────────────────────────────────
  Widget _buildAddButton() {
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
        onTap: _addToDiary,
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
          child: Row(
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
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_calculatedKcal.round()} kcal',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared Helpers ────────────────────────────────────────────
  Widget _glass({
    required Widget child,
    double radius = 20,
    bool accentBorder = false,
  }) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: accentBorder
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.09),
          ),
          boxShadow: [
            BoxShadow(
              color: accentBorder
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              spreadRadius: -14,
            ),
          ],
        ),
        child: child,
      ),
    ),
  );

  Widget _header(IconData icon, String title) => Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.28),
              AppColors.primary.withValues(alpha: 0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: AppColors.primaryLight, size: 15),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 14.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    ],
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Text(
      label,
      style: GoogleFonts.inter(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _macroCol(String label, double value, Color color) => Column(
    children: [
      Text(
        '${value.round()}g',
        style: GoogleFonts.inter(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  Widget _sep() => Container(
    width: 1,
    height: 30,
    color: Colors.white.withValues(alpha: 0.09),
  );

  Widget _dimText(String t) => Text(
    t,
    style: TextStyle(
      color: Colors.white.withValues(alpha: 0.35),
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
    ),
  );

  // ─── Preset Logic ─────────────────────────────────────────────
  List<(String, IconData, double)> _buildUserFriendlyPresets() {
    final seen = <String>{};
    final presets = <(String, IconData, double)>[];

    void addPreset(String label, IconData icon, double grams) {
      final key = '${label.toLowerCase()}_${grams.round()}';
      if (seen.contains(key)) return;
      seen.add(key);
      presets.add((label, icon, grams));
    }

    final normalizedServings = widget.food.servings
        .map((s) => (label: _normalizeLabel(s.label), grams: s.grams))
        .where((s) => s.label != null)
        .cast<({String label, double grams})>()
        .toList();

    for (final s in normalizedServings) {
      final label = s.label;
      final grams = s.grams;
      final icon = _servingIcon(label);
      addPreset(label, icon, grams);
      final lower = label.toLowerCase();
      if (lower.contains('tabak') ||
          lower.contains('kase') ||
          lower.contains('porsiyon')) {
        addPreset('Yarım ${_unit(label)}', icon, grams * 0.5);
        addPreset('1.5 ${_unit(label)}', icon, grams * 1.5);
        addPreset('2 ${_unit(label)}', icon, grams * 2);
      } else if (lower.contains('çay bardağı') ||
          lower.contains('su bardağı')) {
        addPreset('2 ${_unit(label)}', icon, grams * 2);
        addPreset('3 ${_unit(label)}', icon, grams * 3);
        addPreset('Yarım ${_unit(label)}', icon, grams * 0.5);
      } else if (lower.contains('çorba kaşığı')) {
        addPreset('2 ${_unit(label)}', icon, grams * 2);
        addPreset('3 ${_unit(label)}', icon, grams * 3);
      } else if (lower.contains('adet') ||
          lower.contains('dilim') ||
          lower.contains('bardak')) {
        addPreset('2 ${_unit(label)}', icon, grams * 2);
        addPreset('3 ${_unit(label)}', icon, grams * 3);
      } else if (lower.contains('avuç')) {
        addPreset('2 ${_unit(label)}', icon, grams * 2);
      }
      if (presets.length >= 6) break;
    }

    if (presets.isNotEmpty) {
      presets.sort((a, b) => a.$3.compareTo(b.$3));
      return presets.take(6).toList();
    }

    final base = _defaultPortionGrams;
    return [
      ('Yarım Porsiyon', Icons.pie_chart_outline_rounded, base * 0.5),
      ('1 Porsiyon', Icons.restaurant_rounded, base),
      ('1.5 Porsiyon', Icons.restaurant_menu_rounded, base * 1.5),
      ('2 Porsiyon', Icons.lunch_dining_rounded, base * 2),
    ];
  }

  String? _normalizeLabel(String raw) {
    final label = raw.trim();
    final lower = label.toLowerCase();
    if (lower == '100 g' || lower == '100g') return null;
    return label;
  }

  String _unit(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('çay bardağı')) return 'Çay Bardağı';
    if (lower.contains('su bardağı')) return 'Su Bardağı';
    if (lower.contains('çorba kaşığı')) return 'Çorba K.';
    if (lower.contains('tatlı kaşığı')) return 'Tatlı K.';
    if (lower.contains('çay kaşığı')) return 'Çay K.';
    if (lower.contains('tabak')) return 'Tabak';
    if (lower.contains('kase')) return 'Kase';
    if (lower.contains('adet')) return 'Adet';
    if (lower.contains('dilim')) return 'Dilim';
    if (lower.contains('bardak')) return 'Bardak';
    if (lower.contains('avuç')) return 'Avuç';
    if (lower.contains('demet')) return 'Demet';
    return 'Porsiyon';
  }

  IconData _servingIcon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('çay bardağı')) return Icons.local_cafe_rounded;
    if (lower.contains('su bardağı')) return Icons.local_drink_rounded;
    if (lower.contains('çorba kaşığı')) return Icons.soup_kitchen_rounded;
    if (lower.contains('tatlı kaşığı') || lower.contains('çay kaşığı')) return Icons.restaurant_rounded;
    if (lower.contains('adet')) return Icons.egg_alt_rounded;
    if (lower.contains('tabak')) return Icons.dinner_dining_rounded;
    if (lower.contains('kase')) return Icons.ramen_dining_rounded;
    if (lower.contains('dilim')) return Icons.cake_rounded;
    if (lower.contains('bardak')) return Icons.local_drink_rounded;
    if (lower.contains('avuç')) return Icons.back_hand_rounded;
    if (lower.contains('porsiyon')) return Icons.restaurant_rounded;
    return Icons.restaurant_menu_rounded;
  }

  // ─── Add to diary ──────────────────────────────────────────────
  Future<void> _addToDiary() async {
    final grams = double.tryParse(_gramController.text.replaceAll(',', '.'));
    if (grams == null || grams <= 0 || grams.isNaN || grams.isInfinite) {
      AppSnack.showError(context, 'Geçerli bir gram girin.');
      return;
    }
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      await provider.addEntry(
        food: widget.food,
        grams: grams,
        mealType: _mealType,
        date: provider.selectedDate,
      );
      if (mounted) {
        AppSnack.showSuccess(context, 'Günlüğe eklendi.');
        try {
          Navigator.of(context, rootNavigator: false).pop();
        } catch (_) {
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

// ─── Ring Painter ──────────────────────────────────────────────
class _RingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double glowOpacity;

  const _RingPainter({
    required this.color,
    this.strokeWidth = 3,
    this.glowOpacity = 0.12,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;

    // Glow
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: glowOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 10
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Arc (270°)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.glowOpacity != glowOpacity || old.color != color;
}
