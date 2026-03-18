import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/premium_features.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../../../core/widgets/app_gradient_background.dart';
import '../../../../core/widgets/ambient_glow_background.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/screens/premium_screen.dart';
import '../../domain/entities/grocery_item.dart';
import '../../models/nutrition_ai_response.dart';
import '../state/diet_provider.dart';

class _GrocerySection {
  const _GrocerySection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<GroceryItem> items;
}

class _MealIdeaCardData {
  const _MealIdeaCardData({
    required this.title,
    required this.reason,
    this.prepMinutes,
    this.kcal,
  });

  final String title;
  final String reason;
  final int? prepMinutes;
  final int? kcal;
}

class SmartGroceryListPage extends StatefulWidget {
  const SmartGroceryListPage({
    super.key,
    this.seedItems = const [],
    this.seedReason,
    this.seedMealName,
  });

  final List<String> seedItems;
  final String? seedReason;
  final String? seedMealName;

  @override
  State<SmartGroceryListPage> createState() => _SmartGroceryListPageState();
}

class _SmartGroceryListPageState extends State<SmartGroceryListPage> {
  bool _isLoading = false;
  bool _isPremium = false;
  bool _isCheckingPremium = true;
  List<GroceryItem> _groceryList = [];
  List<_MealIdeaCardData> _mealIdeas = [];
  String _reason = '';
  String? _lastUpdatedLabel;
  bool _showOnlyPending = false;
  bool _loadedFromCache = false;
  final Set<String> _checkedItems = {};
  int _loadingMessageIndex = 0;

  static const List<String> _loadingMessages = [
    'Alisveris listen hazirlaniyor...',
    'Hedeflerine uygun urunler seciliyor...',
    'Kategoriler ve yemek fikirleri toparlaniyor...',
  ];

