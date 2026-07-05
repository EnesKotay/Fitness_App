import 'dart:async';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/utils/storage_helper.dart';
import 'package:dio/dio.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../models/ai_coach_models.dart';
import '../services/ai_coach_service.dart';
import '../services/ai_coach_session_service.dart';
import '../services/ai_user_memory_service.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final String? imagePath;
  final DateTime createdAt;
  final CoachResponse? structuredResponse;
  final bool isError;
  final bool isSystemNote;
  final bool isThinking;
  final String? taskMode;
  final String? personality;
  final String? userPrompt;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.structuredResponse,
    this.imagePath,
    this.isError = false,
    this.isSystemNote = false,
    this.isThinking = false,
    this.taskMode,
    this.personality,
    this.userPrompt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AiCoachController extends ChangeNotifier {
  static const int maxPromptLength = 800;
  static const List<String> _safetyKeywords = [
    'ağrı',
    'agri',
    'ağrıyor',
    'agriyor',
    'acı',
    'aci',
    'sakat',
    'incin',
    'dizim',
    'belim',
    'omzum',
    'bileğim',
    'bilegim',
    'baş dön',
    'bas don',
    'göğüs ağr',
    'gogus agr',
    'nefes darl',
    'bayıl',
    'bayil',
    'tansiyon',
    'diyabet',
    'hamile',
    'hastayım',
    'hastayim',
  ];
  static const List<String> _nutritionKeywords = [
    'kahvalt',
    'öğle',
    'ogle',
    'öğlene',
    'oglene',
    'akşam yeme',
    'aksam yeme',
    'akşama',
    'aksama',
    'ara öğün',
    'ara ogun',
    'atıştır',
    'atistir',
    'ne yesem',
    'ne yemeliyim',
    'ne yiy',
    'ne iç',
    'ne ic',
    'yemek öner',
    'yemek oner',
    'öğün öner',
    'ogun oner',
    'menü',
    'menu',
    'tarif',
    'beslen',
    'kalori',
    'kcal',
    'makro',
    'protein',
    'karbonhidrat',
    'karb',
    'yağ',
    'yag',
    'diyet',
    'porsiyon',
    'gram',
    'tabak',
    'alışveriş',
    'alisveris',
    'market',
    'malzeme',
    'yulaf',
    'yumurta',
    'tavuk',
    'salata',
    'pilav',
    'yoğurt',
    'yogurt',
  ];
  static const List<String> _foodLogKeywords = [
    'yedim',
    'içtim',
    'ictim',
    'tükettim',
    'tukettim',
    'yediğim',
    'yedigim',
    'günlüğe ekle',
    'gunluge ekle',
    'yemeği ekle',
    'yemegi ekle',
    'öğünü ekle',
    'ogunu ekle',
    'kaç kalori',
    'kac kalori',
    'kalorisi ne',
  ];
  static const List<String> _hydrationKeywords = [
    'su içtim',
    'su ictim',
    'su ekle',
    'su kaydet',
    'su hedef',
    'su tüket',
    'su tuket',
    'hidrasyon',
    'susuz',
    'kaç litre',
    'kac litre',
  ];
  static const List<String> _supplementKeywords = [
    'kreatin',
    'creatine',
    'whey',
    'protein tozu',
    'preworkout',
    'pre-workout',
    'bcaa',
    'omega',
    'magnezyum',
    'vitamin',
    'kafein',
    'supplement',
  ];
  static const List<String> _workoutKeywords = [
    'antrenman',
    'antreman',
    'egzersiz',
    'hareket',
    'program',
    'set',
    'tekrar',
    'gym',
    'spor',
    'salon',
    'evde çalış',
    'evde calis',
    'ne çalış',
    'ne calis',
    'çalışmalıyım',
    'calismaliyim',
    'full body',
    'split',
    'push pull',
    'bacak',
    'göğüs',
    'gogus',
    'sırt',
    'sirt',
    'omuz',
    'kol',
    'kardiyo',
    'koşu',
    'kosu',
    'ısınma',
    'isinma',
    'esneme',
    'formum',
    'teknik',
  ];
  static const List<String> _analysisKeywords = [
    'analiz',
    'nasılım',
    'nasilim',
    'değerlendir',
    'degerlendir',
    'ilerleme',
    'trend',
    'durumum',
    'gidişat',
    'gidisat',
    'kilo veriyor muyum',
    'kilo alıyor muyum',
    'kilo aliyor muyum',
    'yağ yakıyor muyum',
    'yag yakiyor muyum',
    'hedefe yakın',
    'hedefe yakin',
    'rapor',
  ];
  static const List<String> _recoveryKeywords = [
    'toparlan',
    'dinlen',
    'uyku',
    'yorgun',
    'zorlan',
    'motivasyon',
    'moral',
    'stres',
    'üşen',
    'usen',
    'yapamıyorum',
    'yapamiyorum',
    'bıktım',
    'biktim',
    'enerjim yok',
    'çok yoruldum',
    'cok yoruldum',
  ];

  AiCoachController({
    AiCoachService? service,
    DailySummary? initialSummary,
    int? userId,
    AiCoachSessionService? sessionService,
  }) : _service = service ?? AiCoachService(),
       _sessionService = sessionService ?? AiCoachSessionService(),
       _userId = userId,
       _dailySummary =
           initialSummary ??
           const DailySummary(
             calories: 0,
             waterLiters: 0,
             workouts: 0,
             workoutMinutes: 0,
             workoutHighlights: <String>[],
           ) {
    _addInitialMessage();
  }

  final AiCoachService _service;
  final AiCoachSessionService _sessionService;
  final AiUserMemoryService _memoryService = AiUserMemoryService();
  final int? _userId;
  final List<ChatMessage> _messages = [];
  List<UserMemoryFact> _userMemoryFacts = [];
  DailySummary _dailySummary;
  CoachPersonality _personality = CoachPersonality.supportive;
  CoachTaskMode _taskMode = CoachTaskMode.plan;
  bool _isSessionRestored = false;
  bool get isSessionRestored => _isSessionRestored;

  void _addInitialMessage() {
    _messages.add(
      ChatMessage(
        id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
        role: ChatRole.assistant,
        content: _getWelcomeMessage(),
      ),
    );
  }

  /// Günün saatine göre zaman dilimini döndürür
  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'sabah';
    if (hour >= 12 && hour < 17) return 'öğleden sonra';
    if (hour >= 17 && hour < 22) return 'akşam';
    return 'gece';
  }

  /// Zaman dilimine göre selamlama döndürür
  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Günaydın';
    if (hour >= 12 && hour < 17) return 'Merhaba';
    if (hour >= 17 && hour < 22) return 'İyi akşamlar';
    return 'İyi geceler';
  }

  String _getWelcomeMessage() {
    final greeting = _getTimeGreeting();
    final s = _dailySummary;

    // Personalised opening when we have live data
    if (s.calories > 0 && s.targetCalories != null) {
      final diff = s.targetCalories! - s.calories;
      if (diff > 200) {
        return '$greeting! Bugün ${s.calories} kcal girdin, hedefe $diff kcal kaldı. Ne soruyorsun?';
      } else if (diff < -200) {
        return '$greeting! Bugün ${s.calories} kcal girdin — hedefin ${s.targetCalories} kcal, biraz aşıldı. Nasıl yardımcı olabilirim?';
      }
    }
    if (s.workouts > 0 && s.workoutMinutes > 0) {
      return '$greeting! Bugün ${s.workoutMinutes} dakika antrenman yapmışsın 💪 Nasıl hissediyorsun?';
    }
    if (s.waterLiters > 0 && s.waterLiters < 1.0) {
      return '$greeting! Su tüketimin henüz ${s.waterLiters.toStringAsFixed(1)} L — hedefe biraz daha var. Ne sormak istiyorsun?';
    }

    // Fallback: personality-based
    switch (_personality) {
      case CoachPersonality.motivator:
        return '$greeting! Bahaneleri kapı önünde bırak. Bugün neler başardın?';
      case CoachPersonality.scientist:
        return '$greeting. Fizyolojik verilerini analiz etmeye hazırım. Bugünkü performans metriklerini paylaş.';
      case CoachPersonality.supportive:
        return '$greeting! Hedeflerine bir adım daha yaklaşman için buradayım. Bugün nasıl gidiyor?';
    }
  }

  Timer? _cooldownTimer;
  int? _cooldownSecondsRemaining;

  Goal _goal = Goal.bulk;
  bool _isLoading = false;
  String? _errorMessage;
  CoachRequestSnapshot? _lastRequest;
  XFile? _selectedImage;
  bool _shouldShowConfetti = false;
  bool _isAnalyzingImage = false; // V5: Visual analysis effect

  bool get isAnalyzingImage => _isAnalyzingImage;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  Goal get goal => _goal;
  DailySummary get dailySummary => _dailySummary;
  CoachPersonality get personality => _personality;
  CoachTaskMode get taskMode => _taskMode;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  XFile? get selectedImage => _selectedImage;
  bool get shouldShowConfetti => _shouldShowConfetti;

  void resetConfetti() {
    if (_shouldShowConfetti) {
      _shouldShowConfetti = false;
      notifyListeners();
    }
  }

  void setSelectedImage(XFile? image) {
    _selectedImage = image;
    notifyListeners();
  }

  /// Returns chips contextually relevant to the last AI message when in conversation,
  /// or data-driven starter chips on the welcome screen.
  /// Chips are phrased as standalone questions so they make sense when sent alone.
  List<String> _buildContextualChips(String lastResponse) {
    final lower = lastResponse.toLowerCase();
    final chips = <String>[];

    // Entity extraction: Besin isimleri
    final foodEntities = _extractFoodEntities(lower);
    if (foodEntities.isNotEmpty) {
      final food = foodEntities.first;
      chips.add('$food için tarif ver');
      chips.add('$food yerine ne yiyebilirim?');
      chips.add('$food kaç kalori?');
    }

    // Entity extraction: Sayısal hedefler
    final numberMatch = RegExp(
      r'(\d+)\s*(gram|g|kcal|kalori|dakika|kg)',
    ).firstMatch(lower);
    if (numberMatch != null && chips.length < 4) {
      final amount = numberMatch.group(1);
      final unit = numberMatch.group(2);
      if (unit == 'gram' || unit == 'g') {
        chips.add('$amount$unit protein nasıl alırım?');
      } else if (unit == 'kcal' || unit == 'kalori') {
        chips.add('$amount$unit eklemek için ne yemeliyim?');
      }
    }

    // --- Nutrition-specific context ---
    if ((lower.contains('kalori') || lower.contains('kcal')) &&
        chips.length < 4) {
      final s = _dailySummary;
      if (s.targetCalories != null && s.calories > 0) {
        final diff = s.targetCalories! - s.calories;
        if (diff > 0) {
          chips.add('$diff kcal eklemek için ne yiyebilirim?');
        } else {
          chips.add('Kalori açığımı nasıl kapatırım?');
        }
      } else {
        chips.add('Bugünkü kalori hedefim nedir?');
      }
      if (chips.length < 4) {
        chips.add('Bu kalori miktarıyla kilo verebilir miyim?');
      }
    }

    if (lower.contains('protein')) {
      final s = _dailySummary;
      final p = s.proteinGrams;
      chips.add(
        p != null && p > 0
            ? 'Bugün ${p}g protein aldım, bu yeterli mi?'
            : 'Günlük kaç gram protein almalıyım?',
      );
      chips.add('En iyi protein kaynakları neler?');
    }

    if ((lower.contains('makro') ||
            lower.contains('karbonhidrat') ||
            lower.contains('yağ')) &&
        !lower.contains('protein')) {
      chips.add('Makrolarımı nasıl dengeleyebilirim?');
      chips.add('Karbonhidrat miktarını azaltmalı mıyım?');
    }

    // --- Workout context ---
    if (lower.contains('antrenman') || lower.contains('egzersiz')) {
      final s = _dailySummary;
      if (s.workouts > 0 && s.workoutMinutes >= 30) {
        chips.add(
          '${s.workoutMinutes} dakika sonrası için toparlanma planı ver',
        );
        chips.add('Bu antrenmandan sonra ne yemem gerekiyor?');
      } else {
        chips.add('Bugün kaç dakika egzersiz yapmalıyım?');
        chips.add('Evde yapabileceğim bir antrenman öner');
      }
    }

    // --- Recovery / sleep context ---
    if (lower.contains('toparlanma') ||
        lower.contains('uyku') ||
        lower.contains('dinlenme')) {
      chips.add('Toparlanmamı hızlandırmak için ne yapabilirim?');
      chips.add('Uyku kalitemi artırmanın yolları neler?');
    }

    // --- Weight context ---
    if (lower.contains('kilo') || lower.contains('ağırlık')) {
      final s = _dailySummary;
      final current = s.currentWeightKg;
      final target = s.targetWeightKg;
      if (current != null && target != null) {
        final diff = (target - current).abs();
        chips.add('${diff.toStringAsFixed(1)} kg hedefime ne zaman ulaşırım?');
      } else {
        chips.add('Kilo verme hızım normal mi?');
      }
      chips.add('Kilo verirken kas kaybını nasıl önlerim?');
    }

    // --- Water context ---
    if (lower.contains('su') || lower.contains('hidrasyon')) {
      final s = _dailySummary;
      chips.add(
        'Bugün ${s.waterLiters.toStringAsFixed(1)} L su içtim, yeterli mi?',
      );
      chips.add('Su içmeyi artırmak için pratik öneriler ver');
    }

    // --- Meal plan context ---
    if (lower.contains('öğün') ||
        lower.contains('kahvaltı') ||
        lower.contains('akşam yemeği') ||
        lower.contains('yemek listesi') ||
        lower.contains('menü')) {
      chips.add('Bu planı daha yüksek proteinli yapabilir misin?');
      chips.add('Vejeteryan alternatif öner');
    }

    // --- Motivation / emotional context ---
    if ((lower.contains('motivasyon') ||
            lower.contains('başar') ||
            lower.contains('zor') ||
            lower.contains('dur') ||
            lower.contains('sabır')) &&
        chips.length < 4) {
      chips.add('İlerleme göremiyorum, bu normal mi?');
      chips.add('Küçük ama kalıcı bir alışkanlık nasıl oluşturabilirim?');
    }

    // Sentiment analysis: AI olumlu mu, olumsuz mu?
    if (chips.length < 4) {
      if (lower.contains('yeterli değil') ||
          lower.contains('artırmalı') ||
          lower.contains('eksik')) {
        chips.add('Bunu nasıl düzeltebilirim?');
        chips.add('En hızlı çözüm ne?');
      } else if (lower.contains('harika') ||
          lower.contains('mükemmel') ||
          lower.contains('iyi gidiyor')) {
        chips.add('Bir sonraki hedefim ne olmalı?');
        chips.add('Bu başarıyı nasıl sürdürebilirim?');
      }
    }

    // Pad to 3-4 chips with context-neutral follow-ups if needed
    final fallbacks = [
      'Bunu daha basit açıklar mısın?',
      'Daha detaylı açıklar mısın?',
      'Bunu plana nasıl yansıtabilirim?',
      'Başka ne yapmalıyım?',
    ];
    for (final f in fallbacks) {
      if (chips.length >= 4) break;
      if (!chips.contains(f)) chips.add(f);
    }
    return chips.take(4).toList();
  }

  /// Extracts food entities from AI response
  List<String> _extractFoodEntities(String text) {
    final foods = <String>[];
    final foodPatterns = [
      r'\b(tavuk|chicken)\b',
      r'\b(yumurta|egg)\b',
      r'\b(pirinç|rice)\b',
      r'\b(makarna|pasta)\b',
      r'\b(peynir|cheese)\b',
      r'\b(süt|milk)\b',
      r'\b(muz|banana)\b',
      r'\b(elma|apple)\b',
      r'\b(patates|potato)\b',
      r'\b(ekmek|bread)\b',
      r'\b(mercimek|lentil)\b',
      r'\b(nohut|chickpea)\b',
      r'\b(balık|fish)\b',
      r'\b(ton|tuna)\b',
      r'\b(somon|salmon)\b',
      r'\b(hindi|turkey)\b',
      r'\b(biftek|steak)\b',
      r'\b(avokado|avocado)\b',
      r'\b(fıstık|peanut|nut)\b',
    ];

    for (final pattern in foodPatterns) {
      final match = RegExp(pattern, caseSensitive: false).firstMatch(text);
      if (match != null) {
        final food = match.group(1)!;
        // Türkçe normalize et
        if (food.toLowerCase().contains('chicken')) {
          foods.add('tavuk');
        } else if (food.toLowerCase().contains('egg')) {
          foods.add('yumurta');
        } else {
          foods.add(food.toLowerCase());
        }
      }
    }

    return foods.take(2).toList(); // Max 2 besin
  }

  // ─── Server-backed quota (overrides local SharedPrefs count) ───
  int? _serverRemainingFreePrompts;
  int? get serverRemainingFreePrompts => _serverRemainingFreePrompts;

  void updateFromServerQuota(int? remaining) {
    if (remaining == null) return;
    _serverRemainingFreePrompts = remaining;
    notifyListeners();
  }

  List<String> get actionChips {
    if (_messages.length > 1) {
      // Find the last non-error assistant message
      final lastAi = _messages.lastWhere(
        (m) => m.role == ChatRole.assistant && !m.isError,
        orElse: () => _messages.first,
      );
      if (lastAi.structuredResponse?.suggestedPrompts?.isNotEmpty ?? false) {
        return lastAi.structuredResponse!.suggestedPrompts!;
      }
      return _buildContextualChips(lastAi.content);
    }

    // Verilere göre akıllı öneriler
    final s = _dailySummary;
    final hasCalories = s.calories > 0;
    final hasWorkout = s.workouts > 0;
    final isUnderCalories =
        s.targetCalories != null &&
        hasCalories &&
        s.calories < s.targetCalories! - 200;
    final isOverCalories =
        s.targetCalories != null &&
        hasCalories &&
        s.calories > s.targetCalories! + 200;
    final isLowWater = s.waterLiters < 1.5;
    final timeOfDay = _getTimeOfDay();

    switch (_taskMode) {
      case CoachTaskMode.nutrition:
        return [
          if (!hasCalories) 'Bugün ne yemeliyim?',
          if (hasCalories && isUnderCalories)
            '${(s.targetCalories! - s.calories)} kcal daha alayım, ne önerirsin?',
          if (hasCalories && isOverCalories)
            'Kalori aştım, nasıl dengeleyeyim?',
          if (hasCalories && !isUnderCalories && !isOverCalories)
            'Kalorim hedefe uygun mu?',
          if (timeOfDay == 'akşam' || timeOfDay == 'gece') 'Akşam öğünü öner',
          if (timeOfDay == 'sabah') 'Sabah kahvaltısı öner',
          'Makrolarımı yorumla',
          if (!hasCalories) 'Kalori hedefimi belirle',
        ].take(4).toList();
      case CoachTaskMode.workout:
        return [
          if (!hasWorkout) 'Bugüne uygun antrenman ver',
          if (hasWorkout && s.workoutMinutes >= 45)
            'Toparlanma için ne yapmalıyım?',
          if (hasWorkout && s.workoutMinutes < 30)
            'Antrenmanı tamamlamak için öneri ver',
          if (!hasWorkout) '30 dakikalık ev antrenmanı yap',
          'Bugün dinlenmeli miyim?',
          'Isınma planı ver',
        ].take(4).toList();
      case CoachTaskMode.recovery:
        return [
          'Enerjim neden düşük?',
          if (isLowWater) 'Su hedefime nasıl ulaşırım?',
          if (!isLowWater) 'Su hedefimi yorumla',
          'Toparlanma planı yap',
          'Uyku kalitem için öner',
        ].take(4).toList();
      case CoachTaskMode.analysis:
        return [
          'Bugünkü verilerimi analiz et',
          'Son 7 günde nasıl gidiyorum?',
          'En zayıf halkam ne?',
          'Neyi iyi yapıyorum?',
        ];
      case CoachTaskMode.plan:
        return [
          if (timeOfDay == 'sabah') 'Bugün için tam plan yap',
          if (timeOfDay != 'sabah') 'Günün kalanı için plan yap',
          'Bana 3 öncelik ver',
          'Hedefime göre günü planla',
          'Bugünü daha iyi geçireyim',
        ].take(4).toList();
    }
  }

  int? get cooldownSecondsRemaining => _cooldownSecondsRemaining;
  bool get isCooldownActive =>
      _cooldownSecondsRemaining != null && _cooldownSecondsRemaining! > 0;
  bool get canRetryLastPrompt =>
      !_isLoading && !isCooldownActive && _lastRequest != null;

  bool get isSessionError {
    final msg = _errorMessage?.toLowerCase() ?? '';
    return msg.contains('oturum') || msg.contains('giriş');
  }

  void setGoal(Goal goal) {
    if (_goal == goal) return;
    _goal = goal;
    notifyListeners();
  }

  void setPersonality(CoachPersonality p) {
    if (_personality == p) return;
    final previous = _personality;
    _personality = p;
    // Inject a brief system note so the AI adapts tone without losing context.
    // Only add the note if there is an active conversation.
    if (_messages.length > 1) {
      final note = _personalityChangeNote(previous, p);
      _messages.add(
        ChatMessage(
          id: 'sys_${DateTime.now().millisecondsSinceEpoch}',
          role: ChatRole.assistant,
          content: note,
          isSystemNote: true,
        ),
      );
    }
    notifyListeners();
  }

  String _personalityChangeNote(CoachPersonality from, CoachPersonality to) {
    switch (to) {
      case CoachPersonality.motivator:
        return '⚡ Tamam, modumu değiştiriyorum. Bundan itibaren sert ve direkt konuşacağım — bahanelere yer yok!';
      case CoachPersonality.scientist:
        return '🔬 Geçiyorum bilimsel moda. Bundan sonra verilere ve araştırmalara dayalı net cevaplar vereceğim.';
      case CoachPersonality.supportive:
        return '🤗 Artık daha nazik ve destekleyici olacağım. Yanındayım, adım adım gideceğiz!';
    }
  }

  void setTaskMode(CoachTaskMode mode) {
    if (_taskMode == mode) return;
    _taskMode = mode;
    notifyListeners();
  }

  List<UserMemoryFact> get userMemoryFacts =>
      List.unmodifiable(_userMemoryFacts);
  AiUserMemoryService get memoryService => _memoryService;

  Future<void> saveMemoryFact(UserMemoryFact fact) async {
    final uid = _userId;
    if (uid == null) return;
    await _memoryService.saveFact(uid, fact);
    _userMemoryFacts = await _memoryService.getFacts(uid);
    notifyListeners();
  }

  Future<void> deleteMemoryFact(int index) async {
    final uid = _userId;
    if (uid == null) return;
    await _memoryService.deleteFact(uid, index);
    _userMemoryFacts = await _memoryService.getFacts(uid);
    notifyListeners();
  }

  /// Restore messages from previous session. Call once after init from the screen.
  Future<void> restoreSession() async {
    final uid = _userId;
    if (uid == null) {
      _isSessionRestored = true;
      notifyListeners();
      return;
    }
    try {
      // Load persistent memory alongside conversation
      _userMemoryFacts = await _memoryService.getFacts(uid);
      final stored = await _sessionService.loadSession(userId: uid);
      if (stored.isNotEmpty) {
        // Replace welcome message with stored history
        _messages.clear();
        for (final m in stored) {
          _messages.add(
            ChatMessage(
              id: 'restored_${DateTime.now().microsecondsSinceEpoch}',
              role: m['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
              content: m['content']!,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error restoring session: $e');
    } finally {
      _isSessionRestored = true;
      notifyListeners();
    }
  }

  Future<void> _persistSession() async {
    final uid = _userId;
    if (uid == null) return;
    final toSave = _messages
        .where((m) => !m.isError && !m.isSystemNote && m.content.isNotEmpty)
        .map(
          (m) => {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();
    await _sessionService.saveSession(userId: uid, messages: toSave);
    // Also archive to daily history key so it's always up-to-date
    if (toSave.isNotEmpty) {
      await _sessionService.archiveSession(
        userId: uid,
        date: _todayKey(),
        messages: toSave,
      );
    }
  }

  /// Saves current conversation to history before clearing.
  Future<void> _archiveIfNeeded() async {
    final uid = _userId;
    if (uid == null) return;
    final real = _messages
        .where((m) => !m.isError && !m.isSystemNote && m.content.isNotEmpty)
        .toList();
    if (real.length < 2) return;
    final toSave = real
        .map(
          (m) => {
            'role': m.role == ChatRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();
    await _sessionService.archiveSession(
      userId: uid,
      date: _todayKey(),
      messages: toSave,
    );
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void clearMessages() async {
    await _archiveIfNeeded();
    _messages.clear();
    _addInitialMessage();
    _errorMessage = null;
    if (_userId != null) {
      _sessionService.clearSession(userId: _userId);
    }
    notifyListeners();
  }

  /// Start a fresh conversation, archiving the current one first.
  Future<void> startNewConversation() async {
    await _archiveIfNeeded();
    _messages.clear();
    _addInitialMessage();
    _errorMessage = null;
    if (_userId != null) {
      await _sessionService.clearSession(userId: _userId);
    }
    notifyListeners();
  }

  /// Returns list of past sessions (newest first) for the history screen.
  Future<List<Map<String, dynamic>>> getSessionHistory() async {
    final uid = _userId;
    if (uid == null) return [];
    return _sessionService.listSessionsAsync(userId: uid);
  }

  /// Load a past session by date key (e.g. "2025-05-10").
  Future<void> loadHistorySession(String date) async {
    final uid = _userId;
    if (uid == null) return;
    final stored = await _sessionService.loadHistorySession(
      userId: uid,
      date: date,
    );
    if (stored.isEmpty) return;
    _messages.clear();
    for (final m in stored) {
      _messages.add(
        ChatMessage(
          id: 'hist_${DateTime.now().microsecondsSinceEpoch}',
          role: m['role'] == 'user' ? ChatRole.user : ChatRole.assistant,
          content: m['content']!,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> deleteHistorySession(String date) async {
    final uid = _userId;
    if (uid == null) return;
    await _sessionService.deleteHistorySession(userId: uid, date: date);
  }

  void setDailySummary(DailySummary summary) {
    _dailySummary = summary;
    notifyListeners();
  }

  Future<bool> submitPrompt(String prompt) async {
    final normalized = prompt.trim();
    if (normalized.isEmpty || _isLoading || isCooldownActive) {
      return false;
    }
    if (normalized.length > maxPromptLength) {
      _messages.add(
        ChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          role: ChatRole.assistant,
          content: 'Soru en fazla $maxPromptLength karakter olabilir.',
          isError: true,
        ),
      );
      notifyListeners();
      return false;
    }

    await _rememberFactsFromUserPrompt(normalized);
    final memoryContext = _memoryService.buildContextString(_userMemoryFacts);
    final effectiveTaskMode = _inferTaskModeFromPrompt(normalized, _taskMode);
    if (effectiveTaskMode != _taskMode) {
      _taskMode = effectiveTaskMode;
    }
    final snapshot = CoachRequestSnapshot(
      prompt: normalized,
      goal: _goal,
      summary: _dailySummary,
      personality: _personality,
      taskMode: effectiveTaskMode,
      conversationHistory: _buildConversationMemory(),
      imagePath: _selectedImage?.path,
      userMemory: memoryContext.isNotEmpty ? memoryContext : null,
    );
    return _submitSnapshot(snapshot, recordAsLast: true);
  }

  CoachTaskMode _inferTaskModeFromPrompt(
    String prompt,
    CoachTaskMode fallback,
  ) {
    final text = prompt.toLowerCase();
    bool hasAny(Iterable<String> values) {
      return values.any(text.contains);
    }

    if (hasAny(_safetyKeywords)) {
      return CoachTaskMode.recovery;
    }

    if (hasAny(_hydrationKeywords)) {
      return CoachTaskMode.recovery;
    }

    if (hasAny(_nutritionKeywords) ||
        hasAny(_foodLogKeywords) ||
        hasAny(_supplementKeywords)) {
      return CoachTaskMode.nutrition;
    }

    if (hasAny(_workoutKeywords)) {
      return CoachTaskMode.workout;
    }

    if (hasAny(_analysisKeywords)) {
      return CoachTaskMode.analysis;
    }

    if (hasAny(_recoveryKeywords)) {
      return CoachTaskMode.recovery;
    }

    return fallback;
  }

  List<CoachConversationTurn> _buildConversationMemory() {
    final relevant = _messages
        .where((m) => !m.isError)
        .where((m) => m.content.trim().isNotEmpty)
        .toList();

    final trimmed = relevant.length > 12
        ? relevant.sublist(relevant.length - 12)
        : relevant;

    return trimmed
        .map(
          (m) => CoachConversationTurn(
            role: m.role == ChatRole.user ? 'user' : 'assistant',
            content: m.content.trim(),
          ),
        )
        .toList();
  }

  Future<bool> _submitSnapshot(
    CoachRequestSnapshot snapshot, {
    required bool recordAsLast,
  }) async {
    final normalized = snapshot.prompt.trim();
    if (normalized.isEmpty || _isLoading || isCooldownActive) {
      return false;
    }
    if (recordAsLast) {
      _lastRequest = snapshot;
    }
    _isLoading = true;
    _errorMessage = null;
    final requestImagePath = snapshot.imagePath;
    final requestImage = requestImagePath != null
        ? XFile(requestImagePath)
        : null;

    _messages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: ChatRole.user,
        content: normalized,
        imagePath: requestImagePath,
      ),
    );

    final thinkingId = 'thinking_${DateTime.now().millisecondsSinceEpoch}';
    _messages.add(
      ChatMessage(
        id: thinkingId,
        role: ChatRole.assistant,
        content: '',
        isThinking: true,
      ),
    );
    notifyListeners();

    try {
      CoachResponse response;
      if (requestImage != null) {
        _isAnalyzingImage = true;
        notifyListeners();
        try {
          response = await _service.analyzeVision(
            image: requestImage,
            userPrompt: _buildModeAwarePrompt(normalized, snapshot.taskMode),
            goal: snapshot.goal,
            summary: snapshot.summary,
            personality: snapshot.personality,
            taskMode: snapshot.taskMode,
            conversationHistory: snapshot.conversationHistory,
            userMemory: snapshot.userMemory,
          );
          if (_selectedImage?.path == requestImagePath) {
            _selectedImage = null;
          }
        } finally {
          _isAnalyzingImage = false;
          notifyListeners();
        }
      } else {
        // Phase 8: Context enrichment
        final enrichedPrompt = _isImageResponseRequest(normalized)
            ? '$normalized\nLutfen bu yemegin porsiyonunu ve makro degerlerini (Protein/Karbonhidrat/Yag) tahmin et.'
            : _buildModeAwarePrompt(normalized, snapshot.taskMode);

        response = await _service.generatePlan(
          goal: snapshot.goal,
          summary: snapshot.summary,
          userPrompt: enrichedPrompt,
          personality: snapshot.personality,
          taskMode: snapshot.taskMode,
          conversationHistory: snapshot.conversationHistory,
          userMemory: snapshot.userMemory,
        );
      }

      String fullContent = _buildReadableCoachContent(response);

      // Step: Achievement Check
      if (response.isAchievement) {
        _shouldShowConfetti = true;
      }

      unawaited(_saveBackendMemory(response.memorySaved));

      _messages.removeWhere((m) => m.id == thinkingId);

      // Typewriter — 20-char chunks at 8ms base, sentence-end pauses.
      final aiMsgId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
      _messages.add(
        ChatMessage(
          id: aiMsgId,
          role: ChatRole.assistant,
          content: '',
          structuredResponse: response,
          taskMode: snapshot.taskMode.name,
          personality: snapshot.personality.name,
          userPrompt: normalized,
        ),
      );
      notifyListeners();

      int i = 0;
      const chunkSize = 20;
      while (i < fullContent.length) {
        final end = (i + chunkSize) > fullContent.length
            ? fullContent.length
            : (i + chunkSize);
        _messages[_messages.length - 1] = ChatMessage(
          id: aiMsgId,
          role: ChatRole.assistant,
          content: fullContent.substring(0, end),
          structuredResponse: response,
          taskMode: snapshot.taskMode.name,
          personality: snapshot.personality.name,
          userPrompt: normalized,
        );
        notifyListeners();
        i = end;

        if (i >= fullContent.length) break;

        // Pause only at sentence boundaries — single delay per chunk
        final lastChar = fullContent[i - 1];
        final int delay;
        if (lastChar == '.' || lastChar == '!' || lastChar == '?') {
          delay = 60; // Sentence end
        } else if (lastChar == '\n') {
          delay = 40; // New paragraph
        } else {
          delay = 8; // Normal
        }
        await Future.delayed(Duration(milliseconds: delay));
      }

      // Sync quota from server response
      if (response.remainingFreeRequests != null) {
        updateFromServerQuota(response.remainingFreeRequests);
      }

      // Persist conversation for cross-session continuity
      unawaited(_persistSession());

      // Summarize old messages if conversation is getting long
      unawaited(_summarizeIfNeeded());

      return true;
    } on ApiException catch (e) {
      _messages.removeWhere((m) => m.id == thinkingId);
      _errorMessage = e.message;
      String errorContent = e.message;
      final remaining = _extractRemainingFreeRequests(e.data);
      if (remaining != null) {
        updateFromServerQuota(remaining);
      }

      // Timeout hatası
      if (e.statusCode == 408 || e.statusCode == 504) {
        errorContent =
            '⏱️ AI yanıt süresi doldu.\n\n'
            'Öneriler:\n'
            '• Sorunuzu daha kısa yapın\n'
            '• Tekrar deneyin\n'
            '• İnternet bağlantınızı kontrol edin';
      }
      // Rate limit
      else if (e.statusCode == 429) {
        final retryAfterSeconds = _extractRetryAfterSeconds(e);
        if (retryAfterSeconds != null) {
          _startCooldown(retryAfterSeconds);
          errorContent =
              '⏳ Çok fazla istek. ${retryAfterSeconds}s sonra tekrar deneyebilirsin.';
        }
      }
      // Bağlantı hatası
      else if (e.statusCode == 0) {
        errorContent =
            '🔌 Bağlantı hatası.\n\n'
            'İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
      }

      _messages.add(
        ChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          role: ChatRole.assistant,
          content: errorContent,
          isError: true,
        ),
      );
      return false;
    } catch (e) {
      _messages.removeWhere((m) => m.id == thinkingId);

      // Timeout exception
      String errMsg = 'Koç yanıtı oluşturulamadı. Lütfen tekrar dene.';
      if (e.toString().toLowerCase().contains('timeout')) {
        errMsg = '⏱️ Zaman aşımı. Sorunuzu kısaltıp tekrar deneyin.';
      }

      _errorMessage = errMsg;
      _messages.add(
        ChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          role: ChatRole.assistant,
          content: errMsg,
          isError: true,
        ),
      );
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  int? _extractRemainingFreeRequests(dynamic data) {
    if (data is! Map) return null;
    final raw = data['remainingFreeRequests'];
    if (raw is int) return raw.clamp(0, 999).toInt();
    if (raw is num) return raw.toInt().clamp(0, 999).toInt();
    return null;
  }

  String _buildReadableCoachContent(CoachResponse response) {
    final contentBuffer = StringBuffer();
    final focus = _compactCoachText(response.focus, maxLength: 260);
    final actionItems = response.todoItems
        .map((item) => _compactCoachText(item, maxLength: 130))
        .where((item) => item.isNotEmpty)
        .take(6)
        .toList();
    final basisItems = actionItems
        .where(_isWorkoutBasisItem)
        .map(_stripWorkoutBasisPrefix)
        .where((item) => item.isNotEmpty)
        .toList();
    final planItems = actionItems
        .where((item) => !_isWorkoutBasisItem(item))
        .toList();
    final nutritionNote = _compactCoachText(
      response.nutritionNote,
      maxLength: 180,
    );

    if (focus.isNotEmpty) {
      contentBuffer.writeln('### Özet');
      contentBuffer.writeln(focus);
    }

    if (basisItems.isNotEmpty) {
      if (contentBuffer.isNotEmpty) contentBuffer.writeln();
      contentBuffer.writeln('### Neye göre');
      contentBuffer.writeln(basisItems.first);
    }

    if (planItems.isNotEmpty) {
      if (contentBuffer.isNotEmpty) contentBuffer.writeln();
      contentBuffer.writeln('### Plan');
      for (final item in planItems) {
        contentBuffer.writeln('- $item');
      }
    }

    if (nutritionNote.isNotEmpty) {
      if (contentBuffer.isNotEmpty) contentBuffer.writeln();
      contentBuffer.writeln('### Beslenme');
      contentBuffer.writeln(nutritionNote);
    }

    return contentBuffer.isNotEmpty
        ? contentBuffer.toString().trim()
        : 'Sana yardımcı olmaya hazırım!';
  }

  String _compactCoachText(String value, {required int maxLength}) {
    var text = value
        .replaceAll(r'\n', '\n')
        .replaceAll(RegExp(r'#{1,6}\s*'), '')
        .replaceAll(RegExp(r'^\s*[-•]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+[.)]\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*\n+\s*'), ' · ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s*·\s*·\s*'), ' · ')
        .trim();

    text = text.replaceAll(RegExp(r'^[:：·\s]+|[:：·\s]+$'), '');
    if (text.length <= maxLength) return text;

    final clipped = text.substring(0, maxLength).trimRight();
    final lastSentence = clipped.lastIndexOf(RegExp(r'[.!?]'));
    if (lastSentence > maxLength * 0.55) {
      return clipped.substring(0, lastSentence + 1).trim();
    }

    final lastSpace = clipped.lastIndexOf(' ');
    final safeEnd = lastSpace > maxLength * 0.65 ? lastSpace : clipped.length;
    return '${clipped.substring(0, safeEnd).trim()}...';
  }

  bool _isWorkoutBasisItem(String value) {
    final lower = value.toLowerCase();
    return lower.startsWith('neye göre') ||
        lower.startsWith('neye gore') ||
        lower.startsWith('neden:') ||
        lower.startsWith('gerekçe:') ||
        lower.startsWith('gerekce:');
  }

  String _stripWorkoutBasisPrefix(String value) {
    return value
        .replaceFirst(
          RegExp(r'^neye g[öo]re\s*[:：-]?\s*', caseSensitive: false),
          '',
        )
        .replaceFirst(
          RegExp(r'^(neden|gerek[çc]e)\s*[:：-]?\s*', caseSensitive: false),
          '',
        )
        .trim();
  }

  Future<void> retryLastPrompt() async {
    final lastRequest = _lastRequest;
    if (lastRequest == null || _isLoading || isCooldownActive) {
      return;
    }
    if (lastRequest.imagePath != null && _selectedImage == null) {
      _selectedImage = XFile(lastRequest.imagePath!);
      notifyListeners();
    }
    await _submitSnapshot(lastRequest, recordAsLast: false);
  }

  int? _extractRetryAfterSeconds(ApiException error) {
    final fromData = _extractRetryAfterFromData(error.data);
    if (fromData != null) return fromData;
    final match = RegExp(r'(\d+)').firstMatch(error.message);
    if (match == null) return null;
    final parsed = int.tryParse(match.group(1)!);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  int? _extractRetryAfterFromData(dynamic data) {
    if (data is! Map) return null;
    final direct =
        _parsePositiveInt(data['retryAfterSeconds']) ??
        _parsePositiveInt(data['retry_after_seconds']);
    if (direct != null) return direct;
    final nested = data['data'];
    if (nested is Map) {
      return _parsePositiveInt(nested['retryAfterSeconds']) ??
          _parsePositiveInt(nested['retry_after_seconds']);
    }
    return null;
  }

  int? _parsePositiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.floor();
    if (value is String) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed > 0) return parsed;
      }
    }
    return null;
  }

  void _startCooldown(int seconds) {
    if (seconds <= 0) return;
    _cancelCooldownTimer();
    _cooldownSecondsRemaining = seconds;
    notifyListeners();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = _cooldownSecondsRemaining;
      if (current == null) {
        timer.cancel();
        return;
      }
      if (current <= 1) {
        timer.cancel();
        _cooldownTimer = null;
        _cooldownSecondsRemaining = null;
        notifyListeners();
        return;
      }
      _cooldownSecondsRemaining = current - 1;
      notifyListeners();
    });
  }

  void _cancelCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
  }

  bool _isImageResponseRequest(String prompt) {
    final p = prompt.toLowerCase();
    return p.contains('yemek') ||
        p.contains('kalori') ||
        p.contains('tabak') ||
        p.contains('öğün');
  }

  Future<void> _rememberFactsFromUserPrompt(String prompt) async {
    final uid = _userId;
    if (uid == null) return;

    final fact = _extractMemoryFact(prompt);
    if (fact == null || fact.fact.isEmpty) return;

    await _memoryService.saveFact(uid, fact);
    _userMemoryFacts = await _memoryService.getFacts(uid);
  }

  UserMemoryFact? _extractMemoryFact(String prompt) {
    final text = prompt.trim();
    if (text.length < 4) return null;

    final lower = text.toLowerCase();
    final now = DateTime.now();

    bool hasAny(List<String> terms) => terms.any(lower.contains);

    if (hasAny([
      'dizim ağr',
      'dizim agr',
      'belim ağr',
      'belim agr',
      'omzum ağr',
      'omzum agr',
      'sakat',
      'incin',
      'fıtık',
      'fitik',
      'ameliyat',
    ])) {
      return UserMemoryFact(
        category: 'saglik',
        fact: 'Kullanıcı sağlık/form uyarısı paylaştı: $text',
        savedAt: now,
      );
    }

    if (hasAny([
      'vejetaryen',
      'vegan',
      'laktoz',
      'gluten',
      'alerji',
      'sevmiyorum',
      'yemiyorum',
      'tercih',
    ])) {
      return UserMemoryFact(
        category: 'beslenme',
        fact: 'Kullanıcının beslenme tercihi/kısıtı: $text',
        savedAt: now,
      );
    }

    if (hasAny([
      'evde çalış',
      'evde calis',
      'salonda çalış',
      'salonda calis',
      'dambıl',
      'dumbbell',
      'ekipman',
      'barbell',
    ])) {
      return UserMemoryFact(
        category: 'antrenman',
        fact: 'Kullanıcının antrenman ortamı/ekipmanı: $text',
        savedAt: now,
      );
    }

    if (hasAny([
      'hedefim',
      'kilo vermek',
      'kas yapmak',
      'güçlenmek',
      'guclenmek',
      'yağ yak',
      'yag yak',
    ])) {
      return UserMemoryFact(
        category: 'hedef',
        fact: 'Kullanıcının hedef bilgisi: $text',
        savedAt: now,
      );
    }

    return null;
  }

  Future<void> _saveBackendMemory(String? memory) async {
    final uid = _userId;
    final fact = memory?.trim();
    if (uid == null || fact == null || fact.isEmpty) return;

    await _memoryService.saveFact(
      uid,
      UserMemoryFact(category: 'ai', fact: fact, savedAt: DateTime.now()),
    );
    _userMemoryFacts = await _memoryService.getFacts(uid);
    notifyListeners();
  }

  /// Yaygın Türkçe yazım hatalarını düzelt ve keyword'leri normalize et
  String _normalizeTurkish(String text) {
    return text
        .replaceAll(RegExp(r'\bantreman\b', caseSensitive: false), 'antrenman')
        .replaceAll(
          RegExp(r'\bantremanı\b', caseSensitive: false),
          'antrenmanı',
        )
        .replaceAll(
          RegExp(r'\bantremanım\b', caseSensitive: false),
          'antrenmanım',
        )
        .replaceAll(
          RegExp(r'\bkarbohidrat\b', caseSensitive: false),
          'karbonhidrat',
        )
        .replaceAll(RegExp(r'\bprotein\b', caseSensitive: false), 'protein')
        .replaceAll(RegExp(r'\bkalori\b', caseSensitive: false), 'kalori')
        .replaceAll(
          RegExp(r'\bkilo\s+ver\b', caseSensitive: false),
          'kilo vermek',
        )
        .replaceAll(
          RegExp(r'\byağ\s+yak\b', caseSensitive: false),
          'yağ yakmak',
        )
        .replaceAll(
          RegExp(r'\bspor\s+salon\b', caseSensitive: false),
          'spor salonu',
        )
        .replaceAll(RegExp(r'\bIF\b'), 'aralıklı oruç (intermittent fasting)')
        .replaceAll(RegExp(r'\bcreatine\b', caseSensitive: false), 'kreatin')
        .replaceAll(RegExp(r'\bwhey\b', caseSensitive: false), 'whey protein');
  }

  String _buildModeAwarePrompt(String prompt, CoachTaskMode mode) {
    final trimmed = _normalizeTurkish(prompt.trim());

    // Mid-conversation: never inject mode prefix — it disrupts natural flow.
    final isOngoing = _messages.where((m) => !m.isError).length > 2;
    if (isOngoing) return trimmed;

    if (trimmed.isEmpty) return mode.promptLead;

    // First message: skip mode prefix if the user's question already has a clear topic.
    final lower = trimmed.toLowerCase();
    final hasTopic = [
      ..._safetyKeywords,
      ..._nutritionKeywords,
      ..._foodLogKeywords,
      ..._hydrationKeywords,
      ..._supplementKeywords,
      ..._workoutKeywords,
      ..._analysisKeywords,
      ..._recoveryKeywords,
      'kilo',
      'ağırlık',
      'agirlik',
      'su',
      'plan',
      'ne yap',
      'nasıl',
      'nasil',
    ].any(lower.contains);
    if (hasTopic) return trimmed;

    // Vague first message (e.g., just "merhaba") — add mode context to help the AI.
    return '[Mod: ${mode.label}] ${mode.promptLead}\n$trimmed';
  }

  static const int _summarizeThreshold = 14;
  static const int _keepRecentCount = 6;
  bool _isSummarizing = false;

  /// When the conversation exceeds [_summarizeThreshold] real messages, sends the
  /// older half to the backend summarizer and replaces them with a compact summary
  /// message. The most recent [_keepRecentCount] messages are kept verbatim so
  /// context stays fresh.
  Future<void> _summarizeIfNeeded() async {
    if (_isSummarizing) return;
    final real = _messages
        .where((m) => !m.isError && !m.isSystemNote && m.content.isNotEmpty)
        .toList();
    if (real.length < _summarizeThreshold) return;

    final toSummarize = real.sublist(0, real.length - _keepRecentCount);
    if (toSummarize.isEmpty) return;

    _isSummarizing = true;
    try {
      final token = StorageHelper.getToken();
      if (token == null || token.isEmpty) return;

      final lines = toSummarize
          .map(
            (m) =>
                '${m.role == ChatRole.user ? 'Kullanıcı' : 'Koç'}: ${m.content.trim()}',
          )
          .toList();

      final response = await ApiClient().post(
        ApiConstants.aiSummarize,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {'messages': lines},
      );

      if (response.statusCode != 200) return;
      final summary =
          (response.data as Map<String, dynamic>?)?['summary'] as String?;
      if (summary == null || summary.trim().isEmpty) return;

      // Remove the summarized messages and insert a single summary bubble.
      final summarizedIds = toSummarize.map((m) => m.id).toSet();
      _messages.removeWhere((m) => summarizedIds.contains(m.id));

      final summaryMsg = ChatMessage(
        id: 'summary_${DateTime.now().millisecondsSinceEpoch}',
        role: ChatRole.assistant,
        content: '📝 Önceki konuşma özeti:\n\n$summary',
        isSystemNote: true,
      );
      // Insert summary before the kept recent messages (at position 0 after
      // the welcome message if present, otherwise at the front).
      final insertAt = _messages.indexWhere(
        (m) => !m.isSystemNote && m.role == ChatRole.user,
      );
      if (insertAt < 0) {
        _messages.add(summaryMsg);
      } else {
        _messages.insert(insertAt, summaryMsg);
      }

      notifyListeners();
      unawaited(_persistSession());
    } catch (_) {
      // Non-critical — ignore failures silently
    } finally {
      _isSummarizing = false;
    }
  }

  /// Fire-and-forget feedback — called from ChatBubble when user taps 👍/👎.
  void sendFeedback(
    ChatMessage message, {
    required bool isPositive,
    String? reason,
    String? coachingPreference,
  }) {
    unawaited(() async {
      await _service.sendFeedback(
        aiResponse: message.content,
        isPositive: isPositive,
        taskMode: message.taskMode,
        personality: message.personality,
        userQuestion: message.userPrompt,
        reason: reason,
        coachingPreference: coachingPreference,
      );
      final uid = _userId;
      final fact = coachingPreference;
      if (uid != null && fact != null && fact.trim().isNotEmpty) {
        await _memoryService.saveFact(
          uid,
          UserMemoryFact(
            category: 'feedback',
            fact: 'AI koç tercihi: ${fact.trim()}',
            savedAt: DateTime.now(),
          ),
        );
        _userMemoryFacts = await _memoryService.getFacts(uid);
        notifyListeners();
      }
    }());
  }

  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelCooldownTimer();
    super.dispose();
  }
}
