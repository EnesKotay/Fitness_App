import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/premium_features.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/screens/premium_screen.dart';
import '../../data/datasources/weekly_meal_plan_storage.dart';
import '../../data/repositories/local_food_repository.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/planned_meal.dart';
import '../state/diet_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

// day index (0=Mon … 6=Sun), slot key → PlannedMeal
typedef _WeekPlan = Map<int, Map<String, PlannedMeal?>>;

// ── Page ──────────────────────────────────────────────────────────────────────

class WeeklyMealPlanPage extends StatefulWidget {
  const WeeklyMealPlanPage({super.key});

  @override
  State<WeeklyMealPlanPage> createState() => _WeeklyMealPlanPageState();
}

class _WeeklyMealPlanPageState extends State<WeeklyMealPlanPage> {
  static const List<String> _slotKeys = [
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];
  static const Map<String, String> _slotLabels = {
    'breakfast': 'Kahvaltı',
    'lunch': 'Öğle Yemeği',
    'dinner': 'Akşam Yemeği',
    'snack': 'Atıştırma',
  };
  static const List<String> _dayLabels = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  late DateTime _weekStart;
  final _storage = WeeklyMealPlanStorage();
  _WeekPlan _plan = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Monday of current week
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _loadPlan();
  }

  Future<void> _loadPlan() async {
    final loaded = await _storage.load(_weekStart);
    if (mounted) {
      setState(() {
        _plan = loaded;
        _loading = false;
      });
    }
  }

  Future<void> _savePlan() async {
    await _storage.save(_weekStart, _plan);
  }

  int get _totalWeeklyKcal {
    int total = 0;
    for (final slots in _plan.values) {
      for (final meal in slots.values) {
        if (meal != null) total += meal.kcal;
      }
    }
    return total;
  }

  int _dailyKcal(int dayIndex) {
    final slots = _plan[dayIndex];
    if (slots == null) return 0;
    int total = 0;
    for (final meal in slots.values) {
      if (meal != null) total += meal.kcal;
    }
    return total;
  }

  MealType _mealTypeForSlot(String slotKey) {
    switch (slotKey) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      default:
        return MealType.snack;
    }
  }

  List<String> _parseIngredientsText(String raw) {
    return raw
        .split(RegExp(r'[\n,]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<void> _showAddDialog(int dayIndex, String slotKey) async {
    final nameCtrl = TextEditingController();
    final kcalCtrl = TextEditingController();
    final gramsCtrl = TextEditingController(text: '100');
    final ingredientsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    FoodItem? pickedFood;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: Text(
          '${_slotLabels[slotKey]} Ekle',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Yemeklerimden seç butonu
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.chartGreen,
                    side: BorderSide(
                      color: AppColors.chartGreen.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Yemeklerimden Seç'),
                  onPressed: () async {
                    final picked = await _showFoodPickerSheet(ctx);
                    if (picked != null) {
                      final defaultGrams = DietProvider.getDefaultPortionForFood(
                        picked,
                      );
                      pickedFood = picked;
                      nameCtrl.text = picked.name;
                      kcalCtrl.text = picked.kcalPer100g.round().toString();
                      gramsCtrl.text = defaultGrams.round().toString();
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Yemek adı'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: kcalCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Kalori (kcal)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Gerekli';
                  if (int.tryParse(v.trim()) == null) return 'Sayı girin';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: gramsCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Porsiyon (gram)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Gerekli';
                  final grams = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (grams == null || grams <= 0) return 'Geçerli gram girin';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ingredientsCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                decoration: _inputDecoration(
                  'Malzemeler (opsiyonel, virgül veya satır satır)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.chartGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final meal = PlannedMeal(
        name: nameCtrl.text.trim(),
        kcal: int.parse(kcalCtrl.text.trim()),
        portionGrams: double.parse(gramsCtrl.text.trim().replaceAll(',', '.')),
        mealType: _mealTypeForSlot(slotKey),
        foodId: pickedFood?.id,
        category: pickedFood?.category ?? '',
        ingredients: _parseIngredientsText(ingredientsCtrl.text),
      );
      setState(() {
        _plan[dayIndex] ??= {};
        _plan[dayIndex]![slotKey] = meal;
      });
      await _savePlan();
    }
  }

  /// Yerel yemek veritabanından arama yapıp seçim döndürür.
  Future<FoodItem?> _showFoodPickerSheet(BuildContext parentCtx) async {
    final repo = LocalFoodRepository();
    final searchCtrl = TextEditingController();
    List<FoodItem> results = [];
    bool loading = false;

    return showModalBottomSheet<FoodItem>(
      context: parentCtx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> doSearch(String q) async {
            if (q.trim().isEmpty) {
              setSheetState(() => results = []);
              return;
            }
            setSheetState(() => loading = true);
            try {
              final found = await repo.searchFoods(q.trim());
              setSheetState(() => results = found.take(30).toList());
            } finally {
              setSheetState(() => loading = false);
            }
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yemek Seç',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: 'Yemek ara… (ör. yoğurt, tavuk)',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: Colors.white38,
                            ),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      doSearch('');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.06),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          onChanged: doSearch,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.chartGreen,
                            ),
                          )
                        : results.isEmpty
                        ? Center(
                            child: Text(
                              searchCtrl.text.isEmpty
                                  ? 'Aramak için yazmaya başla'
                                  : 'Sonuç bulunamadı',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: results.length,
                            separatorBuilder: (context, idx) => Divider(
                              height: 1,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                            itemBuilder: (_, i) {
                              final food = results[i];
                              final kcal = food.kcalPer100g.round();
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                title: Text(
                                  food.name,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  food.category,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: Text(
                                  '$kcal kcal/100g',
                                  style: const TextStyle(
                                    color: AppColors.chartGreen,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onTap: () => Navigator.pop(sheetCtx, food),
                              );
                            },
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

  Future<void> _showEditDialog(int dayIndex, String slotKey) async {
    final existing = _plan[dayIndex]?[slotKey];
    if (existing == null) return;

    final nameCtrl = TextEditingController(text: existing.name);
    final kcalCtrl = TextEditingController(text: existing.kcal.toString());
    final gramsCtrl = TextEditingController(
      text: existing.portionGrams == existing.portionGrams.roundToDouble()
          ? existing.portionGrams.toInt().toString()
          : existing.portionGrams.toStringAsFixed(1),
    );
    final ingredientsCtrl = TextEditingController(
      text: existing.ingredients.join(', '),
    );
    final formKey = GlobalKey<FormState>();
    FoodItem? pickedFood;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: Text(
          '${_slotLabels[slotKey]} Düzenle',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.chartGreen,
                    side: BorderSide(
                      color: AppColors.chartGreen.withValues(alpha: 0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Yemeklerimden Seç'),
                  onPressed: () async {
                    final picked = await _showFoodPickerSheet(ctx);
                    if (picked != null) {
                      final defaultGrams = DietProvider.getDefaultPortionForFood(
                        picked,
                      );
                      pickedFood = picked;
                      nameCtrl.text = picked.name;
                      kcalCtrl.text = picked.kcalPer100g.round().toString();
                      gramsCtrl.text = defaultGrams.round().toString();
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Yemek adı'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: kcalCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Kalori (kcal)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Gerekli';
                  if (int.tryParse(v.trim()) == null) return 'Sayı girin';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: gramsCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Porsiyon (gram)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Gerekli';
                  final grams = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (grams == null || grams <= 0) return 'Geçerli gram girin';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ingredientsCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 3,
                decoration: _inputDecoration(
                  'Malzemeler (opsiyonel, virgül veya satır satır)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.chartRed),
            onPressed: () => Navigator.pop(ctx, 'delete'),
            child: const Text('Sil'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.chartGreen,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, 'save');
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (result == 'save') {
      setState(() {
        _plan[dayIndex]![slotKey] = PlannedMeal(
          name: nameCtrl.text.trim(),
          kcal: int.parse(kcalCtrl.text.trim()),
          portionGrams: double.parse(
            gramsCtrl.text.trim().replaceAll(',', '.'),
          ),
          mealType: _mealTypeForSlot(slotKey),
          foodId: pickedFood?.id ?? existing.foodId,
          category: pickedFood?.category ?? existing.category,
          ingredients: _parseIngredientsText(ingredientsCtrl.text),
        );
      });
      await _savePlan();
    } else if (result == 'delete') {
      setState(() {
        _plan[dayIndex]![slotKey] = null;
      });
      await _savePlan();
    }
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.chartGreen),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.chartRed),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.chartRed),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isPremium = isPremiumTier(
      context.watch<AuthProvider>().user?.premiumTier,
    );

    if (!isPremium) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text('Haftalık Öğün Planı'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD97706).withValues(alpha: 0.14),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFFFBBF24),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Haftalık öğün planı Premium\'a özel',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Kişisel beslenme planını haftalık takvime yerleştirmek ve alışveriş listesini otomatik oluşturmak için Premium\'a geç.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.64),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const PremiumScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFBBF24),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Premium ile Aç',
                        style: TextStyle(fontWeight: FontWeight.w800),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Haftalık Öğün Planı',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.chartGreen),
            )
          : CustomScrollView(
              slivers: [
                // ── Local-only uyarı banner'ı ──────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFD97706).withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.device_hub_rounded,
                          color: Color(0xFFD97706),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Plan yalnızca bu cihazda saklanır, hesabınızla senkronize edilmez.',
                            style: TextStyle(
                              color: const Color(
                                0xFFD97706,
                              ).withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildWeeklySummaryHeader()),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildDaySection(index),
                    childCount: 7,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildWeeklySummaryHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: AppColors.chartGreen,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bu Hafta',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${_formatDate(_weekStart)} – ${_formatDate(_weekStart.add(const Duration(days: 6)))}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_totalWeeklyKcal',
                      style: const TextStyle(
                        color: AppColors.chartGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'kcal toplam',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
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

  Widget _buildDaySection(int dayIndex) {
    final dayKcal = _dailyKcal(dayIndex);
    final date = _weekStart.add(Duration(days: dayIndex));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(
                  _dayLabels[dayIndex],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (dayKcal > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.chartGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.chartGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      '$dayKcal kcal',
                      style: const TextStyle(
                        color: AppColors.chartGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Slots
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: _slotKeys.asMap().entries.map((entry) {
                    final isLast = entry.key == _slotKeys.length - 1;
                    return _buildSlotTile(
                      dayIndex,
                      entry.value,
                      isLast: isLast,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotTile(int dayIndex, String slotKey, {required bool isLast}) {
    final meal = _plan[dayIndex]?[slotKey];
    final isFilled = meal != null;

    return Column(
      children: [
        InkWell(
          borderRadius: isLast
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                )
              : BorderRadius.zero,
          onTap: () => isFilled
              ? _showEditDialog(dayIndex, slotKey)
              : _showAddDialog(dayIndex, slotKey),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    _slotLabels[slotKey]!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: isFilled
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              meal.ingredients.isNotEmpty
                                  ? '${meal.portionGrams.round()}g • ${meal.ingredients.length} malzeme'
                                  : '${meal.portionGrams.round()}g porsiyon',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.42),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        )
                      : Text(
                          'Ekle +',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 13,
                          ),
                        ),
                ),
                if (isFilled)
                  Text(
                    '${meal.kcal} kcal',
                    style: const TextStyle(
                      color: AppColors.chartGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.white.withValues(alpha: 0.06),
            indent: 16,
            endIndent: 16,
          ),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}
