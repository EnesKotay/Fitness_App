import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/page_guide_service.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/widgets/page_guide_overlay.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/premium_features.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ambient_glow_background.dart';
import '../../../../core/widgets/app_gradient_background.dart';
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
  bool _generating = false;

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '📅',
      title: 'Haftalık Öğün Planın',
      description:
          'Bu sayfa hedefe, vücut tipine ve kalori ihtiyacına göre haftanın 7 günü için sabah, öğle ve akşam öğünlerini otomatik planlar. Kaydırarak tüm haftayı görebilirsin.',
      tip:
          'Plan profil bilgilerine göre oluşturulur — profili güncel tutarsan plan daha isabetli olur.',
    ),
    GuideStep(
      emoji: '🔄',
      title: 'Yeni Plan Oluştur',
      description:
          'Sağ üstteki yenile (↻) butonuna dokun → AI yeni bir haftalık plan oluşturur. Mevcut planı beğenmezsen istediğin zaman yenileyebilirsin.',
      tip:
          'Her yenilemede farklı yemekler önerilir — çeşitli beslenme için haftada 1-2 kez yenile.',
    ),
    GuideStep(
      emoji: '🍽️',
      title: 'Yemeği Takibine Ekle',
      description:
          'Herhangi bir öğüne dokun → detay sayfası açılır → "Ekle" butonuna bas → o yemek otomatik olarak günlük beslenme takibine eklenir.',
      tip: 'Planı sabahları aç ve gün içindeki öğünleri buradan kolayca ekle.',
    ),
    GuideStep(
      emoji: '📤',
      title: 'Planı Paylaş',
      description:
          'Sağ üstteki paylaş ikonuna dokun → haftalık menüyü görsel olarak paylaşabilirsin. Diyetisyen veya arkadaşlarınla paylaşmak için kullanışlı.',
      tip:
          'Planı yazdırıp buzdolabına yapıştırmak alışkanlık oluşturmada çok etkili!',
    ),
  ];

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('weekly_meal_plan')) return;
    await PageGuideService.markGuideSeen('weekly_meal_plan');
    if (mounted) await _showGuide();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Monday of current week
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
    _loadPlan();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkFirstVisitGuide();
    });
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

  Future<void> _generateWithAi() async {
    if (_generating) return;
    final token = StorageHelper.getToken();
    if (token == null || token.isEmpty) return;

    final dietProvider = context.read<DietProvider>();
    final targetKcal = (dietProvider.dailyTargetKcal ?? 2000).round();
    final goalEnum = dietProvider.profile?.goal;
    final goal = goalEnum == null ? 'denge' : goalEnum.name;

    setState(() => _generating = true);
    try {
      final res = await ApiClient().post(
        ApiConstants.aiNutritionWeeklyPlan,
        data: {'targetKcal': targetKcal, 'goal': goal},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (res.statusCode != 200) return;

      final data = res.data as Map<String, dynamic>?;
      final days = (data?['days'] as List<dynamic>?) ?? [];
      if (days.isEmpty) return;

      final newPlan = <int, Map<String, PlannedMeal?>>{};
      for (int i = 0; i < 7 && i < days.length; i++) {
        final day = days[i] as Map<String, dynamic>;
        newPlan[i] = {};
        for (final slot in _slotKeys) {
          final mealData = day[slot] as Map<String, dynamic>?;
          if (mealData == null) continue;
          newPlan[i]![slot] = PlannedMeal(
            name: mealData['name']?.toString() ?? '',
            kcal: (mealData['kcal'] as num?)?.toInt() ?? 0,
            portionGrams: (mealData['portionGrams'] as num?)?.toDouble() ?? 0,
            mealType: _mealTypeForSlot(slot),
            ingredients: const [],
          );
        }
      }

      setState(() => _plan = newPlan);
      await _savePlan();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Haftalık plan oluşturuldu'),
            backgroundColor: AppColors.chartGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plan oluşturulamadı, tekrar dene'),
            backgroundColor: AppColors.chartRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
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
                      final defaultGrams =
                          DietProvider.getDefaultPortionForFood(picked);
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
                      final defaultGrams =
                          DietProvider.getDefaultPortionForFood(picked);
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

  Widget _buildLockedPreviewDay({
    required String day,
    required List<String> meals,
    required String calories,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                day,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF81C784).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFF81C784).withValues(alpha: 0.24),
                  ),
                ),
                child: Text(
                  calories,
                  style: const TextStyle(
                    color: Color(0xFF81C784),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...meals.map((meal) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBBF24),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meal,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLockedState(BuildContext context) {
    return AppGradientBackground(
      imagePath: 'assets/images/nutrition_bg_dark.png',
      child: Stack(
        children: [
          const AmbientGlowBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(
                                  0xFFD97706,
                                ).withValues(alpha: 0.14),
                              ),
                              child: const Icon(
                                Icons.calendar_month_rounded,
                                color: Color(0xFFFBBF24),
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Haftayı senin yerine planlar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Ücretsiz planda öğünlerini tek tek takip etmeye devam edersin. Premium ise haftanın tamamını sana hazırlar.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.62,
                                      ),
                                      fontSize: 12.5,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Text(
                            'Önizleme: AI hedef kalorini, makro dengenini ve çeşit ihtiyacını okuyup günü düşünmeden takip edebileceğin bir haftaya çevirir.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.76),
                              fontSize: 12.5,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const PremiumScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBBF24),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text(
                              'Premium ile Haftalık Planı Aç',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Örnek plan akışı',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLockedPreviewDay(
                    day: 'Pazartesi',
                    calories: '~1880 kcal',
                    meals: const [
                      'Kahvaltı: Yulaf + yoğurt + çilek',
                      'Öğle: Tavuklu bowl + pirinç',
                      'Akşam: Izgara köfte + salata',
                      'Ara öğün: Kefir + badem',
                    ],
                  ),
                  _buildLockedPreviewDay(
                    day: 'Salı',
                    calories: '~1810 kcal',
                    meals: const [
                      'Kahvaltı: Omlet + tam buğday ekmeği',
                      'Öğle: Ton balıklı sandviç',
                      'Akşam: Sebzeli makarna + yoğurt',
                      'Ara öğün: Muz + fıstık ezmesi',
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF81C784).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF81C784).withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Premium ile gelen fark',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '• Her gün için hazır öğün akışı\n• Kaloriye yakın toplamlar\n• Tek dokunuşla alışveriş listesine dönüşüm',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
        body: _buildLockedState(context),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Haftalık Öğün Planı',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_generating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.chartGreen,
                  ),
                ),
              ),
            )
          else
            IconButton(
              tooltip: 'AI ile Doldur',
              icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.chartGreen),
              onPressed: _generateWithAi,
            ),
        ],
      ),
      body: AppGradientBackground(
        imagePath: 'assets/images/nutrition_bg_dark.png',
        child: Stack(
          children: [
            const AmbientGlowBackground(),
            SafeArea(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.chartGreen,
                      ),
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
                              color: const Color(
                                0xFFD97706,
                              ).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFD97706,
                                ).withValues(alpha: 0.30),
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
                        SliverToBoxAdapter(
                          child: _buildWeeklySummaryHeader()
                              .animate()
                              .fadeIn(duration: 400.ms)
                              .slideY(begin: 0.05, end: 0),
                        ),
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _buildDaySection(index)
                                .animate()
                                .fadeIn(
                                  delay: (index * 60).ms,
                                  duration: 400.ms,
                                )
                                .slideX(begin: 0.03, end: 0),
                            childCount: 7,
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearDay(int dayIndex) {
    setState(() {
      _plan[dayIndex] = {};
    });
    _savePlan();
  }

  void _showCopyDayDialog(int sourceIndex) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        title: const Text(
          'Günü Kopyala',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hangi güne kopyalamak istersiniz?',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...List.generate(7, (targetIndex) {
              if (targetIndex == sourceIndex) return const SizedBox.shrink();
              return ListTile(
                title: Text(
                  _dayLabels[targetIndex],
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.chartGreen,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _plan[targetIndex] = {};
                    _plan[sourceIndex]?.forEach((k, v) {
                      if (v != null) {
                        _plan[targetIndex]![k] = v.copyWith();
                      }
                    });
                  });
                  _savePlan();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_dayLabels[sourceIndex]} planı, ${_dayLabels[targetIndex]} gününe kopyalandı.',
                      ),
                      backgroundColor: AppColors.chartGreen,
                      duration: const Duration(milliseconds: 1500),
                    ),
                  );
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
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
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  color: AppColors.surfaceElevated,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'copy') {
                      _showCopyDayDialog(dayIndex);
                    } else if (value == 'clear') {
                      _clearDay(dayIndex);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(
                            Icons.copy_rounded,
                            color: AppColors.chartGreen,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Bu günü kopyala',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.chartRed,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Günü temizle',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
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
