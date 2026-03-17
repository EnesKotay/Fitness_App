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
    switch (_personality) {
      case CoachPersonality.motivator:
        return '$greeting! Bahaneleri kapı önünde bırak. Bugün neler başardın? Hemen rapor ver.';
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

  List<String> get actionChips {
    if (_messages.length > 1) {
      return [
        'Daha fazla detay ver',
        'Bunu bugüne göre netleştir',
        'Bunu daha basit açıkla',
        'Başka ne yapabilirim?',
      ];
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

      final StringBuffer aiContent = StringBuffer();
      if (response.focus.isNotEmpty) {
        aiContent.writeln('🎯 **Bugünün Odağı:**\n${response.focus}\n');
      }
      if (response.todoItems.isNotEmpty) {
        aiContent.writeln('📋 **Yapılacaklar:**');
        for (var item in response.todoItems) {
          aiContent.writeln('• $item');
        }
        aiContent.writeln('');
      }
      if (response.nutritionNote.isNotEmpty) {
        aiContent.writeln('🍎 **Beslenme Notu:**\n${response.nutritionNote}');
      }

      String fullContent = aiContent.toString().trim();
      if (fullContent.isEmpty) {
        fullContent =
            'Bugünkü verilerine göre önerilerim hazır. Yukarıdaki yapılacaklar listesini uygulayabilirsin.';
      }

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

      // Faster typing simulation
      const int charsPerStep = 5;
      for (int i = 0; i <= fullContent.length; i += charsPerStep) {
        await Future.delayed(const Duration(milliseconds: 20));
        final end = (i + charsPerStep) > fullContent.length
            ? fullContent.length
            : (i + charsPerStep);
        _messages[_messages.length - 1] = ChatMessage(
          id: aiMsgId,
          role: ChatRole.assistant,
          content: fullContent.substring(0, end),
          structuredResponse: response,
        );
        notifyListeners();
        if (end == fullContent.length) break;
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
    return '$timeCtx [Mod: ${mode.label}] ${mode.promptLead}\n$trimmed';
  }

  @override
  void dispose() {
    _cancelCooldownTimer();
    super.dispose();
  }
}
