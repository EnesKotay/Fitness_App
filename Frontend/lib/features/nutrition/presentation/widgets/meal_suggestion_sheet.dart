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
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
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
              child: const _MealSuggestionContent(),
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
  const _MealSuggestionContent();

  @override
  State<_MealSuggestionContent> createState() => _MealSuggestionContentState();
}

class _MealSuggestionContentState extends State<_MealSuggestionContent> {
  MealType _mealType = MealType.lunch;
  List<FoodItem> _suggestions = [];
  String? _aiReasoning;
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const _debounceMs = 400;

  // Dinamik Porsiyon Ayarı için
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
    final list = await provider.getSuggestedFoods(_mealType, limit: 28, query: query);
    final reasoning = await provider.getAISuggestionReasoning(list);
    if (mounted) {
      setState(() {
        _suggestions = list;
        _aiReasoning = reasoning;
        _loading = false;
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DietProvider>(context);
    final targets = provider.macroTargets;
    final t = provider.totals;
    final remKcal = provider.remainingKcal.round();
    final remP = (targets.protein - t.totalProtein).clamp(0.0, double.infinity).round();
    final remC = (targets.carb - t.totalCarb).clamp(0.0, double.infinity).round();
    final remF = (targets.fat - t.totalFat).clamp(0.0, double.infinity).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        _buildRemainingSummary(remKcal: remKcal, remP: remP, remC: remC, remF: remF),
        _buildSearchBar(),
        _buildSmartChips(),
        _buildMealTypeSelector(provider),
        _buildModeChips(context, provider),
        if (_aiReasoning != null && _aiReasoning!.isNotEmpty && !_loading) _buildAIReasoning(_aiReasoning!),
        Expanded(
          child: Stack(
            children: [
              _loading
                  ? _buildLoading()
                  : _suggestions.isEmpty
                      ? _buildEmptyState()
                      : _buildFoodList(provider),
              if (_selectedFood != null) _buildPortionAdjustmentOverlay(provider),
            ],
          ),
        ),
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
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      'Bugünkü hedefe göre kalan kalori ve makrolarına uygun öneriler',
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
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Icon(Icons.track_changes_rounded, size: 18, color: AppColors.primary.withValues(alpha: 0.9)),
              const SizedBox(width: 10),
              Text(
                'Kalan bugün:',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              _remainingChip('$remKcal kcal', Icons.local_fire_department_rounded, AppColors.secondary),
              const SizedBox(width: 8),
              _remainingChip('P $remP', Icons.fitness_center_rounded, const Color(0xFF5B9BFF)),
              const SizedBox(width: 6),
              _remainingChip('K $remC', Icons.grain_rounded, const Color(0xFF4CD1A3)),
              const SizedBox(width: 6),
              _remainingChip('Y $remF', Icons.water_drop_rounded, const Color(0xFFFFB74D)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _remainingChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.sm, AppSpacing.m, AppSpacing.xs),
      child: TextField(
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.m, AppSpacing.m, AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hangi öğüne ekleyeceksin?',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            Icon(
                              icon,
                              size: 18,
                              color: selected ? AppColors.primaryLight : Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
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
          ),
        ],
      ),
    );
  }

  Widget _buildModeChips(BuildContext context, DietProvider provider) {
    final modes = [
      (SuggestionMode.balanced, 'Dengeli', 'Kalori ve makro dengesi'),
      (SuggestionMode.highProtein, 'Yüksek protein', 'Kas için protein ağırlıklı'),
      (SuggestionMode.lowCarb, 'Düşük karb', 'Karbonhidratı azalt'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: modes.map((e) {
          final mode = e.$1;
          final label = e.$2;
          final selected = provider.suggestionMode == mode;
          return GestureDetector(
            onTap: () {
              provider.setSuggestionMode(mode);
              _load();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.18),
                  width: 1,
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
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAIReasoning(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.sm, AppSpacing.m, AppSpacing.s),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.12),
              AppColors.primary.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.psychology_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Senin için uygun yemekler aranıyor...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
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
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Farklı bir kelime yaz veya aramayı temizle.'
                  : 'Kalan kalori veya makro kaldığında burada öneriler görünecek.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodList(DietProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpacing.m, AppSpacing.s, AppSpacing.m, 28),
      itemCount: _suggestions.length,
      itemBuilder: (_, i) {
        final food = _suggestions[i];
        final impact = provider.calculateMacroImpact(food, 100.0);
        final proteinImpact = (impact['protein']! * 100).round();
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedFood = food;
                  _adjustmentGrams = 100.0;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                              if (proteinImpact > 15)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5B9BFF).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Yüksek Protein', style: TextStyle(color: Color(0xFF5B9BFF), fontSize: 9, fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _macroPill('${food.kcalPer100g.round()} kcal', AppColors.secondary),
                              const SizedBox(width: 8),
                              _impactIndicator('Hedefe katkı: %$proteinImpact Protein', const Color(0xFF5B9BFF), impact['protein']!),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _impactIndicator(String label, Color color, double percent) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPortionAdjustmentOverlay(DietProvider provider) {
    if (_selectedFood == null) return const SizedBox.shrink();
    
    final food = _selectedFood!;
    final impact = provider.calculateMacroImpact(food, _adjustmentGrams);
    
    return GestureDetector(
      onTap: () => setState(() => _selectedFood = null),
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () {}, // İçeriğe tıklayınca kapanmasın
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Porsiyon (gram)', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                        Text('${_adjustmentGrams.round()} g', style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    Slider(
                      value: _adjustmentGrams,
                      min: 10,
                      max: 1000,
                      divisions: 99,
                      activeColor: AppColors.primary,
                      inactiveColor: Colors.white10,
                      onChanged: (val) => setState(() => _adjustmentGrams = val),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _impactCircle('Kcal', impact['kcal']!, AppColors.secondary),
                          _impactCircle('Prot', impact['protein']!, const Color(0xFF5B9BFF)),
                          _impactCircle('Karb', impact['carb']!, const Color(0xFF4CD1A3)),
                          _impactCircle('Yağ', impact['fat']!, const Color(0xFFFFB74D)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () async {
                          await provider.addEntry(
                            food: food,
                            grams: _adjustmentGrams,
                            mealType: _mealType,
                            date: provider.selectedDate,
                          );
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${food.name} eklendi!'), backgroundColor: AppColors.success),
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

  Widget _impactCircle(String label, double percent, Color color) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                value: percent.clamp(0.0, 1.0),
                strokeWidth: 4,
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text('%${(percent * 100).round()}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _macroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }
}
