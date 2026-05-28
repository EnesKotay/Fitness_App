import 'package:flutter/material.dart';
import '../../../../core/services/page_guide_service.dart';
import '../../../../core/widgets/page_guide_overlay.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/food_item.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/ai_safety_helper.dart';
import '../../models/nutrition_ai_response.dart';
import '../widgets/meal_card.dart';
import '../../../auth/providers/auth_provider.dart';

/// Sohbet botu: "Bugün ne yedim?" → özet; "Öğle yemeğine döner ekle" → ekle ve onayla.
class DietChatPage extends StatefulWidget {
  const DietChatPage({super.key});

  @override
  State<DietChatPage> createState() => _DietChatPageState();
}

class _ChatMessage {
  final bool isUser;
  final String text;
  final NutritionAiResponseModel? structuredResponse;

  _ChatMessage({
    required this.isUser,
    required this.text,
    this.structuredResponse,
  });
}

class _DietChatPageState extends State<DietChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;
  bool _isPremium = false;
  bool _backendReady = true;

  static const List<GuideStep> _guideSteps = [
    GuideStep(
      emoji: '🤖',
      title: 'AI Koç',
      description:
          'Yediklerini yaz, kalori-makro durumunu sor veya öğün fikri al.',
      tip: 'Örneğin: "Öğle yemeğine 200 g tavuk ekle".',
    ),
    GuideStep(
      emoji: '🍽️',
      title: 'Doğal Dille Öğün Ekle',
      description: 'AI Koç porsiyonu hesaplar ve uygun öğüne kayıt açar.',
      tip: 'Öğün adı yazmazsan günün saatine göre tahmin eder.',
    ),
    GuideStep(
      emoji: '📊',
      title: 'Günlük Özet',
      description:
          'Bugün ne yediğini, ne kadar kalori kaldığını ve protein durumunu sor.',
      tip: '"Bana günümün özetini ver" kısa ve yeterli.',
    ),
    GuideStep(
      emoji: '🔁',
      title: 'İşlemleri Geri Alma',
      description:
          'Eğer asistan yanlış bir yemeği eklerse veya fikrini değiştirirsen:\n\n'
          '• "Son eklediğimi sil"\n'
          '• "İptal et"\n'
          '• "Geri al"\n\n'
          'Yazman yeterlidir. Sistem en son eklenen öğünü anında diyet listenden çıkarır.',
      tip:
          'Ayrıca eklenen tüm öğünleri "Ana Sayfa" veya "Beslenme" sekmesinden de manuel olarak düzenleyebilirsin.',
    ),
    GuideStep(
      emoji: '💡',
      title: 'Tavsiye ve Alternatifler',
      description:
          'Sadece kayıt tutmakla kalma, ne yiyeceğini de danış:\n\n'
          '• "Kalan 400 kalorim için bol proteinli bir akşam yemeği öner"\n'
          '• "Canım tatlı çekiyor, düşük kalorili ne yiyebilirim?"\n\n'
          'Sana hedefine uygun tarifler ve yiyecek seçenekleri sunacaktır.',
      tip:
          'Üst menüdeki kısayol çipleriyle (Bugün ne yedim, Kalori açığım ne kadar vb.) tek dokunuşla hazır soruları gönderebilirsin.',
    ),
  ];

  Future<void> _showGuide() async {
    if (!mounted) return;
    await showPageGuide(context, steps: _guideSteps);
  }

  Future<void> _checkFirstVisitGuide() async {
    if (await PageGuideService.hasSeenGuide('diet_chat')) return;
    await PageGuideService.markGuideSeen('diet_chat');
    if (mounted) await _showGuide();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _checkPremiumBadge();
      _checkBackendStatus();
      await _checkFirstVisitGuide();
    });
  }

  Future<void> _checkPremiumBadge() async {
    final auth = context.read<AuthProvider>();
    final tier = auth.user?.premiumTier?.toLowerCase().trim();
    if (tier == 'premium') {
      if (mounted) setState(() => _isPremium = true);
      return;
    }
    try {
      final aiService = context.read<DietProvider>().aiService;
      final ok = await aiService?.checkPremiumStatus() ?? false;
      if (mounted && ok) {
        auth.setPremiumActive(true);
        setState(() => _isPremium = true);
      }
    } catch (_) {
      // Badge check failed — badge stays false, feature still accessible
    }
  }

  Future<void> _checkBackendStatus() async {
    try {
      final ok = await AiSafetyHelper.instance.checkBackendHealth();
      if (!mounted) return;
      setState(() => _backendReady = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _backendReady = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addUser(String text) {
    setState(() => _messages.add(_ChatMessage(isUser: true, text: text)));
    _scrollToEnd();
  }

  void _addBot(String text, {NutritionAiResponseModel? structuredResponse}) {
    setState(
      () => _messages.add(
        _ChatMessage(
          isUser: false,
          text: text,
          structuredResponse: structuredResponse,
        ),
      ),
    );
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Öğün anahtar kelimesini MealType'a çevirir.
  static MealType? _parseMealType(String word) {
    switch (word) {
      case 'kahvaltı':
        return MealType.breakfast;
      case 'öğle':
      case 'öğleye':
      case 'öğlene':
      case 'öğlen':
        return MealType.lunch;
      case 'akşam':
      case 'akşama':
      case 'akşamıma':
        return MealType.dinner;
      case 'atıştırma':
      case 'ara öğün':
      case 'atıştırmalık':
      case 'snack':
      case 'atıştırmalığa':
        return MealType.snack;
      default:
        return null;
    }
  }

  /// Türkçe cümleyi parse et — kelime sırası bağımsız.
  /// Desteklenen formlar:
  ///   "öğle yemeğine 200g tavuk ekle"
  ///   "tavuk ekle öğleye"
  ///   "kahvaltıya yumurta ekle"
  ///   "akşam yemeğine ekle tavuk"
  static (MealType?, String?, double?, String?) _parseAddIntent(String text) {
    final lower = text.trim().toLowerCase();

    // "ekle" fiili yok → add intent değil
    if (!lower.contains('ekle')) return (null, null, null, null);

    // Miktar: "200g", "100 gram", "2 adet", "yarım porsiyon" vb.
    final quantityMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(gram|g|adet|porsiyon|dilim|bardak|ml|litre)',
    ).firstMatch(lower);
    double? amount;
    String? unit;
    if (quantityMatch != null) {
      amount = double.tryParse(quantityMatch.group(1)!.replaceAll(',', '.'));
      unit = quantityMatch.group(2);
    }
    if (lower.contains('yarım')) amount ??= 0.5;

    // Öğün tespiti: herhangi bir konumda öğün kelimesi ara
    MealType? type;
    final mealKeywords = [
      'kahvaltı',
      'öğle',
      'öğleye',
      'öğlene',
      'öğlen',
      'akşam',
      'akşama',
      'atıştırma',
      'atıştırmalık',
      'atıştırmalığa',
      'ara öğün',
      'snack',
    ];
    for (final kw in mealKeywords) {
      if (lower.contains(kw)) {
        type = _parseMealType(kw);
        if (type != null) break;
      }
    }

    if (type == null) return (null, null, null, null);

    // Yemek adı: öğün kelimeleri, "ekle", miktar ve bağlaçlar çıkarıldıktan sonra kalan
    var foodName = lower;
    // Çıkar: öğün ifadeleri
    for (final kw in [
      'yemeğine',
      'yemeği',
      'öğününe',
      'öğünüme',
      ...mealKeywords,
    ]) {
      foodName = foodName.replaceAll(kw, ' ');
    }
    // Çıkar: miktar
    if (quantityMatch != null) {
      foodName = foodName.replaceAll(quantityMatch.group(0)!, ' ');
    }
    // Çıkar: "ekle" ve "yarım"
    foodName = foodName
        .replaceAll(RegExp(r'\bekle\b'), ' ')
        .replaceAll('yarım', ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (foodName.isNotEmpty) {
      return (type, foodName, amount, unit);
    }
    return (null, null, null, null);
  }

  /// "Bugün ne yedim?" / "özet" vb. mi?
  static bool _isSummaryIntent(String text) {
    final lower = text.trim().toLowerCase();
    return lower.contains('bugün') &&
            (lower.contains('ne yedim') ||
                lower.contains('yedim') ||
                lower.contains('özet')) ||
        lower.contains('bugünkü özet') ||
        lower == 'özet' ||
        lower == 'ne yedim';
  }

  /// "Geri al" / "sil" komutu mu?
  static bool _isUndoIntent(String text) {
    final lower = text.trim().toLowerCase();
    return lower == 'geri al' ||
        lower == 'sil' ||
        lower == 'sonuncuyu sil' ||
        lower == 'iptal et';
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;
    _controller.clear();
    _addUser(text);

    setState(() => _loading = true);

    final provider = Provider.of<DietProvider>(context, listen: false);
    final date = provider.selectedDate;

    try {
      if (_isUndoIntent(text)) {
        await provider.undoLastEntry();
        _addBot('Son eklediğin öğünü sildim.');
        setState(() => _loading = false);
        return;
      }

      final (mealType, foodName, amount, unit) = _parseAddIntent(text);
      if (mealType != null && foodName != null && foodName.isNotEmpty) {
        final list = await provider.searchFoods(foodName);
        if (list.isEmpty) {
          _addBot(
            '"$foodName" için bir yemek bulamadım. Farklı bir isim deneyebilir misiniz?',
          );
        } else if (list.length > 1 && list[0].name != foodName) {
          // Belirsizlik: Çoklu sonuç
          _addBot('Hangi $foodName? En yakın seçenekler şunlar:');
          final top3 = list.take(3).toList();
          for (final f in top3) {
            _addBot('• ${f.name} (Ekle derseniz ekleyebilirim)');
          }
        } else {
          final food = list.first;
          double grams = 100.0;

          if (amount != null) {
            if (unit == 'g' || unit == 'gram') {
              grams = amount;
            } else {
              // Adet, porsiyon vb. için FoodItem.servings bak
              final serving = food.servings.firstWhere(
                (s) => s.label.toLowerCase().contains(unit ?? ''),
                orElse: () => food.servings.isNotEmpty
                    ? food.servings.first
                    : ServingUnit(id: 'default', label: 'gram', grams: 1.0),
              );
              grams = amount * serving.grams;
            }
          } else {
            final defaultServing = food.servings.isNotEmpty
                ? (food.servings.where((s) => s.isDefault).isNotEmpty
                      ? food.servings.where((s) => s.isDefault).first
                      : food.servings.first)
                : null;
            grams = defaultServing?.grams ?? 100.0;
          }

          await provider.addEntry(
            food: food,
            grams: grams,
            mealType: mealType,
            date: date,
          );
          _addBot(
            '${food.name} (${grams.round()}g) ${mealType.label} öğününe eklendi.',
          );
        }
        setState(() => _loading = false);
        return;
      }

      if (_isSummaryIntent(text)) {
        final entries = provider.entries;
        final totals = provider.totals;
        final targetKcal = provider.dailyTargetKcal ?? 0;
        if (entries.isEmpty) {
          _addBot('Bugün henüz kayıt yok. İlk yemeğini ekleyebilirsin.');
        } else {
          final buf = StringBuffer();
          buf.writeln(
            '📊 Bugünkü Özet — ${DateFormat('d MMMM', 'tr_TR').format(date)}',
          );
          buf.writeln('');

          // Kalori durumu
          final remaining = (targetKcal - totals.totalKcal).round();
          final pct = targetKcal > 0
              ? ((totals.totalKcal / targetKcal) * 100).round()
              : 0;
          buf.writeln(
            '🔥 Kalori: ${totals.totalKcal.round()} / $targetKcal kcal (%$pct)',
          );
          if (targetKcal > 0) {
            if (remaining > 0) {
              buf.writeln('   → $remaining kcal kaldı');
            } else {
              buf.writeln('   → Hedef aşıldı (${remaining.abs()} kcal fazla)');
            }
          }
          buf.writeln('');

          // Makrolar
          final profile = provider.profile;
          final proteinTarget = profile != null
              ? (profile.weight * 1.8).round()
              : 0;
          buf.writeln('💪 Protein: ${totals.totalProtein.round()}g'
              '${proteinTarget > 0 ? " / ${proteinTarget}g" : ""}');
          buf.writeln(
            '🌾 Karb: ${totals.totalCarb.round()}g · 🫒 Yağ: ${totals.totalFat.round()}g',
          );
          buf.writeln('');

          // Öğünler
          for (final type in MealType.values) {
            final mealEntries = provider.entriesForMeal(type);
            if (mealEntries.isEmpty) continue;
            final mealKcal = mealEntries
                .fold(0.0, (sum, e) => sum + e.calculatedKcal)
                .round();
            buf.writeln('${type.label} ($mealKcal kcal):');
            for (final e in mealEntries) {
              buf.writeln(
                '  • ${e.foodName} (${e.grams.round()}g) · ${e.calculatedKcal.round()} kcal',
              );
            }
            buf.writeln('');
          }

          // Mini insight
          final hour = DateTime.now().hour;
          if (proteinTarget > 0 &&
              totals.totalProtein < proteinTarget * 0.7 &&
              hour < 21) {
            final gap = (proteinTarget - totals.totalProtein.round());
            buf.writeln(
              '⚡ İpucu: Protein hedefine $gap g kaldı. Akşam öğününde protein ağırlıklı bir seçenek ekle.',
            );
          } else if (remaining > 300 && hour < 19) {
            buf.writeln(
              '⚡ İpucu: $remaining kcal alanın var. Gün içinde besleyici bir ara öğün ekleyebilirsin.',
            );
          } else if (remaining < -200) {
            buf.writeln(
              '⚡ İpucu: Kalori hedefini ${remaining.abs()} kcal geçtin. Kalan öğünlerde hafif ve lifli seçimler yap.',
            );
          } else if (totals.totalKcal > 0 && pct >= 90) {
            buf.writeln(
              '✅ İyi iş! Kalori hedefine çok yakınsın.',
            );
          }

          _addBot(buf.toString().trimRight());
        }
        setState(() => _loading = false);
        return;
      }

      // Gemini fallback with structured response
      if (!_backendReady) {
        _addBot(
          'AI servisi şu an erişilemiyor. "Bugün ne yedim?" özeti ve manuel ekleme komutları çalışmaya devam ediyor.',
        );
      } else if (provider.aiService != null && provider.aiService!.isReady) {
        final nutritionContext = provider.getNutritionAiContext();
        final contextStr =
            nutritionContext['summaryText'] as String? ??
            provider.getDietContext();
        final aiService = provider.aiService!;

        // Get structured response with full nutrition context (goal, restrictions, today's foods)
        final structuredResponse = await aiService
            .getStructuredNutritionResponse(
              text,
              contextStr,
              nutritionContext: nutritionContext,
            );

        final reply = structuredResponse.reply;
        if (reply != null && reply.isNotEmpty) {
          _addBot(reply);
        }
        if (structuredResponse.hasMeals) {
          _addBot('', structuredResponse: structuredResponse);
        } else if (reply == null || reply.isEmpty) {
          _addBot('Bir yanit olusturulamadi. Lutfen tekrar deneyin.');
        }
      } else {
        _addBot(
          'AI hazır değil. "Bugün ne yedim?" veya "Öğle yemeğine 200g tavuk ekle" gibi temel komutları kullanabilirsin.',
        );
      }
    } catch (e) {
      _addBot('Bir hata oluştu: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'AI Koç',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isPremium
                      ? [const Color(0xFFD97706), const Color(0xFFF59E0B)]
                      : [const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isPremium ? 'Claude' : 'Gemini',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded, color: Colors.white70),
            onPressed: () => _showAssistantInfoSheet(context),
            tooltip: 'AI Koç hakkında',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isPremium)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFD97706).withValues(alpha: 0.12),
                    const Color(0xFF111827),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFD97706).withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      size: 15,
                      color: Color(0xFFEBC374),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Premium Aktif',
                          style: TextStyle(
                            color: Color(0xFFEBC374),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'AI Koç Claude ile tam erişimde çalışıyor',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF30D158),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          if (!_backendReady)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.45),
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.orangeAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI geçici olarak kapalı. Temel komutlarla devam edebilirsin.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _checkBackendStatus,
                    child: const Text('Yenile'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildMessage(m),
                      );
                    },
                  ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 24),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.6),
                          AppColors.primary.withValues(alpha: 0.2),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                        bottomLeft: Radius.circular(4),
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: const TypingIndicator(color: AppColors.primaryLight),
                  ),
                ],
              ),
            ),
          _buildQuickChips(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // Kullanıcı durumuna göre dinamik öneri kartları oluşturur
  List<({String text, IconData icon, Color color, String badge, String send})>
      _buildDynamicSuggestions(DietProvider provider) {
    final hour = DateTime.now().hour;
    final remaining = provider.remainingKcal.round();
    final protein = provider.totals.totalProtein.round();
    final proteinTarget = provider.profile != null
        ? (provider.profile!.weight * 1.8).round()
        : 0;
    final proteinGap = proteinTarget > 0 ? proteinTarget - protein : 0;
    final hasMeals = provider.entries.isNotEmpty;
    final waterLiters = provider.waterLiters;

    final suggestions =
        <({String text, IconData icon, Color color, String badge, String send})>[];

    // 1. Saat bazlı öğün önerisi
    if (!hasMeals || hour < 11) {
      if (hour < 11) {
        suggestions.add((
          text: 'Kahvaltıya yulaf ezmesi veya omlet ekle',
          icon: Icons.wb_sunny_rounded,
          color: const Color(0xFFFF9F0A),
          badge: 'Kahvaltı',
          send: 'Sabah kahvaltısı için 200 kcal civarında, yüksek proteinli bir öneri ver',
        ));
      } else if (hour < 15) {
        suggestions.add((
          text: 'Öğle yemeğine ne ekleyeyim?',
          icon: Icons.restaurant_rounded,
          color: const Color(0xFF30D158),
          badge: 'Öğle',
          send: 'Öğle yemeği için sağlıklı ve doyurucu bir öneri ver, mevcut kalori durumuma göre',
        ));
      } else if (hour < 20) {
        suggestions.add((
          text: 'Akşam yemeği için öneri yap',
          icon: Icons.dinner_dining_rounded,
          color: const Color(0xFF5B9BFF),
          badge: 'Akşam',
          send: 'Akşam yemeği için kalori ve protein dengemi göz önünde tutarak öneri yap',
        ));
      } else {
        suggestions.add((
          text: 'Gece atıştırması için ne yiyebilirim?',
          icon: Icons.nightlight_rounded,
          color: const Color(0xFFBF5AF2),
          badge: 'Gece',
          send: 'Gece geç saatte hafif, düşük kalorili ama doyurucu bir atıştırmalık öner',
        ));
      }
    }

    // 2. Protein açığı varsa
    if (proteinGap > 30) {
      suggestions.add((
        text: 'Protein hedefime $proteinGap g kaldı, ne yesem?',
        icon: Icons.fitness_center_rounded,
        color: const Color(0xFF32ADE6),
        badge: 'Protein',
        send: 'Protein hedefime $proteinGap gram kaldı. Hızlı protein tamamlamak için yüksek proteinli yemek öner',
      ));
    }

    // 3. Su azsa
    if (waterLiters < 1.2) {
      suggestions.add((
        text: 'Bugün çok az su içtim, hatırlat',
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF64D2FF),
        badge: 'Hidrasyon',
        send: 'Bugün yeterli su içmedim. Su tüketimi ve sağlığı hakkında kısa bir hatırlatma yap',
      ));
    }

    // 4. Kalori durumuna göre
    if (remaining > 400 && hasMeals) {
      suggestions.add((
        text: 'Kalan $remaining kcal ile ne yiyebilirim?',
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFF30D158),
        badge: 'Kalori',
        send: 'Bugün $remaining kcal alanım kaldı. Bu kalori ile besleyici ama hafif ne yiyebilirim?',
      ));
    } else if (remaining < -100) {
      suggestions.add((
        text: 'Kalori hedefimi aştım, ne yapmalıyım?',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFFF9F0A),
        badge: 'Dikkat',
        send: 'Kalori hedefimi ${(-remaining)} kcal aştım. Nasıl telafi etmeliyim?',
      ));
    }

    // 5. Günlük özet (her zaman ekle)
    if (!hasMeals) {
      suggestions.add((
        text: 'Bugün ne yemeliyim? Planla',
        icon: Icons.calendar_today_rounded,
        color: const Color(0xFFBF5AF2),
        badge: 'Günlük Plan',
        send: 'Bugün için sağlıklı bir günlük beslenme planı öner, hedeflerime uygun',
      ));
    } else {
      suggestions.add((
        text: 'Bugün ne yedim, özet ver',
        icon: Icons.summarize_rounded,
        color: const Color(0xFFFF9F0A),
        badge: 'Özet',
        send: 'Bugün ne yedim, özet ver',
      ));
    }

    // Minimum 4 kart garantisi
    final fallbacks = [
      (
        text: 'Yüksek proteinli bir akşam yemeği öner',
        icon: Icons.lightbulb_rounded,
        color: const Color(0xFFBF5AF2),
        badge: 'Öneri',
        send: 'Yüksek proteinli bir akşam yemeği öner',
      ),
      (
        text: 'Bugün kaç kalorim kaldı?',
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFF32ADE6),
        badge: 'Sorgula',
        send: 'Bugün kaç kalorim kaldı, hedefime ne kadar kaldı açıkla',
      ),
      (
        text: 'Öğle yemeğine 1 porsiyon döner ekle',
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF30D158),
        badge: 'Öğün Ekle',
        send: 'Öğle yemeğine 1 porsiyon döner ekle',
      ),
    ];

    for (final f in fallbacks) {
      if (suggestions.length >= 4) break;
      suggestions.add(f);
    }

    return suggestions.take(4).toList();
  }

  Widget _buildEmptyState() {
    final provider = Provider.of<DietProvider>(context, listen: false);
    final suggestions = _buildDynamicSuggestions(provider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Kompakt hero satırı ───────────────────────────────────────────
          Row(
            children: [
              // İkon circle
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.30),
                      AppColors.primary.withValues(alpha: 0.06),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.22),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryLight,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nasıl yardımcı olabilirim?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Öğün ekle, kalori sor veya tarif al.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 2×2 Yetenek grid ─────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _capabilityCell(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Öğün Ekle',
                  desc: 'Doğal dille yaz',
                  color: const Color(0xFF30D158),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _capabilityCell(
                  icon: Icons.analytics_outlined,
                  label: 'Kalori Sorgula',
                  desc: 'Kalan & hedef',
                  color: const Color(0xFF32ADE6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _capabilityCell(
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Tarif Öner',
                  desc: 'Öğüne uygun',
                  color: const Color(0xFFBF5AF2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _capabilityCell(
                  icon: Icons.summarize_outlined,
                  label: 'Günlük Özet',
                  desc: 'Ne yedim bugün',
                  color: const Color(0xFFFF9F0A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          // ── Bölüm başlığı ─────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 16,
                height: 1,
                color: AppColors.primary.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 8),
              Text(
                'Hızlı başlangıç',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Dinamik öneri kartları ────────────────────────────────────────
          ...suggestions.asMap().entries.map((entry) {
            final s = entry.value;
            final isLast = entry.key == suggestions.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
              child: _buildSuggestionCard(
                text: s.text,
                icon: s.icon,
                color: s.color,
                badge: s.badge,
                sendText: s.send,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _capabilityCell({
    required IconData icon,
    required String label,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard({
    required String text,
    required IconData icon,
    required Color color,
    required String badge,
    String? sendText,
  }) {
    return GestureDetector(
      onTap: () {
        _controller.text = sendText ?? text;
        _handleSend();
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 11, 14, 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Renkli sol şerit
            Container(
              width: 3,
              height: 36,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(99),
                  bottomRight: Radius.circular(99),
                ),
              ),
            ),
            // İkon circle
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.16),
              size: 12,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.85),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: _backendReady
                      ? 'Yediklerini yaz veya sor...'
                      : 'AI kapalı: temel komut yaz',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 15),
                onSubmitted: (_) => _handleSend(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _loading ? null : _handleSend,
              icon: const Icon(
                Icons.arrow_upward_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Gönder',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage m) {
    return Row(
      mainAxisAlignment: m.isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!m.isUser)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.6),
                  AppColors.primary.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        if (!m.isUser) const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: m.isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              // Message text
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: m.isUser
                      ? LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.85),
                            AppColors.primary.withValues(alpha: 0.65),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: !m.isUser
                      ? Colors.white.withValues(alpha: 0.08)
                      : null,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(m.isUser ? 20 : 4),
                    bottomRight: Radius.circular(m.isUser ? 4 : 20),
                  ),
                  border: Border.all(
                    color: m.isUser
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
                  boxShadow: m.isUser
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  m.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ),

              // Meal cards if structured response
              if (!m.isUser &&
                  m.structuredResponse != null &&
                  m.structuredResponse!.hasMeals) ...[
                const SizedBox(height: 8),
                const Text(
                  'Önerilen Yemekler',
                  style: TextStyle(
                    color: AppColors.primaryLight,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                ...m.structuredResponse!.meals.map(
                  (meal) => MealCard(
                    meal: meal,
                    onAddToDiary: () => _showAddMealDialog(context, meal),
                    onGenerateAlternative: () =>
                        _generateAlternative(context, meal),
                  ),
                ),
              ],

              // Follow-up questions
              if (!m.isUser &&
                  m.structuredResponse != null &&
                  m.structuredResponse!.hasFollowUpQuestions) ...[
                const SizedBox(height: 12),
                const Text(
                  'Sorular',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: m.structuredResponse!.followUpQuestions.map((
                    question,
                  ) {
                    return ActionChip(
                      label: Text(
                        question,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      onPressed: () {
                        _controller.text = question;
                        _handleSend();
                      },
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
        if (m.isUser) const SizedBox(width: 10),
        if (m.isUser)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ),
      ],
    );
  }

  Widget _buildQuickChips() {
    const chips = [
      (text: 'Bugün ne yedim?',     icon: Icons.summarize_rounded,       send: 'Bugün ne yedim, özet ver'),
      (text: 'Geri al',             icon: Icons.undo_rounded,             send: 'Son eklediğimi geri al'),
      (text: 'Protein öner',        icon: Icons.fitness_center_rounded,   send: 'Yüksek proteinli bir yemek öner'),
      (text: 'Tavuk ekle',          icon: Icons.dinner_dining_rounded,    send: 'Akşama 200g tavuk göğsü ekle'),
      (text: 'Kalori açığım?',      icon: Icons.analytics_rounded,        send: 'Bugünkü kalori açığım ne kadar?'),
    ];

    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, sep) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final chip = chips[i];
          return GestureDetector(
            onTap: () {
              _controller.text = chip.send;
              _handleSend();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(chip.icon, size: 13, color: AppColors.primaryLight),
                  const SizedBox(width: 6),
                  Text(
                    chip.text,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.80),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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

  /// Show dialog to select meal type, gram and portion
  void _showAddMealDialog(BuildContext context, SuggestedMealModel meal) {
    double selectedGram = 200; // default
    double selectedPortion = 1.0; // default

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final totalGram = selectedGram * selectedPortion;
          final scale = totalGram / 100.0;
          final scaledKcal = (meal.kcal * scale).round();
          final scaledProtein = (meal.proteinG * scale).round();
          final scaledCarbs = (meal.carbsG * scale).round();
          final scaledFat = (meal.fatG * scale).round();

          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(ctx).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  '"${meal.name}" ekle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Meal Type Selection
                const Text(
                  'Öğün tipi',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: MealType.values.map((type) {
                    return ActionChip(
                      label: Text(
                        type.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.5),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _addMealToDiary(
                          context,
                          meal,
                          type,
                          totalGram.roundToDouble(),
                        );
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Gramaj Selection
                Row(
                  children: [
                    const Text(
                      'Porsiyon boyutu: ',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${selectedGram.toInt()}g',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [50, 100, 150, 200, 250, 300].map((g) {
                    final isSelected = selectedGram == g.toDouble();
                    return ChoiceChip(
                      label: Text(
                        '${g}g',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      onSelected: (_) =>
                          setSheetState(() => selectedGram = g.toDouble()),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Portion Multiplier
                Row(
                  children: [
                    const Text(
                      'Kat: ',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    Text(
                      '${selectedPortion}x',
                      style: const TextStyle(
                        color: AppColors.primaryLight,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [0.5, 1.0, 1.5, 2.0].map((p) {
                    final isSelected = selectedPortion == p;
                    return ChoiceChip(
                      label: Text(
                        '${p}x',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      onSelected: (_) =>
                          setSheetState(() => selectedPortion = p),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Live Macro Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _macroDisplay(
                        label: 'kcal',
                        value: scaledKcal.toString(),
                        color: AppColors.primary,
                      ),
                      _macroDisplay(
                        label: 'Protein',
                        value: '${scaledProtein}g',
                        color: Colors.orange,
                      ),
                      _macroDisplay(
                        label: 'Karb',
                        value: '${scaledCarbs}g',
                        color: Colors.green,
                      ),
                      _macroDisplay(
                        label: 'Yağ',
                        value: '${scaledFat}g',
                        color: Colors.blue,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Total info
                Text(
                  'Toplam: ${totalGram.toInt()}g porsiyon',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Macro display widget
  Widget _macroDisplay({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  /// Actually add the meal to diary with selected grams
  Future<void> _addMealToDiary(
    BuildContext context,
    SuggestedMealModel meal,
    MealType mealType,
    double grams,
  ) async {
    final provider = context.read<DietProvider>();
    try {
      await provider.addAiMealToDiary(
        mealName: meal.name,
        kcal: meal.kcal.toDouble(),
        protein: meal.proteinG.toDouble(),
        carbs: meal.carbsG.toDouble(),
        fat: meal.fatG.toDouble(),
        mealType: mealType,
        grams: grams,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${meal.name} (${grams.toInt()}g) ${mealType}e eklendi',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ekleme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Generate alternative meal suggestion with smart prompt
  void _generateAlternative(BuildContext context, SuggestedMealModel meal) {
    // Smart prompt: keep same mealType, protein, reduce kcal by ~20%
    final prompt =
        '${meal.name} için aynı öğün tipinde, '
        'benzer tat profiline yakın, '
        'düşük kalorili alternatif öner. '
        'Protein mümkünse aynı kalsın, '
        'kaloriyi yaklaşık %20 düşür. '
        'Çıktıyı aynı JSON formatında ver.';
    _controller.text = prompt;
    _handleSend();
  }

  void _showAssistantInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_alt_rounded,
                    color: AppColors.primaryLight,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'AI Koç Nerede Kullanılır?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildInfoRow(
              icon: Icons.restaurant_menu_rounded,
              title: 'AI Koç - Beslenme',
              desc:
                  'Sadece yediklerine odaklanır. Yediğin yemekleri listene ekler, porsiyon hesaplar ve kalori/makro durumunu anında özetler.',
              color: AppColors.primaryLight,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.fitness_center_rounded,
              title: 'AI Koç - Genel',
              desc:
                  'Tüm fitness serüvenini takip eder. Antrenman programını değiştirir, vücut ölçülerini analiz eder ve sana genel motivasyon sağlar.',
              color: const Color(0xFF10B981), // Zümrüt yeşili
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Anladım'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String desc,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  final Color color;
  const TypingIndicator({super.key, required this.color});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            var t = (_controller.value - delay) % 1.0;
            if (t < 0) t += 1.0;
            final y = t < 0.5 ? (t * 2) : (1.0 - (t - 0.5) * 2);
            return Transform.translate(
              offset: Offset(0, -y * 4),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.5 + y * 0.5),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
