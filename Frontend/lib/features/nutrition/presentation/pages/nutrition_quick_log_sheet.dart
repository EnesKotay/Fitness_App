part of 'nutrition_guide_page.dart';

class _NutritionQuickLogSheet extends StatefulWidget {
  final MealType mealType;
  final _Goal goal;
  final VoidCallback onFoodSearch;

  const _NutritionQuickLogSheet({
    required this.mealType,
    required this.goal,
    required this.onFoodSearch,
  });

  @override
  State<_NutritionQuickLogSheet> createState() => _NutritionQuickLogSheetState();
}

class _NutritionQuickLogSheetState extends State<_NutritionQuickLogSheet> {
  bool _isLoading = false;
  List<FoodItem> _frequentFoods = [];
  bool _loadingFrequents = true;

  @override
  void initState() {
    super.initState();
    _loadFrequents();
  }

  Future<void> _loadFrequents() async {
    final provider = Provider.of<DietProvider>(context, listen: false);
    final list = await provider.loadFrequentFoods();
    if (mounted) {
      setState(() {
        _frequentFoods = list;
        _loadingFrequents = false;
      });
    }
  }

  String _cleanFoodName(String part) {
    var clean = part.toLowerCase();
    // Remove quantity patterns
    clean = clean.replaceAll(RegExp(r'^\d+(\.\d+)?\s*(adet|dilim|g|gram|avuç|su bardağı|bardak|kaşık|yemek kaşığı|tatlı kaşığı)?\s*'), '');
    clean = clean.replaceAll(RegExp(r'^(bir avuç|yarım|birkaç|mavi|fırın|mevsim|haşlanmış|fırınlanmış|ızgara|tava)\s*'), '');
    return clean.trim();
  }

  double _extractGrams(String part, FoodItem food) {
    final gramMatch = RegExp(r'(\d+)\s*(g|gram)').firstMatch(part);
    if (gramMatch != null) {
      return double.parse(gramMatch.group(1)!);
    }
    final countMatch = RegExp(r'^(\d+(\.\d+)?)').firstMatch(part);
    if (countMatch != null) {
      final count = double.parse(countMatch.group(1)!);
      if (food.servings.isNotEmpty) {
        return count * food.servings.first.grams;
      }
      return count * 50.0;
    }
    if (food.servings.isNotEmpty) {
      return food.servings.first.grams;
    }
    return 100.0;
  }

  Future<void> _addFoodDirect(FoodItem food, double grams) async {
    setState(() => _isLoading = true);
    final provider = Provider.of<DietProvider>(context, listen: false);
    try {
      await provider.addEntry(
        food: food,
        grams: grams,
        mealType: widget.mealType,
        date: provider.selectedDate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food.name} başarıyla eklendi ✓'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ekleme hatası: $e'),
            backgroundColor: const Color(0xFFFF453A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addCompoundFood(String foodText) async {
    setState(() => _isLoading = true);
    final provider = Provider.of<DietProvider>(context, listen: false);
    final parts = foodText.split('+').map((s) => s.trim()).toList();
    
    int addedCount = 0;
    try {
      for (final part in parts) {
        final cleanName = _cleanFoodName(part);
        final searchResults = await provider.searchFoods(cleanName);
        if (searchResults.isNotEmpty) {
          final food = searchResults.first;
          final grams = _extractGrams(part, food);
          await provider.addEntry(
            food: food,
            grams: grams,
            mealType: widget.mealType,
            date: provider.selectedDate,
          );
          addedCount++;
        }
      }
      
      if (mounted) {
        if (addedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$addedCount adet besin plana göre eklendi ✓'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Yemek veri tabanında bulunamadı. Lütfen arama yapın.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFFFF9F0A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ekleme hatası: $e'),
            backgroundColor: const Color(0xFFFF453A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> _getGenericSuggestions() {
    switch (widget.mealType) {
      case MealType.breakfast:
        return const ['Yumurta', 'Yulaf ezmesi', 'Muz', 'Süzme Peynir', 'Avokado'];
      case MealType.lunch:
      case MealType.dinner:
        return const ['Tavuk Göğsü', 'Bulgur Pilavı', 'Pirinç Pilavı', 'Mevsim Salatası', 'Köfte', 'Fırın Somon'];
      case MealType.snack:
        return const ['Süzme Yoğurt', 'Ceviz', 'Çiğ Badem', 'Elma', 'Kefir'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final mealPlan = widget.goal.dailyPlan.firstWhere(
      (m) => m.label.toLowerCase() == widget.mealType.label.toLowerCase() ||
             (widget.mealType == MealType.snack && m.label.toLowerCase().contains('ara')),
      orElse: () => widget.goal.dailyPlan.first,
    );

    final genericSuggestions = _getGenericSuggestions();
    final activeColor = widget.goal.color;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: activeColor.withValues(alpha: 0.3)),
                  ),
                  child: Icon(Icons.bolt_rounded, color: activeColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hızlı ${widget.mealType.label} Ekle',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Tek tıkla öğününü kaydet',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white70),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'ÖNERİLEN PLAN YEMEĞİ',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: activeColor.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealPlan.food,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (mealPlan.macros.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            mealPlan.macros,
                            style: TextStyle(
                              color: activeColor.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : () => _addCompoundFood(mealPlan.food),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_rounded, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Ekle',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (!_loadingFrequents && _frequentFoods.isNotEmpty) ...[
              Text(
                'SIK TÜKETİLENLER',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 38,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _frequentFoods.length,
                  itemBuilder: (context, index) {
                    final food = _frequentFoods[index];
                    final defGrams = _defaultGuidePortion(widget.mealType);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        onPressed: _isLoading
                            ? null
                            : () => _addFoodDirect(food, defGrams),
                        backgroundColor: Colors.white.withValues(alpha: 0.04),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        label: Text(
                          food.name,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],

            Text(
              'POPÜLER HIZLI EKLEMELER',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: genericSuggestions.map((name) {
                return GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () async {
                          setState(() => _isLoading = true);
                          final provider = Provider.of<DietProvider>(context, listen: false);
                          final results = await provider.searchFoods(name);
                          if (mounted) {
                            setState(() => _isLoading = false);
                            if (results.isNotEmpty) {
                              final food = results.first;
                              final defGrams = _defaultGuidePortion(widget.mealType);
                              await _addFoodDirect(food, defGrams);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('"${name}" veritabanında bulunamadı. Lütfen arama yapın.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Text(
                      name,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onFoodSearch();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_rounded, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Detaylı Yemek Ara',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _defaultGuidePortion(MealType mealType) {
    switch (mealType) {
      case MealType.breakfast:
        return 120;
      case MealType.lunch:
      case MealType.dinner:
        return 180;
      case MealType.snack:
        return 80;
    }
  }
}
