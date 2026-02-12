import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/entities/food_item.dart';
import '../state/diet_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// Sohbet botu: "Bugün ne yedim?" → özet; "Öğle yemeğine döner ekle" → ekle ve onayla.
class DietChatPage extends StatefulWidget {
  const DietChatPage({super.key});

  @override
  State<DietChatPage> createState() => _DietChatPageState();
}

class _ChatMessage {
  final bool isUser;
  final String text;
  _ChatMessage({required this.isUser, required this.text});
}

class _DietChatPageState extends State<DietChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _addBot(
      'Merhaba! "Bugün ne yedim?" diye sorabilir veya "Öğle yemeğine döner ekle" gibi cümlelerle yemek ekleyebilirsin.',
    );
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

  void _addBot(String text) {
    setState(() => _messages.add(_ChatMessage(isUser: false, text: text)));
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

  /// Türkçe cümleyi parse et: "X yemeğine Y ekle" → (MealType, foodName, amount, unit)
  static (MealType?, String?, double?, String?) _parseAddIntent(String text) {
    final lower = text.trim().toLowerCase();
    
    // Miktar Regex: "200g", "100 gram", "2 adet", "yarım porsiyon" vb.
    final quantityMatch = RegExp(r'(\d+)\s*(gram|g|adet|porsiyon|dilim|bardak)').firstMatch(lower);
    double? amount;
    String? unit;
    if (quantityMatch != null) {
      amount = double.tryParse(quantityMatch.group(1) ?? '');
      unit = quantityMatch.group(2);
    }
    if (lower.contains('yarım')) amount = 0.5;

    final addMatch = RegExp(
      r'(kahvaltı|öğle|akşam|atıştırma|ara öğün|atıştırmalık|snack)\s*(yemeğine?|yemeği|öğününe?)?\s*(.+?)\s+ekle\s*$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(lower);

    if (addMatch != null) {
      final mealStr = addMatch.group(1) ?? '';
      MealType? type;
      switch (mealStr) {
        case 'kahvaltı': type = MealType.breakfast; break;
        case 'öğle': type = MealType.lunch; break;
        case 'akşam': type = MealType.dinner; break;
        case 'atıştırma':
        case 'ara öğün':
        case 'atıştırmalık':
        case 'snack': type = MealType.snack; break;
      }
      var foodName = addMatch.group(3)?.trim() ?? '';
      
      // Yemek adından miktar kısımlarını temizle
      if (quantityMatch != null) {
        foodName = foodName.replaceAll(quantityMatch.group(0)!, '').trim();
      }
      foodName = foodName.replaceAll('yarım', '').trim();

      if (type != null && foodName.isNotEmpty) return (type, foodName, amount, unit);
    }
    return (null, null, null, null);
  }

  /// "Bugün ne yedim?" / "özet" vb. mi?
  static bool _isSummaryIntent(String text) {
    final lower = text.trim().toLowerCase();
    return lower.contains('bugün') && (lower.contains('ne yedim') || lower.contains('yedim') || lower.contains('özet')) ||
        lower.contains('bugünkü özet') ||
        lower == 'özet' ||
        lower == 'ne yedim';
  }

  /// "Geri al" / "sil" komutu mu?
  static bool _isUndoIntent(String text) {
    final lower = text.trim().toLowerCase();
    return lower == 'geri al' || lower == 'sil' || lower == 'sonuncuyu sil' || lower == 'iptal et';
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
          _addBot('"$foodName" için bir yemek bulamadım. Farklı bir isim deneyebilir misiniz?');
        } else if (list.length > 1 && list[0].name != foodName) {
           // Belirsizlik: Çoklu sonuç
           _addBot('Hangi $foodName? En yakın seçenekler şunlar:');
           final top3 = list.take(3).toList();
           for (final f in top3) {
              _addBot('• ${f.name} (Ekle derseniz ekleyebilirim)');
              // Not: İleride bunları buton yapmak daha iyi olur
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
          _addBot('${food.name} (${grams.round()}g) ${mealType.label} öğününe eklendi.');
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
          buf.writeln('Bugünkü özet (${DateFormat('d MMM', 'tr_TR').format(date)}):');
          buf.writeln('• Toplam: ${totals.totalKcal.round()} kcal');
          if (targetKcal > 0) {
            buf.writeln('• Kalan: ${(targetKcal - totals.totalKcal).round()} kcal');
          }
          buf.writeln('• Protein: ${totals.totalProtein.round()}g · Karb.: ${totals.totalCarb.round()}g · Yağ: ${totals.totalFat.round()}g');
          buf.writeln('');
          for (final type in MealType.values) {
            final mealEntries = provider.entriesForMeal(type);
            if (mealEntries.isEmpty) continue;
            buf.writeln('${type.label}:');
            for (final e in mealEntries) {
              buf.writeln('  – ${e.foodName} (${e.grams.round()}g) · ${e.calculatedKcal.round()} kcal');
            }
          }
          _addBot(buf.toString());
        }
        setState(() => _loading = false);
        return;
      }

      // Gemini fallback
      if (provider.aiService != null && provider.aiService!.isReady) {
        final contextStr = provider.getDietContext();
        final response = await provider.aiService!.getChatResponse(text, contextStr);
        _addBot(response);
      } else {
        _addBot(
          'Anlayamadım. "Bugün ne yedim?" veya "Öğle yemeğine 200g tavuk ekle" gibi yazabilirsin.',
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
        title: const Text(
          'Beslenme Asistanı',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!m.isUser)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.smart_toy_rounded, color: AppColors.primaryLight, size: 18),
                        ),
                      if (!m.isUser) const SizedBox(width: 10),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: m.isUser
                                ? AppColors.primary.withValues(alpha: 0.25)
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: m.isUser ? AppColors.primary.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          child: Text(
                            m.text,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ),
                      if (m.isUser) const SizedBox(width: 10),
                      if (m.isUser)
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded, color: Colors.white70, size: 18),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 42),
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.95),
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Örn: Öğle yemeğine döner ekle',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _loading ? null : _handleSend,
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.all(12),
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
