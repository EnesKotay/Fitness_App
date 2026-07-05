import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/services/page_guide_service.dart';
import '../../../../core/health/health_safety_service.dart';
import '../../../../core/widgets/page_guide_overlay.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/premium_features.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/pro_badge.dart';
import '../../../../core/preferences/app_preferences.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../data/datasources/weekly_meal_plan_storage.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/nutrition_preferences.dart';
import '../../domain/entities/planned_meal.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/entities/user_profile.dart';
import '../../models/nutrition_ai_response.dart';
import '../../services/ai_customized_plan_mapper.dart';
import '../../services/premium_feature_gate.dart';
import '../../services/smart_nutrition_plan_engine.dart';
import '../state/diet_provider.dart';
import '../../../workout/providers/workout_provider.dart';
import 'food_search_page.dart';
import 'smart_grocery_list_page.dart';
import 'weekly_meal_plan_page.dart';

part 'nutrition_guide_models.dart';
part 'nutrition_guide_data.dart';
part 'nutrition_guide_components.dart';
part 'nutrition_quick_log_sheet.dart';

class NutritionGuidePage extends StatefulWidget {
  const NutritionGuidePage({super.key});

  @override
  State<NutritionGuidePage> createState() => _NutritionGuidePageState();
}

class _NutritionGuidePageState extends State<NutritionGuidePage>
    with TickerProviderStateMixin {
  static const List<String> _weeklyPlanSlotKeys = [
    'breakfast',
    'lunch',
    'dinner',
    'snack',
    'snack2',
    'preWorkout',
    'postWorkout',
  ];
  int _selectedIndex = 0;
  bool _syncedWithProfile = false;
  final _weeklyPlanStorage = WeeklyMealPlanStorage();
  late AnimationController _switchCtrl;
  late Animation<double> _fadeAnim;
  late TabController _tabController;

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '📚',
      title: 'Beslenme Rehberin',
      description:
          'Bu sayfa hedefe göre kişiselleştirilmiş günlük kalori ihtiyacını, makro besin hedeflerini ve beslenme önerilerini gösterir. Hedefin değiştikçe otomatik güncellenir.',
      tip:
          'Profilindeki boy, kilo ve aktivite düzeyine göre hesaplanır — bunları güncel tutarsan plan daha doğru olur.',
    ),
    GuideStep(
      emoji: '🎯',
      title: 'Hedef Seç',
      description:
          'Sayfanın üstündeki hedef seçiciden:\n• Kilo Ver — kalori açığı ile yağ yakımı\n• Kilo Koru — bakım kalorileri\n• Kas Kazan — kalori fazlası ile hacim\nArasında geçiş yap, makrolar anında güncellenir.',
      tip:
          'Hedefi değiştirince önerilen kalori ve protein/karb/yağ oranları otomatik yeniden hesaplanır.',
    ),
    GuideStep(
      emoji: '💡',
      title: 'Kişisel Öneriler',
      description:
          'Aşağı kaydırdıkça günlük kalori, protein, karbonhidrat ve yağ önerilerini ayrıntılı görürsün. Her makronun neden önemli olduğu kısa açıklamalarla belirtilir.',
      tip:
          '"Bugün ne yesem?" sorusunu AI Koç\'a sor — profilindeki hedefleri bilerek menü önerir.',
    ),
    GuideStep(
      emoji: '🔄',
      title: 'Planı Güncel Tut',
      description:
          'Kilonuz değiştikçe Profil → Fiziksel Bilgiler\'i güncelle. Bu sayfa profil bilgilerinden hesaplandığı için kilo veya aktivite güncellemesi makro hedeflerini de değiştirir.',
      tip:
          'Her 4 haftada bir profil bilgilerini güncelle — vücut değiştikçe kalori ihtiyacı da değişir.',
    ),
  ];

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('nutrition_guide')) return;
    await PageGuideService.markGuideSeen('nutrition_guide');
    if (mounted) await _showGuide();
  }

  @override
  void initState() {
    super.initState();
    _switchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _switchCtrl, curve: Curves.easeOut);
    _switchCtrl.forward();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkFirstVisitGuide();
    });
  }

  @override
  void dispose() {
    _switchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _selectGoal(int i) async {
    if (i == _selectedIndex) return;
    await _switchCtrl.reverse();
    if (!mounted) return;
    setState(() => _selectedIndex = i);
    _switchCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedWithProfile) return;
    final profileGoal = context.read<DietProvider>().profile?.goal;
    final goalIndex = _goalIndexForProfile(profileGoal);
    if (goalIndex != null) {
      _selectedIndex = goalIndex;
    }
    _syncedWithProfile = true;
  }

  int? _goalIndexForProfile(Goal? goal) {
    switch (goal) {
      case Goal.cut:
        return _goals.indexWhere((item) => item.key == 'cut');
      case Goal.bulk:
        return _goals.indexWhere((item) => item.key == 'bulk');
      case Goal.strength:
        return _goals.indexWhere((item) => item.key == 'strength');
      case Goal.maintain:
        return _goals.indexWhere((item) => item.key == 'maintain');
      case null:
        return null;
    }
  }

  MealType _suggestedMealType() {
    final hour = DateTime.now().hour;
    if (hour < 11) return MealType.breakfast;
    if (hour < 16) return MealType.lunch;
    if (hour < 21) return MealType.dinner;
    return MealType.snack;
  }

  IconData _mealTimeIcon(int hour) {
    if (hour < 10) return Icons.wb_sunny_rounded;
    if (hour < 12) return Icons.wb_cloudy_outlined;
    if (hour < 15) return Icons.restaurant_rounded;
    if (hour < 18) return Icons.wb_cloudy_rounded;
    if (hour < 21) return Icons.dinner_dining_rounded;
    return Icons.nights_stay_rounded;
  }

  List<_PersonalInsight> _buildInsights(DietProvider provider, _Goal goal) {
    final hour = DateTime.now().hour;
    final projectedGoal = _profileGoalForGuideGoal(goal);
    final simulated = provider.getSimulatedTargets(projectedGoal);
    final proteinGap = (simulated.proteinTarget - provider.totals.totalProtein)
        .clamp(0, double.infinity);
    final carbGap = (simulated.carbTarget - provider.totals.totalCarb).clamp(
      0,
      double.infinity,
    );
    final remaining = simulated.targetKcal - provider.totals.totalKcal;
    final progressPct = simulated.targetKcal > 0
        ? ((provider.totals.totalKcal / simulated.targetKcal) * 100)
              .round()
              .clamp(0, 100)
        : 0;
    final preferences = provider.nutritionPreferences;

    // ── Saat bazlı öğün bağlamı ──
    final String mealLabel;
    final String mealTip;
    if (hour < 9) {
      final example = _allowedFoodText('Yulaf, 2 yumurta ve meyve', preferences)
          ? 'Yulaf, 2 yumurta ve meyve'
          : _fallbackFoodFor(
              label: 'Kahvaltı',
              goalKey: goal.key,
              prefs: preferences,
            );
      mealLabel = 'Kahvaltı vakti';
      mealTip =
          'Güne protein + kompleks karb ile başla. $example iyi bir başlangıç olabilir. Hedefin ${remaining.round()} kcal.';
    } else if (hour < 11) {
      mealLabel = 'Sabah ortası';
      mealTip =
          'Hafif bir ara öğün yeterli: 1 meyve + 15 çiğ badem gibi küçük bir seçim enerji düşmesini önler.';
    } else if (hour < 14) {
      final lunchBudget = (remaining * 0.4).round().clamp(200, 800);
      final example = _allowedFoodText('Tavuk + pirinç + salata', preferences)
          ? 'Tavuk + pirinç + salata'
          : _fallbackFoodFor(
              label: 'Öğle',
              goalKey: goal.key,
              prefs: preferences,
            );
      mealLabel = 'Öğle yemeği vakti';
      mealTip =
          'Bu öğün için ~$lunchBudget kcal\'lık bir seçim dengeli olur. $example iyi bir seçenek olabilir.';
    } else if (hour < 17) {
      mealLabel = 'Öğleden sonra';
      mealTip =
          'İkindi arası hafif tutabilirsin. 1 muz (~90 kcal) veya 15 badem (~100 kcal, 3g pro) enerji verir, açlığı bastırır.';
    } else if (hour < 20) {
      final dinnerBudget = remaining.round().clamp(0, 700);
      final dinnerExample =
          _allowedFoodText('fırın somon, köfte veya tavuk şiş', preferences)
          ? 'fırın somon, köfte veya tavuk şiş + bol sebze'
          : _fallbackFoodFor(
              label: 'Akşam',
              goalKey: goal.key,
              prefs: preferences,
            );
      mealLabel = 'Akşam yemeği vakti';
      mealTip = remaining > 50
          ? 'Kalan $dinnerBudget kcal için protein ağırlıklı seç: $dinnerExample.'
          : 'Kalori hedefine yaklaştın. Hafif tut: salata, sebze veya tercihlerine uygun küçük bir protein yeterli.';
    } else {
      final nightExample = _allowedFoodText('süzme yoğurt', preferences)
          ? 'süzme yoğurt (~100 kcal, 11g pro)'
          : _fallbackFoodFor(
              label: 'Gece',
              goalKey: goal.key,
              prefs: preferences,
            );
      mealLabel = 'Gece öğünü';
      mealTip =
          'Geç saatte mide boşsa küçük bir seçenek yeterli: $nightExample. Ağır yemeklerden kaçın.';
    }

    // ── Spesifik protein önerisi ──
    final String proteinAdvice;
    if (proteinGap <= 5) {
      proteinAdvice =
          'Protein hedefine ulaştın. Günün kalanında dengeyi korumaya odaklan.';
    } else if (proteinGap <= 15) {
      final example = _allowedFoodText('1 yumurta + süzme yoğurt', preferences)
          ? '1 yumurta + 50g süzme yoğurt'
          : _fallbackFoodFor(
              label: 'Ara Öğün',
              goalKey: goal.key,
              prefs: preferences,
            );
      proteinAdvice =
          '${proteinGap.round()}g kaldı. $example ile tamamlayabilirsin. Küçük ama önemli fark.';
    } else if (proteinGap <= 35) {
      final example =
          _allowedFoodText('150g tavuk göğsü veya ton balığı', preferences)
          ? '150g tavuk göğsü veya ton balığı'
          : _fallbackFoodFor(
              label: 'Öğle',
              goalKey: goal.key,
              prefs: preferences,
            );
      proteinAdvice =
          '${proteinGap.round()}g protein açığın var. $example iyi bir kapanış olabilir.';
    } else {
      final example = _fallbackFoodFor(
        label: 'Öğle',
        goalKey: goal.key,
        prefs: preferences,
      );
      proteinAdvice =
          '${proteinGap.round()}g protein açığı fazla. Her kalan öğüne tercihlerine uygun protein kaynağı ekle; örneğin $example.';
    }

    // ── Kalori mesajı ──
    final String calorieTitle;
    final String calorieDesc;
    if (remaining >= 0) {
      if (progressPct < 25) {
        calorieTitle = 'Gün henüz başlıyor ($progressPct%)';
        calorieDesc =
            '$remaining kcal alanın var. Öğünleri güne dengeli yay — sabah atlama, akşam yükleme.';
      } else if (progressPct < 60) {
        calorieTitle = 'İyi ritim (%$progressPct tamamlandı)';
        calorieDesc =
            '$remaining kcal kalan. Bu tempoda akşama dengeli bitirirsin. Protein öncelikli seçim yap.';
      } else if (progressPct < 85) {
        calorieTitle = 'Hedefe yaklaşıyorsun (%$progressPct)';
        calorieDesc =
            'Sadece $remaining kcal kaldı. Hafif bir akşam yemeği veya protein ağırlıklı ara öğünle bitir.';
      } else {
        calorieTitle = 'Neredeyse tamam (%$progressPct)';
        calorieDesc =
            '$remaining kcal bıraktın. Çok az — sadece hafif bir şey ye, hedefi aşma.';
      }
    } else {
      calorieTitle = 'Kalori hedefi aşıldı (${remaining.abs().round()} kcal)';
      calorieDesc =
          'Bugün hedefin üstüne çıktın. Bunu tek günlük veri olarak değerlendir; sonraki öğünlerde daha sade ve dengeli seçimler yap.';
    }

    return [
      _PersonalInsight(
        title: mealLabel,
        description: mealTip,
        icon: _mealTimeIcon(hour),
        color: goal.color,
      ),
      _PersonalInsight(
        title: calorieTitle,
        description: calorieDesc,
        icon: remaining >= 0
            ? Icons.local_fire_department_rounded
            : Icons.balance_rounded,
        color: remaining >= 0 ? AppColors.secondary : const Color(0xFFFF9F0A),
      ),
      _PersonalInsight(
        title: proteinGap <= 5 ? 'Protein hedefine ulaştın' : 'Protein takibi',
        description: proteinAdvice,
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF30D158),
      ),
      if (carbGap > 30 && hour < 18)
        _PersonalInsight(
          title: 'Enerji karbonhidratı eksik',
          description:
              '${carbGap.round()}g karb açığın var. Antrenman öncesi yulaf, bulgur veya tam buğday ekmeği performansını belirgin artırır.',
          icon: Icons.bolt_rounded,
          color: const Color(0xFF0A84FF),
        ),
      if (provider.waterLiters < 1.5)
        _PersonalInsight(
          title: provider.waterLiters < 0.5
              ? 'Su içmeyi unuttun'
              : 'Su alımı düşük',
          description: provider.waterLiters < 0.5
              ? 'Bugün henüz su kaydın yok. Günde en az 2–2.5L su içmek metabolizmayı destekler, açlık hissini azaltır ve performansı artırır.'
              : '${(provider.waterLiters * 1000).round()}ml içildi. Gün içinde ${((2.0 - provider.waterLiters) * 1000).round()}ml daha ekle — günde 2L hedef.',
          icon: Icons.water_drop_rounded,
          color: const Color(0xFF64D2FF),
        ),
    ];
  }

  void _openFoodSearch({MealType? mealType}) {
    final selectedMeal = mealType ?? _suggestedMealType();
    _openQuickLogSheet(selectedMeal);
  }

  void _openQuickLogSheet(MealType mealType) {
    final goal = _goals[_selectedIndex];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NutritionQuickLogSheet(
        mealType: mealType,
        goal: goal,
        onFoodSearch: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FoodSearchPage(selectedMealType: mealType),
            ),
          );
        },
      ),
    );
  }

  void _openWeeklyPlan() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WeeklyMealPlanPage()));
  }

  void _openGroceryList() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SmartGroceryListPage()));
  }

  String _slotKeyForMealType(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
    }
  }

  String _nextSlotKeyForMeal(
    PlannedMeal meal,
    Map<String, PlannedMeal?> daySlots,
  ) {
    if (_weeklyPlanSlotKeys.contains(meal.category) &&
        daySlots[meal.category] == null) {
      return meal.category;
    }
    final preferred = _slotKeyForMealType(meal.mealType);
    if (daySlots[preferred] == null) return preferred;
    if (meal.mealType == MealType.snack) {
      for (final slotKey in const ['snack2', 'preWorkout', 'postWorkout']) {
        if (daySlots[slotKey] == null) return slotKey;
      }
    }
    return preferred;
  }

  Future<void> _copyPlannedMealsToWeeklyPlan(
    List<PlannedMeal> meals, {
    required String successMessage,
  }) async {
    if (meals.isEmpty) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Kopyalanacak öğün bulunamadı.'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            duration: const Duration(milliseconds: 1600),
            dismissDirection: DismissDirection.down,
          ),
        );
      return;
    }

    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(monday.year, monday.month, monday.day);
    final dayIndex = now.weekday - 1;
    final weekPlan = await _weeklyPlanStorage.load(weekStart);
    final daySlots = <String, PlannedMeal?>{
      for (final slotKey in _weeklyPlanSlotKeys) slotKey: null,
      ...Map<String, PlannedMeal?>.from(weekPlan[dayIndex] ?? {}),
    };

    for (final slotKey in _weeklyPlanSlotKeys) {
      daySlots[slotKey] = null;
    }

    for (final nextMeal in meals) {
      final slotKey = _nextSlotKeyForMeal(nextMeal, daySlots);
      daySlots[slotKey] = nextMeal;
    }

    weekPlan[dayIndex] = daySlots;
    await _weeklyPlanStorage.save(weekStart, weekPlan);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            successMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          duration: const Duration(milliseconds: 1600),
          dismissDirection: DismissDirection.down,
        ),
      );
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    });
  }

  Future<void> _copySmartDailyPlanToWeeklyPlan(
    _Goal goal,
    List<PlannedMeal> meals,
  ) async {
    await _copyPlannedMealsToWeeklyPlan(
      meals,
      successMessage:
          '${goal.label} için akıllı plan bugünün haftalık planına kopyalandı.',
    );
  }

  Future<void> _applyAiDailyPlan(
    _Goal goal,
    List<CustomizedDailyPlanMealModel> dailyPlan,
  ) async {
    final plannedMeals = AiCustomizedPlanMapper.toPlannedMeals(dailyPlan);
    await _copyPlannedMealsToWeeklyPlan(
      plannedMeals,
      successMessage:
          '${goal.label} için AI ile özelleştirilen plan bugünün planına uygulandı.',
    );
  }

  Future<void> _showAiCustomizeSheet(_Goal goal) async {
    final allowed = await PremiumFeatureGate.ensureAccess(
      context,
      featureName: 'AI ile plan özelleştirme',
    );
    if (!allowed || !mounted) {
      return;
    }

    final customizedPlan =
        await showModalBottomSheet<List<CustomizedDailyPlanMealModel>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AiCustomizeSheet(goal: goal),
        );

    if (!mounted || customizedPlan == null || customizedPlan.isEmpty) {
      return;
    }

    await _applyAiDailyPlan(goal, customizedPlan);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DietProvider>();
    final goal = _goals[_selectedIndex];
    final insights = _buildInsights(provider, goal);
    final isPremiumUser = isPremiumTier(
      context.watch<AuthProvider>().user?.premiumTier,
      expiresAt: context.watch<AuthProvider>().user?.premiumExpiresAt,
    );
    final hasProfile = provider.profile != null;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  goal.color.withValues(alpha: 0.14),
                  AppColors.background,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beslenme Rehberi',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        hasProfile
                            ? 'Profil hedefine göre kişisel plan'
                            : 'Hedefe göre rehber modu',
                        style: GoogleFonts.dmSans(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _showGuide,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: const Icon(
                      Icons.help_outline_rounded,
                      color: Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Goal Selector ─────────────────────────────────────────────────
          _GoalSelector(
            goals: _goals,
            selectedIndex: _selectedIndex,
            profileGoalIndex: hasProfile
                ? _goalIndexForProfile(provider.profile?.goal)
                : null,
            onSelected: _selectGoal,
          ),

          // ── Tab Bar ───────────────────────────────────────────────────────
          _buildTabBar(goal),
          const SizedBox(height: 4),

          // ── Tab Content ───────────────────────────────────────────────────
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSummaryTab(goal, provider, insights),
                  _buildPlanTab(goal, isPremiumUser),
                  _buildDetailsTab(goal, provider),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(_Goal goal) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: goal.color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: goal.color.withValues(alpha: 0.45)),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: goal.color,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.dashboard_rounded,
                    size: 14,
                    color: _tabController.index == 0
                        ? goal.color
                        : Colors.white54,
                  ),
                  const SizedBox(width: 5),
                  const Text('Özet'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 14,
                    color: _tabController.index == 1
                        ? goal.color
                        : Colors.white54,
                  ),
                  const SizedBox(width: 5),
                  const Text('Plan'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.analytics_rounded,
                    size: 14,
                    color: _tabController.index == 2
                        ? goal.color
                        : Colors.white54,
                  ),
                  const SizedBox(width: 5),
                  const Text('Detaylar'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryTab(
    _Goal goal,
    DietProvider provider,
    List<_PersonalInsight> insights,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SmartNowCard(
                goal: goal,
                provider: provider,
                onFoodSearch: (mealType) => _openFoodSearch(mealType: mealType),
                workoutProvider: context.read<WorkoutProvider>(),
              )
              .animate(key: ValueKey('smart_${goal.label}'))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.03, duration: 300.ms, curve: Curves.easeOutQuad),
          const SizedBox(height: 12),
          _HeroBanner(goal: goal, provider: provider)
              .animate(key: ValueKey('hero_${goal.label}'))
              .fadeIn(delay: 40.ms, duration: 350.ms)
              .slideY(begin: 0.04, duration: 350.ms, curve: Curves.easeOutQuad),
          const SizedBox(height: 14),
          _PersonalSummaryCard(
                goal: goal,
                provider: provider,
                insights: insights,
              )
              .animate(key: ValueKey('summary_${goal.label}'))
              .fadeIn(delay: 80.ms, duration: 350.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutQuad),
          const SizedBox(height: 14),
          _GuideActionsCard(
                onFoodSearch: _openFoodSearch,
                onWeeklyPlan: _openWeeklyPlan,
                onGroceryList: _openGroceryList,
              )
              .animate(key: ValueKey('actions_${goal.label}'))
              .fadeIn(delay: 120.ms, duration: 350.ms)
              .slideY(begin: 0.04, curve: Curves.easeOutQuad),
        ],
      ),
    );
  }

  Widget _buildPlanTab(_Goal goal, bool isPremiumUser) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Öğün Fikirleri',
            icon: Icons.restaurant_menu_rounded,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 152,
            child: _MealList(goal: goal, onTap: _openFoodSearch),
          ),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Örnek Günlük Plan',
            icon: Icons.schedule_rounded,
          ),
          const SizedBox(height: 10),
          _DailyPlanCard(
            goal: goal,
            onCopyTap: _copySmartDailyPlanToWeeklyPlan,
            onAiCustomizeTap: () => _showAiCustomizeSheet(goal),
            isAiPremiumUnlocked: isPremiumUser,
          ),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Antrenman Zamanlaması',
            icon: Icons.timer_rounded,
          ),
          const SizedBox(height: 10),
          _TimingCard(goal: goal),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(_Goal goal, DietProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (provider.profile != null) ...[
            _BodyProfileCard(profile: provider.profile!),
            const SizedBox(height: 10),
          ],
          _MacroCard(goal: goal, provider: provider),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'En İyi 6 Besin',
            icon: Icons.star_rounded,
          ),
          const SizedBox(height: 10),
          _TopFoodsGrid(goal: goal),
          const SizedBox(height: 22),
          _SectionHeader(
            title: 'Altın Kurallar',
            icon: Icons.check_circle_rounded,
            color: goal.color,
          ),
          const SizedBox(height: 10),
          _RulesCard(goal: goal),
          const SizedBox(height: 14),
          const _SectionHeader(
            title: 'Kaçınılacaklar',
            icon: Icons.block_rounded,
            color: Color(0xFFFF453A),
          ),
          const SizedBox(height: 10),
          _AvoidCard(goal: goal),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Takviye Notları',
            icon: Icons.science_rounded,
          ),
          const SizedBox(height: 10),
          _SupplementChips(goal: goal),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Beslenme İpuçları',
            icon: Icons.lightbulb_rounded,
            color: Color(0xFFFFD60A),
          ),
          const SizedBox(height: 10),
          if (provider.profile != null) ...[
            _PersonalTipsSection(profile: provider.profile!),
            const SizedBox(height: 10),
          ],
          const _GeneralTipsCard(),
        ],
      ),
    );
  }
}

// ─── Section Header ───────────────────────────────────────────────────────────
