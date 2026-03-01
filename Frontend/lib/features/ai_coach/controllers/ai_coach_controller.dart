import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_exception.dart';
import '../models/ai_coach_models.dart';
import '../services/ai_coach_service.dart';

class AiCoachController extends ChangeNotifier {
  static const int maxPromptLength = 500;
  static const List<String> _quickPrompts = <String>[
    'Bugun icin 30 dakikalik ev antrenmani planla.',
    'Yag yakimi hedefime gore bugun ne yemeliyim?',
    'Guc odakli alt vucut antrenmani oner.',
    'Uyku duzenim kotu, toparlanma plani ver.',
  ];

  AiCoachController({AiCoachService? service, DailySummary? initialSummary})
    : _service = service ?? AiCoachService(),
      _dailySummary =
          initialSummary ??
          const DailySummary(
            steps: 6200,
            calories: 2100,
            waterLiters: 2.0,
            sleepHours: 6.8,
            workouts: 1,
          ),
      _advice = const CoachAdviceView(
        focus: 'Hedef secip sorunu yaz, sana bugune ozel bir plan olusturalim.',
      );

  final AiCoachService _service;
  DailySummary _dailySummary;
  CoachAdviceView _advice;
  Timer? _cooldownTimer;
  int? _cooldownSecondsRemaining;

  CoachGoal _goal = CoachGoal.bulk;
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastPrompt;

  CoachGoal get goal => _goal;
  DailySummary get dailySummary => _dailySummary;
  CoachAdviceView get advice => CoachAdviceView(
    focus: _advice.focus,
    actions: List<String>.unmodifiable(_advice.actions),
    nutritionNote: _advice.nutritionNote,
  );
  List<CoachSuggestion> get suggestions {
    final grouped = _advice;
    final result = <CoachSuggestion>[];
    if (grouped.focus.trim().isNotEmpty) {
      result.add(
        CoachSuggestion(title: 'Bugunun odagi', description: grouped.focus),
      );
    }
    result.addAll(
      grouped.actions.map(
        (item) => CoachSuggestion(title: 'Aksiyon', description: item),
      ),
    );
    if (grouped.nutritionNote.trim().isNotEmpty) {
      result.add(
        CoachSuggestion(
          title: 'Beslenme notu',
          description: grouped.nutritionNote,
        ),
      );
    }
    return List<CoachSuggestion>.unmodifiable(result);
  }
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<String> get quickPrompts => List<String>.unmodifiable(_quickPrompts);
  int? get cooldownSecondsRemaining => _cooldownSecondsRemaining;
  bool get isCooldownActive =>
      _cooldownSecondsRemaining != null && _cooldownSecondsRemaining! > 0;
  bool get canRetryLastPrompt =>
      !_isLoading &&
      !isCooldownActive &&
      _lastPrompt != null &&
      _lastPrompt!.isNotEmpty;

  bool get isSessionError {
    final msg = _errorMessage?.toLowerCase() ?? '';
    return msg.contains('oturum') || msg.contains('giris');
  }

  void setGoal(CoachGoal goal) {
    if (_goal == goal) {
      return;
    }
    _goal = goal;
    notifyListeners();
  }

  void setDailySummary(DailySummary summary) {
    _dailySummary = summary;
    notifyListeners();
  }

  Future<void> submitPrompt(String prompt) async {
    final normalized = prompt.trim();
    if (normalized.isEmpty || _isLoading || isCooldownActive) {
      return;
    }
    if (normalized.length > maxPromptLength) {
      _errorMessage = 'Soru en fazla $maxPromptLength karakter olabilir.';
      notifyListeners();
      return;
    }

    _lastPrompt = normalized;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _service.generatePlan(
        goal: _goal,
        summary: _dailySummary,
        userPrompt: normalized,
      );
      _advice = CoachAdviceView(
        focus: response.focus.trim(),
        actions: response.todoItems
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList(),
        nutritionNote: response.nutritionNote.trim(),
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
      if (e.statusCode == 429) {
        final retryAfterSeconds = _extractRetryAfterSeconds(e);
        if (retryAfterSeconds != null) {
          _startCooldown(retryAfterSeconds);
        }
      }
    } catch (_) {
      _errorMessage = 'Koc yaniti olusturulamadi. Lutfen tekrar dene.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> retryLastPrompt() async {
    final lastPrompt = _lastPrompt;
    if (lastPrompt == null || lastPrompt.isEmpty || _isLoading || isCooldownActive) {
      return;
    }
    await submitPrompt(lastPrompt);
  }

  int? _extractRetryAfterSeconds(ApiException error) {
    final fromData = _extractRetryAfterFromData(error.data);
    if (fromData != null) {
      return fromData;
    }

    final match = RegExp(r'(\d+)').firstMatch(error.message);
    if (match == null) {
      return null;
    }
    final parsed = int.tryParse(match.group(1)!);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  int? _extractRetryAfterFromData(dynamic data) {
    if (data is! Map) {
      return null;
    }

    final direct =
        _parsePositiveInt(data['retryAfterSeconds']) ??
        _parsePositiveInt(data['retry_after_seconds']);
    if (direct != null) {
      return direct;
    }

    final nested = data['data'];
    if (nested is Map) {
      return _parsePositiveInt(nested['retryAfterSeconds']) ??
          _parsePositiveInt(nested['retry_after_seconds']);
    }
    return null;
  }

  int? _parsePositiveInt(dynamic value) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is num && value > 0) {
      return value.floor();
    }
    if (value is String) {
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        final parsed = int.tryParse(match.group(1)!);
        if (parsed != null && parsed > 0) {
          return parsed;
        }
      }
    }
    return null;
  }

  void _startCooldown(int seconds) {
    if (seconds <= 0) {
      return;
    }
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

  @override
  void dispose() {
    _cancelCooldownTimer();
    super.dispose();
  }
}
