import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/models/meal.dart';
import '../../../core/models/food.dart';
import '../../../core/models/meal_models.dart';
import '../../../core/data/food_database.dart';
import '../../../core/utils/storage_helper.dart';
import '../providers/nutrition_provider.dart';
import '../../auth/providers/auth_provider.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _selectedDate = DateTime.now();
  int _waterML = 0;

  String get _dateKey =>
      '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _loadData();
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final nutritionProvider =
          Provider.of<NutritionProvider>(context, listen: false);
      final userId = authProvider.user?.id ?? StorageHelper.getUserId();
      if (userId != null) {
        await nutritionProvider.loadMealsByDate(userId, _selectedDate);
      }
      if (mounted) {
        setState(() => _waterML = StorageHelper.getWaterForDate(_dateKey));
      }
    } catch (e) {
      debugPrint('NutritionScreen _loadData hatası: $e');
      if (mounted) {
        setState(() => _waterML = StorageHelper.getWaterForDate(_dateKey));
      }
    }
  }

  static const _mealTypeLabels = {
    'BREAKFAST': 'Kahvaltı',
    'LUNCH': 'Öğle',
    'DINNER': 'Akşam',
    'SNACK': 'Ara öğün',
  };

  static const _mealTypeIcons = {
    'BREAKFAST': Icons.wb_sunny_outlined,
    'LUNCH': Icons.wb_cloudy_outlined,
    'DINNER': Icons.nightlight_round_outlined,
    'SNACK': Icons.apple,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _NutritionHeader(),
            _buildDateSelector(context),
            Expanded(
              child: Consumer<NutritionProvider>(
                builder: (context, nutritionProvider, _) {
                  final meals = nutritionProvider.meals;
                  final dailyCalories = nutritionProvider.dailyCalories;
                  final isLoading = nutritionProvider.isLoading;
                  final targetCalories =
                      StorageHelper.getTargetCalories() ?? 2000;

                  if (isLoading && meals.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFCC7A4A)),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _loadData,
                    color: const Color(0xFFCC7A4A),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCalorieCard(dailyCalories, targetCalories, meals),
                          _buildWaterCard(),
                          _buildMealSections(meals),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildAddButton(context),
    );
  }

  Widget _buildDateSelector(BuildContext context) {
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final isYesterday =
        _isSameDay(_selectedDate, DateTime.now().subtract(const Duration(days: 1)));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          _buildDateChip(
            label: 'Bugün',
            isSelected: isToday,
            onTap: () {
              setState(() => _selectedDate = DateTime.now());
              _loadData();
            },
          ),
          const SizedBox(width: 8),
          _buildDateChip(
            label: 'Dün',
            isSelected: isYesterday,
            onTap: () {
              setState(() =>
                  _selectedDate = DateTime.now().subtract(const Duration(days: 1)));
              _loadData();
            },
          ),
          const SizedBox(width: 8),
          _buildDateChip(
            label: 'Özel tarih',
            icon: Icons.calendar_today,
            isSelected: !isToday && !isYesterday,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
                _loadData();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFCC7A4A).withValues(alpha: 0.3)
              : const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCC7A4A)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.white70),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildCalorieCard(int dailyCalories, int targetCalories, List<Meal> meals) {
    final progress = targetCalories > 0
        ? (dailyCalories / targetCalories).clamp(0.0, 1.0)
        : 0.0;
    final progressPercent = (progress * 100).round();

    double totalProtein = 0, totalCarbs = 0, totalFat = 0;
    for (final m in meals) {
      totalProtein += m.protein ?? 0;
      totalCarbs += m.carbs ?? 0;
      totalFat += m.fat ?? 0;
    }

    final totalMacro = totalProtein + totalCarbs + totalFat;
    final proteinPct = totalMacro > 0 ? (totalProtein / totalMacro) : 0.33;
    final carbsPct = totalMacro > 0 ? (totalCarbs / totalMacro) : 0.33;
    final fatPct = totalMacro > 0 ? (totalFat / totalMacro) : 0.34;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: () => _showGoalSettingDialog(),
        child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFCC7A4A).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Günlük Kalori Hedefi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(),
                Icon(Icons.settings, size: 18, color: Colors.white.withValues(alpha: 0.5)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFCC7A4A)),
                      ),
                      Text(
                        '%$progressPercent',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFCC7A4A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$dailyCalories / $targetCalories kcal',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMacroChip('Protein', '${totalProtein.round()}g', Colors.blue),
                          _buildMacroChip('Karbonhidrat', '${totalCarbs.round()}g', Colors.orange),
                          _buildMacroChip('Yağ', '${totalFat.round()}g', Colors.purple),
                        ],
                      ),
                      if (totalMacro > 0) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 60,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              sections: [
                                PieChartSectionData(value: proteinPct, color: Colors.blue, title: 'P', radius: 24),
                                PieChartSectionData(value: carbsPct, color: Colors.orange, title: 'K', radius: 24),
                                PieChartSectionData(value: fatPct, color: Colors.purple, title: 'Y', radius: 24),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildWaterCard() {
    final goal = StorageHelper.getWaterGoalML();
    final progress = goal > 0 ? (_waterML / goal).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Su Takibi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _showWaterEditDialog(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_waterML / $goal ml',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, size: 14, color: Colors.white.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildWaterButton(250),
                const SizedBox(width: 8),
                _buildWaterButton(500),
                const SizedBox(width: 8),
                _buildWaterButton(1000),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildWaterSubtractButton(250),
                const SizedBox(width: 8),
                _buildWaterSubtractButton(500),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _waterML > 0 ? () => _showWaterResetConfirm() : null,
                    icon: Icon(Icons.refresh, size: 16, color: _waterML > 0 ? Colors.blue.withValues(alpha: 0.8) : Colors.grey),
                    label: Text(
                      'Sıfırla',
                      style: TextStyle(
                        fontSize: 12,
                        color: _waterML > 0 ? Colors.blue.withValues(alpha: 0.8) : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaterButton(int ml) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () async {
          final newVal = _waterML + ml;
          await StorageHelper.saveWaterForDate(_dateKey, newVal);
          setState(() => _waterML = newVal);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
          side: const BorderSide(color: Colors.blue),
        ),
        child: Text('+$ml ml'),
      ),
    );
  }

  Widget _buildWaterSubtractButton(int ml) {
    final canSubtract = _waterML >= ml;
    return Expanded(
      child: OutlinedButton(
        onPressed: canSubtract
            ? () async {
                final newVal = (_waterML - ml).clamp(0, 99999);
                await StorageHelper.saveWaterForDate(_dateKey, newVal);
                setState(() => _waterML = newVal);
              }
            : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: canSubtract ? Colors.orange : Colors.grey,
          side: BorderSide(color: canSubtract ? Colors.orange : Colors.grey.withValues(alpha: 0.5)),
        ),
        child: Text('-$ml ml'),
      ),
    );
  }

  Future<void> _showWaterEditDialog() async {
    final controller = TextEditingController(text: _waterML.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Su miktarını düzenle', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Toplam ml',
            labelStyle: TextStyle(color: Colors.white70),
            hintText: 'Örn: 1500',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              Navigator.pop(ctx, val != null && val >= 0 ? val : null);
            },
            child: const Text('Kaydet', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      await StorageHelper.saveWaterForDate(_dateKey, result);
      setState(() => _waterML = result);
    }
  }

  Future<void> _showWaterResetConfirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Su takibini sıfırla?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Bugünkü su miktarı ($_waterML ml) sıfırlanacak.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await StorageHelper.saveWaterForDate(_dateKey, 0);
      setState(() => _waterML = 0);
    }
  }

  Future<void> _showGoalSettingDialog() async {
    final calController = TextEditingController(
      text: (StorageHelper.getTargetCalories() ?? 2000).toString(),
    );
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Günlük Hedefler', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: calController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Hedef Kalori (kcal)',
                labelStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              final cal = int.tryParse(calController.text) ?? 2000;
              await StorageHelper.saveTargetCalories(cal);
              if (mounted) setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Kaydet', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildMealSections(List<Meal> meals) {
    const types = ['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: types.map((type) {
          final typeMeals = meals.where((m) => m.mealType == type).toList();
          return _buildMealSection(
            _mealTypeLabels[type] ?? type,
            _mealTypeIcons[type] ?? Icons.restaurant,
            typeMeals,
            type,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMealSection(
      String title, IconData icon, List<Meal> typeMeals, String mealType) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFCC7A4A), size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (typeMeals.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Icon(Icons.add_circle_outline,
                      color: Colors.white.withValues(alpha: 0.4), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'Henüz eklenmedi',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            )
          else
            ...typeMeals.map((m) => _buildMealItem(m)),
        ],
      ),
    );
  }

  Widget _buildMealItem(Meal meal) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.user?.id ?? StorageHelper.getUserId();

    return Dismissible(
      key: Key('meal_${meal.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      confirmDismiss: (direction) async {
        if (userId == null) return false;
        final provider = Provider.of<NutritionProvider>(context, listen: false);
        return await provider.deleteMeal(userId, meal.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                meal.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
            Text(
              '${meal.calories} kcal',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFCC7A4A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'nutrition_meal_fab',
      onPressed: () => _showAddMealSheet(context),
      backgroundColor: const Color(0xFFCC7A4A),
      icon: const Icon(Icons.add, color: Colors.white, size: 24),
      label: const Text(
        'Yemek Ekle',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  void _showAddMealSheet(BuildContext context) {
    Food? selectedFood;
    bool usePortion = true;
    final portionController = TextEditingController(text: '1');
    final gramController = TextEditingController();
    final searchController = TextEditingController();
    String selectedMealType = 'BREAKFAST';
    String searchQuery = '';
    Timer? searchDebounce;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final totalGrams = usePortion && selectedFood != null
              ? selectedFood!.portionToGrams(
                  double.tryParse(portionController.text) ?? 1)
              : int.tryParse(gramController.text) ?? 0;
          final calculatedCalories =
              selectedFood != null ? selectedFood!.calculateCalories(totalGrams) : 0;
          final calculatedProtein =
              selectedFood != null ? selectedFood!.calculateProtein(totalGrams) : 0.0;
          final calculatedCarbs =
              selectedFood != null ? selectedFood!.calculateCarbs(totalGrams) : 0.0;
          final calculatedFat =
              selectedFood != null ? selectedFood!.calculateFat(totalGrams) : 0.0;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Yemek Ekle',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Favoriler
                  Builder(
                    builder: (_) {
                      final favIds = StorageHelper.getFavoriteFoodIds();
                      if (favIds.isEmpty) return const SizedBox();
                      final favFoods = favIds
                          .map((id) => FoodDatabase.findById(id))
                          .whereType<Food>()
                          .toList();
                      if (favFoods.isEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⭐ Favoriler',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: favFoods.map((food) {
                                final isSel = selectedFood?.id == food.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(food.name, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : Colors.white70)),
                                    selected: isSel,
                                    onSelected: (_) => setModalState(() {
                                      selectedFood = food;
                                      portionController.text = '1';
                                    }),
                                    selectedColor: const Color(0xFFC45C2C),
                                    backgroundColor: const Color(0xFF2A2A2A),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  // Son Yenenler
                  Builder(
                    builder: (_) {
                      final recent = StorageHelper.getRecentFoodEntries();
                      if (recent.isEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🕐 Son Yenenler',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: recent.take(5).map((e) {
                                final food = FoodDatabase.findById(e['foodId'] as String);
                                if (food == null) return const SizedBox();
                                final grams = e['grams'] as int;
                                final isSel = selectedFood?.id == food.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: FilterChip(
                                    label: Text(
                                      '${food.name} (${grams}g)',
                                      style: TextStyle(fontSize: 11, color: isSel ? Colors.white : Colors.white70),
                                    ),
                                    selected: isSel,
                                    onSelected: (_) => setModalState(() {
                                      selectedFood = food;
                                      usePortion = false;
                                      gramController.text = grams.toString();
                                    }),
                                    selectedColor: const Color(0xFFC45C2C),
                                    backgroundColor: const Color(0xFF2A2A2A),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  // Akıllı Öneriler
                  Builder(
                    builder: (_) {
                      if (searchQuery.trim().isNotEmpty) return const SizedBox();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '💡 Önerilenler',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Proteini yüksek',
                            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: FoodDatabase.getHighProteinFoods().map((food) {
                                final isSel = selectedFood?.id == food.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(food.name, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : Colors.white70)),
                                    onPressed: () => setModalState(() {
                                      selectedFood = food;
                                      portionController.text = '1';
                                    }),
                                    backgroundColor: isSel ? const Color(0xFFC45C2C) : const Color(0xFF2A2A2A),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Düşük kalorili atıştırmalık',
                            style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: FoodDatabase.getLowCalorieSnacks().map((food) {
                                final isSel = selectedFood?.id == food.id;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ActionChip(
                                    label: Text(food.name, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : Colors.white70)),
                                    onPressed: () => setModalState(() {
                                      selectedFood = food;
                                      portionController.text = '1';
                                    }),
                                    backgroundColor: isSel ? const Color(0xFFC45C2C) : const Color(0xFF2A2A2A),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
                  // Besin ara ve seç
                  Text(
                    'Besin ara',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: searchController,
                    onChanged: (q) {
                      searchDebounce?.cancel();
                      searchDebounce = Timer(const Duration(milliseconds: 250), () {
                        searchQuery = q;
                        setModalState(() {});
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Yumurta, pilav, tavuk...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: const Color(0xFF252525),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFCC7A4A), width: 2),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  // Besin listesi (arama sonuçları)
                  Builder(
                    builder: (context) {
                      final results = searchQuery.trim().isEmpty
                          ? FoodDatabase.foods.take(20).toList()
                          : FoodDatabase.search(searchQuery).take(20).toList();
                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final food = results[i];
                            final isSelected = selectedFood?.id == food.id;
                            final isFav = StorageHelper.isFavorite(food.id);
                            return ListTile(
                              dense: true,
                              title: Text(
                                food.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFE07B2D)
                                      : Colors.white,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(
                                '${food.caloriesPer100g} kcal/100g',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  isFav ? Icons.star : Icons.star_border,
                                  color: isFav ? Colors.amber : Colors.white38,
                                  size: 22,
                                ),
                                onPressed: () async {
                                  await StorageHelper.toggleFavorite(food.id);
                                  setModalState(() {});
                                },
                              ),
                              onTap: () {
                                setModalState(() {
                                  selectedFood = food;
                                  if (usePortion) {
                                    portionController.text = '1';
                                  } else {
                                    gramController.text =
                                        food.portionToGrams(1).toString();
                                  }
                                });
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Porsiyon / Gram seçimi
                  Row(
                    children: [
                      ChoiceChip(
                        label: Text(
                          'Porsiyon',
                          style: TextStyle(
                            color: usePortion ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontWeight: usePortion ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        selected: usePortion,
                        onSelected: (v) {
                          setModalState(() {
                            usePortion = true;
                            if (selectedFood != null) {
                              portionController.text = '1';
                              gramController.text =
                                  selectedFood!.portionToGrams(1).toString();
                            }
                          });
                        },
                        backgroundColor: const Color(0xFF2A2A2A),
                        selectedColor: const Color(0xFFC45C2C),
                        side: BorderSide(
                          color: usePortion ? const Color(0xFFC45C2C) : Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(
                          'Gram',
                          style: TextStyle(
                            color: !usePortion ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontWeight: !usePortion ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        selected: !usePortion,
                        onSelected: (v) {
                          setModalState(() {
                            usePortion = false;
                            portionController.clear();
                          });
                        },
                        backgroundColor: const Color(0xFF2A2A2A),
                        selectedColor: const Color(0xFFC45C2C),
                        side: BorderSide(
                          color: !usePortion ? const Color(0xFFC45C2C) : Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (usePortion)
                    TextField(
                      controller: portionController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Porsiyon sayısı',
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        hintText: '1',
                        filled: true,
                        fillColor: const Color(0xFF252525),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    )
                  else
                    TextField(
                      controller: gramController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Gram',
                        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                        hintText: '150',
                        filled: true,
                        fillColor: const Color(0xFF252525),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  const SizedBox(height: 20),
                  // Otomatik hesaplanan kalori
                  if (selectedFood != null && calculatedCalories > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC45C2C).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFC45C2C),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kalori (otomatik)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              Text(
                                '$calculatedCalories kcal',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE07B2D),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildMacroBadge('P', calculatedProtein.toStringAsFixed(0)),
                              const SizedBox(width: 8),
                              _buildMacroBadge('K', calculatedCarbs.toStringAsFixed(0)),
                              const SizedBox(width: 8),
                              _buildMacroBadge('Y', calculatedFat.toStringAsFixed(0)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                  // Öğün tipi
                  Text(
                    'Öğün',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['BREAKFAST', 'LUNCH', 'DINNER', 'SNACK'].map((type) {
                      final isSelected = selectedMealType == type;
                      return ChoiceChip(
                        label: Text(
                          _mealTypeLabels[type] ?? type,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (_) =>
                            setModalState(() => selectedMealType = type),
                        backgroundColor: const Color(0xFF2A2A2A),
                        selectedColor: const Color(0xFFC45C2C),
                        side: BorderSide(
                          color: isSelected ? const Color(0xFFC45C2C) : Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedFood != null && calculatedCalories > 0
                          ? () async {
                              final authProvider =
                                  Provider.of<AuthProvider>(context, listen: false);
                              final nutritionProvider =
                                  Provider.of<NutritionProvider>(context, listen: false);
                              final userId =
                                  authProvider.user?.id ?? StorageHelper.getUserId();
                              if (userId == null) return;

                              final mealDate = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                DateTime.now().hour,
                                DateTime.now().minute,
                              );

                              final request = MealRequest(
                                name: selectedFood!.name,
                                mealType: selectedMealType,
                                calories: calculatedCalories,
                                protein: calculatedProtein,
                                carbs: calculatedCarbs,
                                fat: calculatedFat,
                                mealDate: mealDate,
                              );

                              final success =
                                  await nutritionProvider.createMeal(userId, request);
                              if (success) {
                                await StorageHelper.addRecentFoodEntry(
                                    selectedFood!.id, totalGrams, selectedMealType);
                              }
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(success
                                        ? 'Yemek eklendi'
                                        : nutritionProvider.errorMessage ?? 'Hata'),
                                    backgroundColor:
                                        success ? Colors.green : Colors.red,
                                  ),
                                );
                              }
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC45C2C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Ekle',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() => searchDebounce?.cancel());
  }

  Widget _buildMacroBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

/// StatelessWidget - rebuild optimizasyonu (header provider değişince yeniden çizilmez)
class _NutritionHeader extends StatelessWidget {
  const _NutritionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFCC7A4A).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restaurant_menu_rounded,
              color: Color(0xFFCC7A4A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Beslenme',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
