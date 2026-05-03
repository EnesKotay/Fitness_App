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
import '../../../../core/widgets/premium_state_badge.dart';
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
      title: 'Diyetisyene Sor (AI)',
      description:
          'Bu sayfa, senin doğal dilde konuşarak beslenme kaydı yapmanı ve tavsiye almanı sağlayan akıllı asistanındır.\n\n'
          'Sadece bir şeyler yazıp göndererek yediklerini otomatik olarak kaydedebilir veya kalori/makro durumunu anında öğrenebilirsin.',
      tip: 'Yemek aramakla vakit kaybetmek yerine, yediğin yemeği doğrudan buraya yazabilirsin.',
    ),
    GuideStep(
      emoji: '🍽️',
      title: 'Doğal Dille Öğün Ekleme',
      description:
          'Yediklerini bir insanla konuşur gibi yaz:\n\n'
          '• "Öğle yemeğine 1 porsiyon döner ve 1 bardak ayran ekle"\n'
          '• "Sabah 2 yumurta, 5 zeytin ve 1 dilim kepek ekmek yedim"\n'
          '• "Ara öğüne 1 elma ekler misin?"\n\n'
          'AI yazdıklarını anlar, porsiyonları hesaplar ve ilgili öğüne anında ekler.',
      tip: 'Eğer bir öğün ismi (sabah, öğle, akşam) belirtmezsen, AI o anki saate bakarak en uygun öğünü tahmin eder.',
    ),
    GuideStep(
      emoji: '📊',
      title: 'Durum Özeti İsteme',
      description:
          'Gün içindeki durumunu merak ettiğinde sadece sor:\n\n'
          '• "Bugün ne yedim?"\n'
          '• "Kaç kalorim kaldı?"\n'
          '• "Bugün yeterince protein aldım mı?"\n\n'
          'Asistan sana o günkü makro dağılımını ve öğünlerinin detaylı bir özetini sunar.',
      tip: 'Her akşam yatmadan önce "Bana günümün özetini ver" diyerek günü değerlendirebilirsin.',
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
      tip: 'Ayrıca eklenen tüm öğünleri "Ana Sayfa" veya "Beslenme" sekmesinden de manuel olarak düzenleyebilirsin.',
    ),
    GuideStep(
      emoji: '💡',
      title: 'Tavsiye ve Alternatifler',
      description:
          'Sadece kayıt tutmakla kalma, ne yiyeceğini de danış:\n\n'
          '• "Kalan 400 kalorim için bol proteinli bir akşam yemeği öner"\n'
          '• "Canım tatlı çekiyor, düşük kalorili ne yiyebilirim?"\n\n'
          'Sana hedefine uygun tarifler ve yiyecek seçenekleri sunacaktır.',
      tip: 'Üst menüdeki kısayol çipleriyle (Bugün ne yedim, Kalori açığım ne kadar vb.) tek dokunuşla hazır soruları gönderebilirsin.',
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
      'kahvaltı', 'öğle', 'öğleye', 'öğlene', 'öğlen',
      'akşam', 'akşama', 'atıştırma', 'atıştırmalık',
      'atıştırmalığa', 'ara öğün', 'snack',
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
      'yemeğine', 'yemeği', 'öğününe', 'öğünüme', ...mealKeywords,
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
            'Bugünkü özet (${DateFormat('d MMM', 'tr_TR').format(date)}):',
          );
          buf.writeln('• Toplam: ${totals.totalKcal.round()} kcal');
          if (targetKcal > 0) {
            buf.writeln(
              '• Kalan: ${(targetKcal - totals.totalKcal).round()} kcal',
            );
          }
          buf.writeln(
            '• Protein: ${totals.totalProtein.round()}g · Karb.: ${totals.totalCarb.round()}g · Yağ: ${totals.totalFat.round()}g',
          );
          buf.writeln('');
          for (final type in MealType.values) {
            final mealEntries = provider.entriesForMeal(type);
            if (mealEntries.isEmpty) continue;
            buf.writeln('${type.label}:');
            for (final e in mealEntries) {
              buf.writeln(
                '  – ${e.foodName} (${e.grams.round()}g) · ${e.calculatedKcal.round()} kcal',
              );
            }
          }
          _addBot(buf.toString());
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
        final contextStr = provider.getDietContext();
        final aiService = provider.aiService!;

        // Get structured response directly from aiService
        final structuredResponse = await aiService
            .getStructuredNutritionResponse(text, contextStr);

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
              'Beslenme Asistanı',
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
      ),
      body: Column(
        children: [
          if (_isPremium)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFD97706).withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                children: [
                  const PremiumStateBadge(active: true, compact: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Premium aktif. AI diyet sohbeti tam erişimle açık.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryLight,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Nasıl yardımcı olabilirim?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Öğünlerini doğal dille yazabilir veya\nbeslenme hedeflerin hakkında sorular sorabilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            _buildSuggestionCard(
              'Öğle yemeğine 1 porsiyon döner ve ayran ekle',
              Icons.restaurant_rounded,
            ),
            const SizedBox(height: 12),
            _buildSuggestionCard(
              'Bugün kaç kalorim kaldı?',
              Icons.pie_chart_rounded,
            ),
            const SizedBox(height: 12),
            _buildSuggestionCard(
              'Yüksek proteinli bir akşam yemeği öner',
              Icons.lightbulb_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(String text, IconData icon) {
    return GestureDetector(
      onTap: () {
        _controller.text = text;
        _handleSend();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white.withValues(alpha: 0.2),
              size: 14,
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
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
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
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
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
              icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
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
                  color: !m.isUser ? Colors.white.withValues(alpha: 0.08) : null,
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
                          )
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
    final chips = [
      ('Bugün ne yedim?', Icons.summarize_rounded),
      ('Geri al', Icons.undo_rounded),
      ('Protein kaynağı öner', Icons.fitness_center_rounded),
      ('Akşama tavuk ekle', Icons.dinner_dining_rounded),
      ('Kalori açığım ne kadar?', Icons.analytics_rounded),
    ];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: chips.map((chip) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ActionChip(
              avatar: Icon(chip.$2, size: 14, color: AppColors.primaryLight),
              label: Text(
                chip.$1,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: () {
                _controller.text = chip.$1;
                _handleSend();
              },
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        }).toList(),
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
              '${meal.name} ($grams.toInt()g) $mealType\'e eklendi',
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