  bool get _hasPremiumAccess {
    final localTier = context
        .read<AuthProvider>()
        .user
        ?.premiumTier
        ?.toLowerCase()
        .trim();
    return localTier == 'premium' || _isPremium;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialList();
      _checkPremiumAndFetch();
    });
  }

  void _loadInitialList() {
    if (widget.seedItems.isNotEmpty && mounted) {
      setState(() {
        _groceryList = widget.seedItems.map(_seedItemToGroceryItem).toList();
        _reason =
            widget.seedReason ??
            'Sectigin tarifin malzemeleri alisveris listene aktarıldı.';
        _lastUpdatedLabel = _formatUpdatedAt(DateTime.now());
        _mealIdeas = [
          if (widget.seedMealName != null &&
              widget.seedMealName!.trim().isNotEmpty)
            _MealIdeaCardData(
              title: widget.seedMealName!.trim(),
              reason: 'Bu malzemelerle once bu tarifi hazirlayabilirsin.',
            ),
        ];
        _loadedFromCache = false;
      });
      return;
    }

    final cachedItems = StorageHelper.getSmartGroceryItems();
    if (cachedItems.isNotEmpty && mounted) {
      setState(() {
        _groceryList = cachedItems.map(GroceryItem.fromJson).toList();
        _mealIdeas = _deserializeMealIdeas(
          StorageHelper.getSmartGroceryMealIdeas(),
        );
        _reason = StorageHelper.getSmartGroceryReason();
        _lastUpdatedLabel = StorageHelper.getSmartGroceryUpdatedAt();
        _loadedFromCache = true;
      });
      return;
    }

    final cachedList = StorageHelper.getSmartGroceryList();
    if (cachedList.isEmpty || !mounted) return;

    setState(() {
      _groceryList = cachedList.map(_seedItemToGroceryItem).toList();
      _mealIdeas = _deserializeMealIdeas(
        StorageHelper.getSmartGroceryMealIdeas(),
      );
      _reason = StorageHelper.getSmartGroceryReason();
      _lastUpdatedLabel = StorageHelper.getSmartGroceryUpdatedAt();
      _loadedFromCache = true;
    });
  }

  Future<void> _checkPremiumAndFetch() async {
    try {
      final auth = context.read<AuthProvider>();
      if (isPremiumTier(auth.user?.premiumTier)) {
        if (mounted) {
          setState(() {
            _isPremium = true;
          });
        }
      }
      if (!_isPremium) {
        final provider = context.read<DietProvider>();
        final aiService = provider.aiService;
        if (aiService != null && aiService.isReady) {
          final res = await aiService.checkPremiumStatus();
          if (mounted && res != null) {
            auth.setPremiumActive(res);
            setState(() => _isPremium = res);
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isCheckingPremium = false);
      if (mounted &&
          !_isLoading &&
          widget.seedItems.isEmpty &&
          _hasPremiumAccess) {
        await _fetchGroceryList();
      }
    }
  }

  Future<void> _fetchGroceryList() async {
    if (!_hasPremiumAccess) return;
    final provider = context.read<DietProvider>();

    setState(() {
      _isLoading = true;
      _loadedFromCache = false;
      _loadingMessageIndex = 0;
    });
    _startLoadingMessageLoop();
    try {
      final generated = await provider.generateSmartGroceryItems(
        includePersonalSuggestions: true,
      );
      var mealIdeas = _fallbackMealIdeas(generated);
      var reason = _resolveReason(
        null,
        provider: provider,
        fromCache: false,
        localItemCount: generated.length,
      );
      var finalItems = generated;

      final aiService = provider.aiService;
      if (_hasPremiumAccess && aiService != null && aiService.isReady) {
        const prompt =
            'Haftalik beslenme planima gore market listesini ve pratik yemek fikirlerini iyilestir.';
        final response = await provider.getStructuredNutritionResponse(
          prompt,
          task: 'GROCERY_LIST',
          nutritionContext: {
            ...provider.getNutritionAiContext(),
            'plannedMeals': await provider.getWeeklyPlanSummaryAsync(),
            'baseShoppingList': generated.map((item) => item.toJson()).toList(),
          },
        );
        if (response != null) {
          mealIdeas = _resolveMealIdeas(response, generated);
          reason = _resolveReason(
            response.reply?.trim(),
            provider: provider,
            fromCache: false,
            localItemCount: generated.length,
          );
          finalItems = _mergeAiSuggestions(generated, response.shoppingList);
        }
      }
      await _persistGroceryState(finalItems, reason, mealIdeas);
      if (!mounted) return;
      setState(() {
        _groceryList = finalItems;
        _mealIdeas = mealIdeas;
        _reason = reason;
        _lastUpdatedLabel = _formatUpdatedAt(DateTime.now());
      });
    } catch (e) {
      final fallbackList = await provider.generateSmartGroceryItems(
        includePersonalSuggestions: true,
      );
      final mealIdeas = _fallbackMealIdeas(fallbackList);
      final reason = _resolveReason(
        '',
        provider: provider,
        fromCache: false,
        localItemCount: fallbackList.length,
      );
      await _persistGroceryState(fallbackList, reason, mealIdeas);
      if (!mounted) return;
      setState(() {
        _groceryList = fallbackList;
        _mealIdeas = mealIdeas;
        _reason = reason;
        _lastUpdatedLabel = _formatUpdatedAt(DateTime.now());
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  GroceryItem _seedItemToGroceryItem(String item) {
    return GroceryItem(
      name: item,
      normalizedName: item.trim().toLowerCase(),
      category: '',
      totalGrams: 0,
      quantityLabel: null,
      linkedMeals: const [],
      source: 'seed',
    );
  }

  void _startLoadingMessageLoop() {
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted || !_isLoading) return;
      setState(() {
        _loadingMessageIndex =
            (_loadingMessageIndex + 1) % _loadingMessages.length;
      });
      _startLoadingMessageLoop();
    });
  }

  Future<void> _persistGroceryState(
    List<GroceryItem> items,
    String reason,
    List<_MealIdeaCardData> mealIdeas,
  ) async {
    final updatedAt = DateTime.now();
    await StorageHelper.saveSmartGroceryList(
      items.map((item) => item.name).toList(),
    );
    await StorageHelper.saveSmartGroceryItems(
      items.map((item) => item.toJson()).toList(),
    );
    await StorageHelper.saveSmartGroceryReason(reason);
    await StorageHelper.saveSmartGroceryUpdatedAt(_formatUpdatedAt(updatedAt));
    await StorageHelper.saveSmartGroceryMealIdeas(
      _serializeMealIdeas(mealIdeas),
    );
  }

  String _resolveReason(
    String? aiReason, {
    required DietProvider provider,
    required bool fromCache,
    required int localItemCount,
  }) {
    if (aiReason != null && aiReason.isNotEmpty) {
      return aiReason;
    }

    final goal = provider.profile?.goal.name ?? 'maintain';
    final goalLabel = switch (goal) {
      'bulk' => 'kas kazanimi',
      'cut' => 'yag yakimi',
      'strength' => 'guc artisi',
      _ => 'dengeyi koruma',
    };
    final cacheNote = fromCache ? ' Son kaydedilen liste gosteriliyor.' : '';
    if (localItemCount > 0) {
      return 'Bu liste haftalik ogun planindaki porsiyonlardan ve favori tercihlerinden uretilerek $goalLabel hedefini destekleyecek sekilde duzenlendi.$cacheNote';
    }
    return 'Liste olusturmak icin haftalik ogun planina yemek ekledikce market ihtiyacin burada toparlanir.$cacheNote';
  }

  String _formatUpdatedAt(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String _buildShareText() {
    final buffer = StringBuffer();
    buffer.writeln('Akilli Alisveris Listem');
    if (_reason.isNotEmpty) {
      buffer.writeln(_reason);
      buffer.writeln();
    }
    for (final section in _buildSections()) {
      if (section.items.isEmpty) continue;
      buffer.writeln('${section.title}:');
      for (final item in section.items) {
        final checked = _checkedItems.contains(item.normalizedName)
            ? '[x]'
            : '[ ]';
        final details = [
          if (item.displayAmount.isNotEmpty) item.displayAmount,
          if (item.linkedMeals.isNotEmpty) item.linkedMeals.take(2).join(', '),
        ].join(' • ');
        buffer.writeln(
          details.isEmpty
              ? '$checked ${item.name}'
              : '$checked ${item.name} ($details)',
        );
      }
      buffer.writeln();
    }
    if (_mealIdeas.isNotEmpty) {
      buffer.writeln('Bunlarla ne yapabilirim:');
      for (final meal in _mealIdeas) {
        buffer.writeln('- ${meal.title}: ${meal.reason}');
      }
    }
    return buffer.toString().trim();
  }

  List<_MealIdeaCardData> _resolveMealIdeas(
    NutritionAiResponseModel response,
    List<GroceryItem> groceryList,
  ) {
    if (response.meals.isNotEmpty) {
      return response.meals.take(3).map(_mapMealIdea).toList();
    }
    return _fallbackMealIdeas(groceryList);
  }

  _MealIdeaCardData _mapMealIdea(SuggestedMealModel meal) {
    return _MealIdeaCardData(
      title: meal.name,
      reason: meal.reason.isNotEmpty
          ? meal.reason
          : 'Listedeki ana malzemelerle kolayca hazirlanabilir.',
      prepMinutes: meal.prepMinutes,
      kcal: meal.kcal > 0 ? meal.kcal : null,
    );
  }

  List<_MealIdeaCardData> _fallbackMealIdeas(List<GroceryItem> groceryList) {
    final joined = groceryList.map((item) => item.name).join(' ').toLowerCase();
    final ideas = <_MealIdeaCardData>[];

    if (_matchesAny(joined, [
      'yumurta',
      'lor',
      'peynir',
      'yesillik',
      'yeşillik',
    ])) {
      ideas.add(
        const _MealIdeaCardData(
          title: 'Proteinli Kahvalti Tabagi',
          reason:
              'Yumurta, lor ve yesilliklerle hizli bir kahvalti cikartabilirsin.',
          prepMinutes: 10,
        ),
      );
    }
    if (_matchesAny(joined, ['tavuk', 'pirinc', 'pirinç', 'bulgur', 'sebze'])) {
      ideas.add(
        const _MealIdeaCardData(
          title: 'Tavuklu Fit Kase',
          reason:
              'Tavuk, tahil ve sebzeleri birlestirip dengeli bir ogun hazirlayabilirsin.',
          prepMinutes: 20,
        ),
      );
    }
    if (_matchesAny(joined, [
      'yulaf',
      'muz',
      'sut',
      'süt',
      'yogurt',
      'yoğurt',
    ])) {
      ideas.add(
        const _MealIdeaCardData(
          title: 'Yulaf Bowl',
          reason:
              'Yulaf, sut veya yogurt ve meyveyle pratik bir ara ogun yapabilirsin.',
          prepMinutes: 5,
        ),
      );
    }
    if (ideas.isEmpty) {
      ideas.add(
        const _MealIdeaCardData(
          title: 'Karisik Hazirlik Tabagi',
          reason:
              'Listedeki protein, sebze ve karbonhidratlari birlestirip kolay bir gunluk meal prep yapabilirsin.',
          prepMinutes: 15,
        ),
      );
    }

    return ideas.take(3).toList();
  }

  List<GroceryItem> _mergeAiSuggestions(
    List<GroceryItem> localItems,
    List<String> aiSuggestions,
  ) {
    final merged = <String, GroceryItem>{
      for (final item in localItems) item.normalizedName: item,
    };
    for (final suggestion in aiSuggestions) {
      final normalized = suggestion.trim().toLowerCase();
      if (normalized.isEmpty || merged.containsKey(normalized)) continue;
      merged[normalized] = GroceryItem(
        name: suggestion.trim(),
        normalizedName: normalized,
        category: '',
        totalGrams: 0,
        quantityLabel: null,
        linkedMeals: const ['AI onerisi'],
        source: 'ai',
      );
    }
    return merged.values.toList();
  }

  List<String> _serializeMealIdeas(List<_MealIdeaCardData> items) {
    return items
        .map(
          (item) => [
            item.title,
            item.reason,
            item.prepMinutes?.toString() ?? '',
            item.kcal?.toString() ?? '',
          ].join('||'),
        )
        .toList();
  }

  List<_MealIdeaCardData> _deserializeMealIdeas(List<String> rawItems) {
    return rawItems.map((item) {
      final parts = item.split('||');
      return _MealIdeaCardData(
        title: parts.isNotEmpty ? parts[0] : 'Ogun Fikri',
        reason: parts.length > 1 && parts[1].isNotEmpty
            ? parts[1]
            : 'Listedeki malzemelerle hazirlanabilir.',
        prepMinutes: parts.length > 2 ? int.tryParse(parts[2]) : null,
        kcal: parts.length > 3 ? int.tryParse(parts[3]) : null,
      );
    }).toList();
  }

  Future<void> _copyList() async {
    await Clipboard.setData(ClipboardData(text: _buildShareText()));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Liste panoya kopyalandi.')));
  }

  Future<void> _shareList() async {
    try {
      await SharePlus.instance.share(ShareParams(text: _buildShareText()));
    } catch (_) {
      await _copyList();
    }
  }

  List<_GrocerySection> _buildSections() {
    final groups = <String, List<GroceryItem>>{
      'Proteinler': [],
      'Sebze ve Meyveler': [],
      'Karbonhidratlar': [],
      'Saglikli Yaglar': [],
      'Ekstra ve Atistirmaliklar': [],
    };

    for (final item in _groceryList) {
      final normalized = item.normalizedName;
      final explicitCategory = item.category.toLowerCase();
      final key = switch (normalized) {
        _
            when explicitCategory.contains('et') ||
                explicitCategory.contains('tavuk') ||
                explicitCategory.contains('balik') ||
                explicitCategory.contains('protein') ||
                explicitCategory.contains('sut') =>
          'Proteinler',
        _
            when explicitCategory.contains('sebze') ||
                explicitCategory.contains('meyve') =>
          'Sebze ve Meyveler',
        _
            when explicitCategory.contains('pilav') ||
                explicitCategory.contains('makarna') ||
                explicitCategory.contains('tahil') ||
                explicitCategory.contains('ekmek') =>
          'Karbonhidratlar',
        _
            when _matchesAny(normalized, [
              'tavuk',
              'hindi',
              'yumurta',
              'ton',
              'balik',
              'somon',
              'et',
              'kofte',
              'lor',
              'peynir',
              'yoğurt',
              'yogurt',
              'kefir',
              'süt',
              'sut',
              'bakliyat',
              'mercimek',
              'nohut',
              'fasulye',
              'protein',
            ]) =>
          'Proteinler',
        _
            when _matchesAny(normalized, [
              'domates',
              'salatalik',
              'biber',
              'yesillik',
              'yeşillik',
              'ispanak',
              'brokoli',
              'muz',
              'elma',
              'avokado',
              'meyve',
              'sebze',
              'limon',
            ]) =>
          'Sebze ve Meyveler',
        _
            when _matchesAny(normalized, [
              'yulaf',
              'pirinç',
              'pirinc',
              'bulgur',
              'makarna',
              'ekmek',
              'patates',
              'tortilla',
              'lavaş',
              'lavas',
              'quinoa',
              'granola',
            ]) =>
          'Karbonhidratlar',
        _
            when _matchesAny(normalized, [
              'zeytinyagi',
              'zeytinyağı',
              'fistik ezmesi',
              'badem',
              'ceviz',
              'findik',
              'tohum',
              'chia',
              'keten',
            ]) =>
          'Saglikli Yaglar',
        _ => 'Ekstra ve Atistirmaliklar',
      };
      final isPending =
          !_showOnlyPending || !_checkedItems.contains(item.normalizedName);
      if (isPending) {
        groups[key]!.add(item);
      }
    }

    return const [
          ('Proteinler', Icons.egg_alt_rounded),
          ('Sebze ve Meyveler', Icons.eco_rounded),
          ('Karbonhidratlar', Icons.rice_bowl_rounded),
          ('Saglikli Yaglar', Icons.water_drop_rounded),
          ('Ekstra ve Atistirmaliklar', Icons.shopping_bag_rounded),
        ]
        .map((entry) {
          return _GrocerySection(
            title: entry.$1,
            icon: entry.$2,
            items: groups[entry.$1] ?? const [],
          );
        })
        .where((section) => section.items.isNotEmpty)
        .toList();
  }

  bool _matchesAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) return true;
    }
    return false;
  }

  Widget _buildReasonCard() {
    if (_reason.isEmpty && _lastUpdatedLabel == null && !_loadedFromCache) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Neden bu liste?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_lastUpdatedLabel != null)
                      Text(
                        _loadedFromCache
                            ? 'Son kayitli liste • $_lastUpdatedLabel'
                            : 'Bugun guncellendi • $_lastUpdatedLabel',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (_reason.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              _reason,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final message = _loadingMessages[_loadingMessageIndex];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              message,
              key: ValueKey(message),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sana uygun listeyi secip duzenli bir sekilde hazirliyoruz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshingBanner() {
    final message = _loadingMessages[_loadingMessageIndex];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: const CircularProgressIndicator(
              strokeWidth: 2.2,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _buildActionChip(
          icon: Icons.copy_all_rounded,
          label: 'Kopyala',
          onTap: _copyList,
        ),
        _buildActionChip(
          icon: Icons.ios_share_rounded,
          label: 'Paylas',
          onTap: _shareList,
        ),
        _buildActionChip(
          icon: _showOnlyPending
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          label: _showOnlyPending ? 'Tümünü Göster' : 'Tamamlananları Gizle',
          onTap: () {
            setState(() => _showOnlyPending = !_showOnlyPending);
          },
        ),
      ],
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(_GrocerySection section) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(section.icon, color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Text(
                    section.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${section.items.length} urun',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...section.items.map((item) {
                final isChecked = _checkedItems.contains(item.normalizedName);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isChecked
                          ? AppColors.secondary.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isChecked
                            ? AppColors.secondary.withValues(alpha: 0.28)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: CheckboxListTile(
                      dense: true,
                      value: isChecked,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: TextStyle(
                              color: isChecked ? Colors.white54 : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              decoration: isChecked
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (item.displayAmount.isNotEmpty ||
                              item.linkedMeals.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                [
                                  if (item.displayAmount.isNotEmpty)
                                    item.displayAmount,
                                  if (item.linkedMeals.isNotEmpty)
                                    item.linkedMeals.take(2).join(' • '),
                                ].join('  ·  '),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.46),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: item.source == 'ai'
                          ? const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'AI tamamlama onerisi',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                      activeColor: AppColors.secondary,
                      checkColor: Colors.white,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _checkedItems.add(item.normalizedName);
                          } else {
                            _checkedItems.remove(item.normalizedName);
                          }
                        });
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMealIdeasCard() {
    if (_mealIdeas.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.restaurant_menu_rounded, color: AppColors.secondary),
              SizedBox(width: 10),
              Text(
                'Bunlarla Ne Yapabilirsin?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._mealIdeas.map((meal) {
            final meta = <String>[
              if (meal.prepMinutes != null) '${meal.prepMinutes} dk',
              if (meal.kcal != null) '~${meal.kcal} kcal',
            ];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      meal.reason,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        meta.join('  •  '),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLockedState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
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
                  Icons.shopping_cart_rounded,
                  color: Color(0xFFFBBF24),
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Akıllı alışveriş listesi Premium\'a özel',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Haftalık öğün planından otomatik liste üretmek ve AI yemek fikirleri görmek için Premium\'a geç.',
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
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremiumAccess =
        isPremiumTier(context.watch<AuthProvider>().user?.premiumTier) ||
        _isPremium;

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Akıllı Alışveriş Listesi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _isLoading || !isPremiumAccess ? null : _fetchGroceryList,
          ),
        ],
      ),
      body: AppGradientBackground(
        imagePath: 'assets/images/nutrition_bg_dark.png',
        child: Stack(
          children: [
            const AmbientGlowBackground(),
            SafeArea(
              child: _isCheckingPremium
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.secondary,
                      ),
                    )
                  : !isPremiumAccess
                  ? _buildLockedState()
                  : _isLoading && _groceryList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildLoadingState().animate().fadeIn(
                          duration: 250.ms,
                        ),
                      ),
                    )
                  : _groceryList.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.shopping_cart_outlined,
                              color: Colors.white70,
                              size: 42,
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Liste henuz bos.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Haftalik ogun planina yemek ekledikce ihtiyac duydugun urunler burada toplanacak.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      children: [
                        if (_isLoading) _buildRefreshingBanner(),
                        if (!isPremiumAccess)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PremiumScreen(),
                                  ),
                                );
                              },
                              child: Ink(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.24),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.workspace_premium_rounded,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Liste haftalik planindan olusturuldu. Premium ile AI yemek fikirleri ve ekstra market onerileri acilir.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.86,
                                          ),
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        _buildReasonCard()
                            .animate()
                            .fadeIn(duration: 350.ms)
                            .slideY(begin: 0.06, end: 0),
                        const SizedBox(height: 14),
                        _buildActionBar().animate().fadeIn(
                          delay: 80.ms,
                          duration: 300.ms,
                        ),
                        const SizedBox(height: 18),
                        ..._buildSections().asMap().entries.map((entry) {
                          final index = entry.key;
                          final section = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildSectionCard(section)
                                .animate()
                                .fadeIn(delay: (index * 70).ms)
                                .slideX(begin: 0.04, end: 0),
                          );
                        }),
                        if (_mealIdeas.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _buildMealIdeasCard()
                              .animate()
                              .fadeIn(delay: 180.ms, duration: 320.ms)
                              .slideY(begin: 0.04, end: 0),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
