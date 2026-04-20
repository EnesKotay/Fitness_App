import 'dart:async';
import 'package:image_picker/image_picker.dart';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../../nutrition/domain/entities/user_profile.dart';
import '../models/ai_coach_models.dart';
import '../services/ai_coach_service.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final String? imagePath;
  final DateTime createdAt;
  final CoachResponse? structuredResponse;
  final bool isError;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? createdAt,
    this.structuredResponse,
    this.imagePath,
    this.isError = false,
  }) : createdAt = createdAt ?? DateTime.now();
}

class AiCoachController extends ChangeNotifier {
  static const int maxPromptLength = 500;

  AiCoachController({AiCoachService? service, DailySummary? initialSummary})
    : _service = service ?? AiCoachService(),
      _dailySummary =
          initialSummary ??
          const DailySummary(
            steps: 0,
            calories: 0,
            waterLiters: 0,
            sleepHours: 0,
            workouts: 0,
            workoutMinutes: 0,
            workoutHighlights: <String>[],
          ) {
    _addInitialMessage();
  }

  final AiCoachService _service;
  final List<ChatMessage> _messages = [];
  DailySummary _dailySummary;
  CoachPersonality _personality = CoachPersonality.supportive;
  CoachTaskMode _taskMode = CoachTaskMode.plan;

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
  List<String> _buildContextualChips(String lastResponse) {
    final lower = lastResponse.toLowerCase();
    final chips = <String>[];

    if (lower.contains('kalori') || lower.contains('kcal')) {
      chips.add('Nasıl tamamlayabilirim?');
      chips.add('Kalorim yeterli mi?');
    }
    if (lower.contains('antrenman') || lower.contains('egzersiz') || lower.contains('training')) {
      chips.add('Farklı bir antrenman öner');
      chips.add('Dinlenmeli miyim?');
    }
    if (lower.contains('protein') || lower.contains('makro') || lower.contains('karbonhidrat')) {
      chips.add('Makrolarımı nasıl dengelerim?');
      chips.add('En iyi protein kaynakları neler?');
    }
    if (lower.contains('kilo') || lower.contains('ağırlık') || lower.contains('weight')) {
      chips.add('Ne kadar sürede değişir?');
      chips.add('Neden kilo alamıyorum?');
    }
    if (lower.contains('su') || lower.contains('water')) {
      chips.add('Su hedefime nasıl ulaşırım?');
    }
    if (lower.contains('toparlanma') || lower.contains('uyku') || lower.contains('recovery')) {
      chips.add('Toparlanma için ne yapabilirim?');
    }

    // Always pad to 4 chips with universals
    const universals = [
      'Devam et, daha fazla anlat',
      'Peki ya bunun yerine?',
      'Bunu daha basit açıkla',
      'Başka ne önerirsin?',
    ];
    for (final u in universals) {
      if (chips.length >= 4) break;
      if (!chips.contains(u)) chips.add(u);
    }
    return chips.take(4).toList();
  }

