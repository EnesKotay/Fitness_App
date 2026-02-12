import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui'; // For ImageFilter
import '../../domain/entities/food_item.dart';
import '../../domain/entities/meal_type.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import 'add_custom_food_page.dart';
import '../../ai_scan/presentation/pages/barcode_scan_page.dart';
import '../../ai_scan/presentation/pages/label_ocr_scan_page.dart';

/// Yemek arama: Premium tasarım, Glassmorphic search bar, hızlı öneriler.
class FoodSearchPage extends StatefulWidget {
  final MealType? selectedMealType;

  const FoodSearchPage({super.key, this.selectedMealType});

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  Timer? _debounce;
  final _query = ValueNotifier<String>('');
  final _searchController = TextEditingController();
  List<FoodItem> _recentFoods = [];
  List<FoodItem> _frequentFoods = [];
  List<FoodItem> _recommendedFoods = [];
  List<FoodItem> _list = [];
  bool _loading = false;
  bool _isAISearch = false;
  /// Seçili kategori (null = Tümü). Popüler Besinler bu kategoriye göre filtrelenir.
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _determineSmartMealType();
    _loadInitialData();
    _search();
    _query.addListener(_onQueryChanged);
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadRecents(),
      _loadFrequents(),
      _loadRecommendations(),
    ]);
  }

  void _determineSmartMealType() {
    if (widget.selectedMealType != null) return; // Zaten seçili geldiyse dokunma
    
    final hour = DateTime.now().hour;
    MealType smartType;
    if (hour >= 5 && hour < 11) {
      smartType = MealType.breakfast;
    } else if (hour >= 11 && hour < 15) {
      smartType = MealType.lunch;
    } else if (hour >= 17 && hour < 22) {
      smartType = MealType.dinner;
    } else {
      smartType = MealType.snack;
    }
    
    // Hack: Widget state'ini güncellememiz lazım ama parent'tan gelen parametreyi değiştiremeyiz.
    // Bu yüzden UI'da widget.selectedMealType ?? _smartMealType kullanacağız.
    // Ancak state içinde _smartMealType tutmalıyız.
    _smartMealType = smartType;
  }
  
  MealType? _smartMealType;
  
  MealType get _effectiveMealType => widget.selectedMealType ?? _smartMealType ?? MealType.snack;

  Future<void> _loadRecents() async {
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final recents = await provider.loadRecentFoods();
      if (mounted) {
        setState(() => _recentFoods = recents);
      }
    } catch (e) {
      debugPrint('FoodSearchPage _loadRecents error: $e');
    }
  }

  Future<void> _loadFrequents() async {
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final frequents = await provider.loadFrequentFoods();
      if (mounted) {
        setState(() => _frequentFoods = frequents);
      }
    } catch (e) {
      debugPrint('FoodSearchPage _loadFrequents error: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      // Boş arama ile ilk 20 öğeyi al
      final recs = await provider.searchFoods('', category: _selectedCategory);
      if (mounted) {
        setState(() => _recommendedFoods = recs.take(20).toList());
      }
    } catch (e) {
      debugPrint('FoodSearchPage _loadRecommendations error: $e');
    }
  }

  void _onQueryChanged() {
    if (!mounted) return;
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _search();
    });
  }

  Future<void> _search() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final provider = Provider.of<DietProvider>(context, listen: false);
      final list = _isAISearch && _query.value.isNotEmpty
          ? await provider.aiSearch(_query.value)
          : await provider.searchFoods(_query.value);
      if (mounted) {
        setState(() {
          _list = list;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('FoodSearchPage._search hatası: $e');
      if (mounted) {
        setState(() {
          _list = [];
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.removeListener(_onQueryChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AppGradientBackground(
        child: Column(
          children: [
            // Custom Glass Header
            _buildGlassHeader(context),
            
            Expanded(
              child: _loading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Aranıyor...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _query.value.isEmpty
                      ? _buildInitialContent()
                      : _list.isEmpty
                          ? _buildEmptyState(_query.value.trim().isEmpty)
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m, vertical: AppSpacing.s),
                              itemCount: _list.length,
                              itemBuilder: (context, index) {
                                final food = _list[index];
                                return _FoodListTile(
                                  food: food,
                                  selectedMealType: _effectiveMealType,
                                  onTap: () => _openDetail(food),
                                  onAddTap: () => _openPortion(food),
                                  onQuickAdd: (grams) => _quickAdd(food, grams),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(FoodItem food) {
    try {
      Navigator.of(context, rootNavigator: false).pushNamed(
        'detail',
        arguments: {'food': food, 'mealType': _effectiveMealType},
      ).then((_) {
         if (mounted && _query.value.isEmpty) _loadInitialData();
      });
    } catch (e) {
      debugPrint('FoodSearchPage detail navigation hatası: $e');
    }
  }

  void _openPortion(FoodItem food) {
    try {
      Navigator.of(context, rootNavigator: false).pushNamed(
        'portion',
        arguments: {'food': food, 'mealType': _effectiveMealType},
      ).then((_) {
        // Geri dönünce recent listesi güncellenmeli
        if (mounted && _query.value.isEmpty) _loadInitialData();
      });
    } catch (e) {
      debugPrint('FoodSearchPage portion navigation hatası: $e');
    }
  }

  void _quickAdd(FoodItem food, double grams) {
     try {
       // Hızlı ekleme için direkt porsiyon sayfasına yönlendir, ama gramajı hazır ver
       Navigator.of(context, rootNavigator: false).pushNamed(
         'portion',
         arguments: {
           'food': food,
           'mealType': _effectiveMealType,
           'initialGrams': grams,
         },
       ).then((_) {
         if (mounted && _query.value.isEmpty) _loadInitialData();
       });
     } catch (e) {
        debugPrint('Quick add error: $e');
     }
  }

  Widget _buildInitialContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hızlı Kategoriler (seçilen kategori önerileri filtreler)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('Tümü', Icons.apps_rounded),
                  _buildCategoryChip('Kahvaltılık', Icons.egg_alt_outlined),
                  _buildCategoryChip('Çorba', Icons.soup_kitchen_outlined),
                  _buildCategoryChip('Et / Tavuk', Icons.kebab_dining_outlined),
                  _buildCategoryChip('Sebze', Icons.eco_outlined),
                  _buildCategoryChip('Meyve', Icons.apple_outlined),
                  _buildCategoryChip('Tatlı', Icons.cake_outlined),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sık Yenenler (Ribbon)
          if (_frequentFoods.isNotEmpty)
            _buildRibbonSection('Sık Yenenler', _frequentFoods, isFrequent: true),

          // Son Eklenenler (Ribbon)
          if (_recentFoods.isNotEmpty)
            _buildRibbonSection('Son Eklenenler', _recentFoods),
          
          // Önerilenler / Popüler Besinler
          if (_recommendedFoods.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _selectedCategory ?? 'Popüler Besinler',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            ..._recommendedFoods.map((food) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FoodListTile(
                    food: food,
                    selectedMealType: _effectiveMealType,
                    onTap: () => _openDetail(food),
                    onAddTap: () => _openPortion(food),
                    onQuickAdd: (grams) => _quickAdd(food, grams),
                  ),
            )),
          ],
          
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildRibbonSection(String title, List<FoodItem> items, {bool isFrequent = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final food = items[index];
              final kcal = food.kcalPer100g;
              
              return GestureDetector(
                onTap: () => _openDetail(food),
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${kcal.round()} kcal',
                          style: const TextStyle(
                            color: AppColors.secondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryChip(String label, IconData icon) {
    final isTumu = label == 'Tümü';
    final isSelected = isTumu ? _selectedCategory == null : _selectedCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
        label: Text(label),
        backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1),
        labelStyle: TextStyle(color: Colors.white, fontSize: 13, fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
        side: BorderSide(color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onPressed: () {
          setState(() {
            _selectedCategory = isTumu ? null : label;
          });
          _searchController.text = label;
          _query.value = label;
          _loadRecommendations();
        },
      ),
    );
  }

  Widget _buildGlassHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 16,
            bottom: 16,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.85),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst Bar: Geri ve Başlık
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () {
                      try {
                        Navigator.of(context, rootNavigator: false).pop();
                      } catch (e) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  Text(
                    widget.selectedMealType?.label ?? 'Yemek Ara',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                   GestureDetector(
                    onTap: () async {
                      try {
                        final added = await Navigator.of(context, rootNavigator: false).pushNamed<bool>('add_custom_food');
                        if (added == true && mounted) _search();
                      } catch (e) {
                        debugPrint('FoodSearchPage add_custom_food navigation hatası: $e');
                        // Fallback: Doğrudan sayfayı açmayı dene
                        try {
                          if (!mounted) return;
                          final added = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => const AddCustomFoodPage()),
                          );
                          if (added == true && mounted) _search();
                        } catch (e2) {
                          debugPrint('FoodSearchPage fallback navigation hatası: $e2');
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // AI Scan Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildScanButton(
                      context,
                      icon: Icons.qr_code_scanner,
                      label: 'Barkod',
                      onTap: () async {
                         try {
                           final food = await Navigator.push(
                             context,
                             MaterialPageRoute(builder: (_) => BarcodeScanPage(initialMealType: widget.selectedMealType ?? MealType.snack)),
                           );
                           if (food != null && mounted) {
                               Navigator.of(context, rootNavigator: false).pushNamed(
                                     'portion',
                                     arguments: {'food': food, 'mealType': widget.selectedMealType},
                                   ).then((_) {
                                     if (mounted) {
                                       Navigator.of(context, rootNavigator: false).pop();
                                     }
                                   });
                           }
                         } catch (e) {
                           debugPrint('Barcode scan error: $e');
                         }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildScanButton(
                      context,
                      icon: Icons.document_scanner_outlined,
                      label: 'Etiket (OCR)',
                      onTap: () async {
                         try {
                           final food = await Navigator.push(
                             context,
                             MaterialPageRoute(builder: (_) => LabelOcrScanPage(initialMealType: widget.selectedMealType ?? MealType.snack)),
                           );
                           if (food != null && mounted) {
                                Navigator.of(context, rootNavigator: false).pushNamed(
                                     'portion',
                                     arguments: {'food': food, 'mealType': widget.selectedMealType},
                                   ).then((_) {
                                     if (mounted) {
                                       Navigator.of(context, rootNavigator: false).pop();
                                     }
                                   });
                           }
                         } catch (e) {
                           debugPrint('OCR scan error: $e');
                         }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Arama Çubuğu
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: _isAISearch 
                      ? AppColors.primary.withValues(alpha: 0.15) 
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAISearch 
                        ? AppColors.primary.withValues(alpha: 0.4) 
                        : Colors.white.withValues(alpha: 0.1),
                    width: _isAISearch ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      _isAISearch ? Icons.psychology_rounded : Icons.search, 
                      color: _isAISearch ? AppColors.primary : AppColors.textTertiary
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => _query.value = v,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: _isAISearch ? 'Örn: 1 yumurta ve yarım simit' : 'Yulaf, Yumurta, Elma...',
                          hintStyle: TextStyle(
                            color: _isAISearch 
                                ? AppColors.primary.withValues(alpha: 0.5) 
                                : AppColors.textTertiary
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isAISearch = !_isAISearch);
                        if (_query.value.isNotEmpty) _search();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _isAISearch ? AppColors.primary : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.auto_awesome,
                          color: _isAISearch ? Colors.white : AppColors.textTertiary,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_query.value.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          _query.value = '';
                        },
                        child: const Icon(Icons.close, color: AppColors.textTertiary, size: 20),
                      ),
                  ],
                ),
              ),
              
              // İnternetten Arama Switch (Consumer içinde)
               const SizedBox(height: 12),
               Consumer<DietProvider>(
                builder: (context, provider, _) {
                  if (!provider.useRemoteSearch && _query.value.isEmpty) {
                      return _buildQuickSuggestions();
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'İnternette ara',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 24,
                        child: Switch(
                          value: provider.useRemoteSearch,
                          onChanged: (v) {
                            provider.setUseRemoteSearch(v);
                            _search();
                          },
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildQuickSuggestions() {
    final suggestions = ['Yumurta', 'Yulaf', 'Tavuk', 'Pilav', 'Muz', 'Kahve'];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: suggestions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8), // Standard is fine, but lint wants less
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () {
              _searchController.text = suggestions[index];
              _query.value = suggestions[index];
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              alignment: Alignment.center,
              child: Text(
                suggestions[index],
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isQueryEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isQueryEmpty ? Icons.search_rounded : Icons.inbox_rounded,
              size: 72,
              color: AppColors.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              isQueryEmpty ? 'Aramaya başla' : 'Sonuç bulunamadı',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isQueryEmpty
                  ? 'Yukarıya yemek adı yaz veya hızlı önerilere tıkla'
                  : 'Bu arama için kayıt yok. Farklı bir kelime dene veya özel yemek ekle.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryLight, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FoodListTile extends StatelessWidget {
  final FoodItem food;
  final MealType? selectedMealType;
  final VoidCallback onTap;
  final VoidCallback onAddTap;
  final void Function(double grams) onQuickAdd;

  const _FoodListTile({
    required this.food,
    required this.selectedMealType,
    required this.onTap,
    required this.onAddTap,
    required this.onQuickAdd,
  });

  @override
  Widget build(BuildContext context) {
    final kcal = food.kcalPer100g;
    final p = food.proteinPer100g.round();
    final c = food.carbPer100g.round();
    final f = food.fatPer100g.round();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Macro Pills
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _macroPill('${kcal.round()} kcal', AppColors.secondary),
                            const SizedBox(width: 8),
                            _macroPill('P $p', const Color(0xFF5B9BFF)),
                            const SizedBox(width: 6),
                            _macroPill('K $c', const Color(0xFF4CD1A3)),
                            const SizedBox(width: 6),
                            _macroPill('Y $f', const Color(0xFFFFB74D)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Quick Action Buttons
                      Row(
                        children: [
                          _QuickGramChip(label: '100g', onTap: () => onQuickAdd(100)),
                          const SizedBox(width: 8),
                          _QuickGramChip(label: '150g', onTap: () => onQuickAdd(150)),
                          const Spacer(),
                          GestureDetector(
                            onTap: onAddTap,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.tune_rounded, size: 14, color: AppColors.primaryLight),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Özelleştir',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _macroPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _QuickGramChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickGramChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
            ),
          ),
        ),
      ),
    );
  }
}