  List<String> get actionChips {
    if (_messages.length > 1) {
      // Find the last non-error assistant message
      final lastAi = _messages.lastWhere(
        (m) => m.role == ChatRole.assistant && !m.isError,
        orElse: () => _messages.first,
      );
      return _buildContextualChips(lastAi.content);
    }

    // Verilere göre akıllı öneriler
    final s = _dailySummary;
    final hasCalories = s.calories > 0;
    final hasWorkout = s.workouts > 0;
    final isUnderCalories = s.targetCalories != null && hasCalories && s.calories < s.targetCalories! - 200;
    final isOverCalories = s.targetCalories != null && hasCalories && s.calories > s.targetCalories! + 200;
    final isLowWater = s.waterLiters < 1.5;
    final timeOfDay = _getTimeOfDay();

    switch (_taskMode) {
      case CoachTaskMode.nutrition:
        return [
          if (!hasCalories) 'Bugün ne yemeliyim?',
          if (hasCalories && isUnderCalories) '${(s.targetCalories! - s.calories)} kcal daha alayım, ne önerirsin?',
          if (hasCalories && isOverCalories) 'Kalori aştım, nasıl dengeleyeyim?',
          if (hasCalories && !isUnderCalories && !isOverCalories) 'Kalorim hedefe uygun mu?',
          if (timeOfDay == 'akşam' || timeOfDay == 'gece') 'Akşam öğünü öner',
          if (timeOfDay == 'sabah') 'Sabah kahvaltısı öner',
          'Makrolarımı yorumla',
          if (!hasCalories) 'Kalori hedefimi belirle',
        ].take(4).toList();
      case CoachTaskMode.workout:
        return [
          if (!hasWorkout) 'Bugüne uygun antrenman ver',
          if (hasWorkout && s.workoutMinutes >= 45) 'Toparlanma için ne yapmalıyım?',
          if (hasWorkout && s.workoutMinutes < 30) 'Antrenmanı tamamlamak için öneri ver',
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
    _personality = p;
    _messages.clear();
    _addInitialMessage();
    notifyListeners();
  }

  void setTaskMode(CoachTaskMode mode) {
    if (_taskMode == mode) return;
    _taskMode = mode;
    notifyListeners();
  }

  void clearMessages() {
    _messages.clear();
    _addInitialMessage();
    _errorMessage = null;
    notifyListeners();
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

    final snapshot = CoachRequestSnapshot(
      prompt: normalized,
      goal: _goal,
      summary: _dailySummary,
      personality: _personality,
      taskMode: _taskMode,
      conversationHistory: _buildConversationMemory(),
      imagePath: _selectedImage?.path,
    );
    return _submitSnapshot(snapshot, recordAsLast: true);
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
        );
      }

      String fullContent = response.focus.isNotEmpty
          ? response.focus
          : 'Sana yardımcı olmaya hazırım!';


      // Step: Achievement Check
      if (response.isAchievement) {
        _shouldShowConfetti = true;
      }

      // Step: Typing Simulation for "Canlı Yazım" effect
      final aiMsgId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
      final initialAiMsg = ChatMessage(
        id: aiMsgId,
        role: ChatRole.assistant,
        content: '',
        structuredResponse: response,
      );
      _messages.add(initialAiMsg);
      notifyListeners();

      // Variable-speed typing — pauses on punctuation like a real human
      int i = 0;
      while (i < fullContent.length) {
        final end = (i + 4) > fullContent.length ? fullContent.length : (i + 4);
        _messages[_messages.length - 1] = ChatMessage(
          id: aiMsgId,
          role: ChatRole.assistant,
          content: fullContent.substring(0, end),
          structuredResponse: response,
        );
        notifyListeners();
        i = end;

        if (i >= fullContent.length) break;

        final nextChar = fullContent[i - 1];
        final int delay;
        if (nextChar == '.' || nextChar == '!' || nextChar == '?') {
          delay = 90; // Sentence end — natural pause
        } else if (nextChar == ',' || nextChar == ':' || nextChar == '—') {
          delay = 45; // Clause break — slight hesitation
        } else if (nextChar == '\n') {
          delay = 60; // New line — brief breath
        } else {
          delay = 16; // Normal character — fast
        }
        await Future.delayed(Duration(milliseconds: delay));
      }

      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      String errorContent = e.message;
      if (e.statusCode == 429) {
        final retryAfterSeconds = _extractRetryAfterSeconds(e);
        if (retryAfterSeconds != null) {
          _startCooldown(retryAfterSeconds);
          errorContent =
              'Çok fazla istek. ${retryAfterSeconds}s sonra tekrar deneyebilirsin.';
        }
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
    } catch (_) {
      const errMsg = 'Koç yanıtı oluşturulamadı. Lütfen tekrar dene.';
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

  String _buildModeAwarePrompt(String prompt, CoachTaskMode mode) {
    final trimmed = prompt.trim();
    final timeCtx = '[Gün: ${_getTimeOfDay()}]';
    if (trimmed.isEmpty) return '$timeCtx ${mode.promptLead}';

    // When conversation is ongoing, drop the mode prefix so the chat flows naturally.
    // The mode context was already established in earlier turns.
    final isOngoing = _messages.where((m) => !m.isError).length > 2;
    if (isOngoing) return '$timeCtx $trimmed';

    return '$timeCtx [Mod: ${mode.label}] ${mode.promptLead}\n$trimmed';
  }

  @override
  void dispose() {
    _cancelCooldownTimer();
    super.dispose();
  }
}
