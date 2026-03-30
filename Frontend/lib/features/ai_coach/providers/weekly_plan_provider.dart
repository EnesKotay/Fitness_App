import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'package:dio/dio.dart';

/// Haftalık AI antrenman planını yönetir.
class WeeklyPlanProvider with ChangeNotifier {
  static const _kPlanKey = 'weekly_ai_plan';
  static const _kPlanDateKey = 'weekly_ai_plan_date';

  bool _isLoading = false;
  String? _error;
  WeeklyPlan? _plan;
  DateTime? _planDate;

  bool get isLoading => _isLoading;
  String? get error => _error;
  WeeklyPlan? get plan => _plan;
  DateTime? get planDate => _planDate;

  bool get hasPlan => _plan != null;
  bool get isExpired {
    if (_planDate == null) return true;
    return DateTime.now().difference(_planDate!).inDays >= 7;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kPlanKey);
    final dateStr = prefs.getString(_kPlanDateKey);
    if (json != null) {
      try {
        _plan = WeeklyPlan.fromJson(jsonDecode(json));
      } catch (e) {
        debugPrint('WeeklyPlanProvider: cached plan parse error — $e');
      }
    }
    if (dateStr != null) _planDate = DateTime.tryParse(dateStr);
    notifyListeners();
  }

  Future<void> generatePlan({
    required String goal,
    required String fitnessLevel,
    required int workoutsPerWeek,
    required String focusAreas,
    required String? injuries,
    required double? bodyWeight,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final client = ApiClient();
      final prompt = _buildPrompt(
        goal: goal,
        fitnessLevel: fitnessLevel,
        workoutsPerWeek: workoutsPerWeek,
        focusAreas: focusAreas,
        injuries: injuries,
        bodyWeight: bodyWeight,
      );

      final response = await client.post(
        ApiConstants.aiCoach,
        data: {
          'goal': goal,
          'question': prompt,
          'dailySummary': {
            'steps': 0,
            'calories': 0,
            'waterLiters': 0,
            'sleepHours': 0,
            'workouts': 0,
            'workoutMinutes': 0,
            'workoutHighlights': [],
          },
          'task': 'weekly_plan',
          'context': {
            'fitnessLevel': fitnessLevel,
            'workoutsPerWeek': workoutsPerWeek,
            'focusAreas': focusAreas,
            'injuries': injuries ?? '',
          },
        },
        options: Options(
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      final data = response.data;
      // AI'dan gelen yanıtı parse et veya text'i günlere ayır
      final replyText = data is Map ? (data['reply'] ?? data['todayFocus'] ?? '') : data.toString();

      _plan = _parsePlanFromText(replyText.toString(), workoutsPerWeek, focusAreas, goal);
      _planDate = DateTime.now();

      await _persist();
    } catch (e) {
      _error = 'Plan oluşturulamadı. Lütfen internet bağlantınızı kontrol edin.';
      debugPrint('WeeklyPlanProvider.generatePlan: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  WeeklyPlan _parsePlanFromText(
      String text, int workoutsPerWeek, String focusAreas, String goal) {
    // 1. Önce JSON parse dene (backend structured response dönebilir)
    final jsonPlan = _tryParseJsonPlan(text);
    if (jsonPlan != null) return jsonPlan;

    // 2. AI metnini gün isimlerine göre böl ve egzersiz satırlarını çıkar
    final dayNames = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final focusList = focusAreas.split(',').map((s) => s.trim()).toList();
    final workoutDayIndices = List.generate(workoutsPerWeek, (i) => i * (7 ~/ workoutsPerWeek));

    // AI yanıtını gün bölümlerine ayır
    final dayExercisesFromAI = _extractDayExercisesFromText(text, dayNames);

    final dayPlans = <DayPlan>[];
    for (int i = 0; i < 7; i++) {
      final isRest = !workoutDayIndices.contains(i);
      final focusIndex = workoutDayIndices.indexOf(i);
      final focusLabel = isRest
          ? 'Dinlenme & Toparlanma'
          : (focusIndex >= 0 && focusIndex < focusList.length
              ? focusList[focusIndex]
              : focusList[focusIndex % focusList.length]);

      // AI'dan parse edilen egzersizler varsa kullan, yoksa fallback
      final aiExercises = dayExercisesFromAI[dayNames[i]];
      final exercises = isRest
          ? ['Hafif yürüyüş veya esneme önerilir']
          : (aiExercises != null && aiExercises.isNotEmpty
              ? aiExercises
              : _defaultExercises(focusLabel));

      dayPlans.add(DayPlan(
        dayName: dayNames[i],
        isRestDay: isRest,
        focus: focusLabel,
        exercises: exercises,
        notes: isRest
            ? 'Kasların toparlanması için önemli.'
            : 'Isınmayı atlama. Form > Ağırlık.',
      ));
    }

    // Özet: AI yanıtının ilk anlamlı paragrafını kullan
    final summary = _extractSummary(text) ??
        '$workoutsPerWeek günlük kişiselleştirilmiş antrenman planı — $goal ($focusAreas odaklı).';

    return WeeklyPlan(summary: summary, days: dayPlans);
  }

  /// Backend'in JSON döndürdüğü durumu handle eder.
  WeeklyPlan? _tryParseJsonPlan(String text) {
    try {
      final trimmed = text.trim();
      final start = trimmed.indexOf('{');
      final end = trimmed.lastIndexOf('}');
      if (start == -1 || end == -1 || end <= start) return null;
      final jsonStr = trimmed.substring(start, end + 1);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (decoded.containsKey('days') && decoded['days'] is List) {
        return WeeklyPlan.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  /// AI metin yanıtından gün adlarına göre egzersiz satırlarını çıkarır.
  Map<String, List<String>> _extractDayExercisesFromText(
      String text, List<String> dayNames) {
    final result = <String, List<String>>{};
    if (text.trim().isEmpty) return result;

    // Egzersiz satırı pattern: "- X", "• X", "* X" veya set×rep içerenler
    final exerciseLinePattern = RegExp(
      r'(?:[-•*]\s+|^\d+[.)]\s*)(.+)',
      multiLine: true,
    );
    final setRepPattern = RegExp(r'\d+\s*[×xX]\s*\d+|\d+\s*set|\d+\s*tekrar', caseSensitive: false);

    for (int i = 0; i < dayNames.length; i++) {
      final dayName = dayNames[i];
      final nextDay = i + 1 < dayNames.length ? dayNames[i + 1] : null;

      final startIdx = text.indexOf(dayName);
      if (startIdx == -1) continue;
      final endIdx = nextDay != null ? text.indexOf(nextDay, startIdx + dayName.length) : text.length;
      final section = text.substring(startIdx, endIdx == -1 ? text.length : endIdx);

      final exercises = exerciseLinePattern
          .allMatches(section)
          .map((m) => m.group(1)!.trim())
          .where((line) =>
              line.length > 3 &&
              (setRepPattern.hasMatch(line) || line.length < 80))
          .take(6)
          .toList();

      if (exercises.isNotEmpty) result[dayName] = exercises;
    }
    return result;
  }

  /// AI yanıtından özet cümle/paragraf çıkarır.
  String? _extractSummary(String text) {
    if (text.trim().isEmpty) return null;
    // İlk anlamlı paragrafı al (gün adı içermeyenler)
    final dayNames = {'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'};
    final paragraphs = text.split(RegExp(r'\n{2,}'));
    for (final para in paragraphs) {
      final clean = para.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (clean.length > 20 && !dayNames.any((d) => clean.startsWith(d))) {
        return clean.length > 300 ? '${clean.substring(0, 300)}...' : clean;
      }
    }
    // Gün adı içermeyen ilk satır
    final firstLine = text.split('\n').firstWhere(
      (l) => l.trim().length > 20 && !dayNames.any((d) => l.contains(d)),
      orElse: () => '',
    );
    if (firstLine.isNotEmpty) {
      return firstLine.trim().length > 300
          ? '${firstLine.trim().substring(0, 300)}...'
          : firstLine.trim();
    }
    return null;
  }

  List<String> _defaultExercises(String focus) {
    final f = focus.toLowerCase();
    if (f.contains('göğüs') || f.contains('chest')) {
      return ['Bench Press 4×8', 'İncline DB Press 3×10', 'Cable Fly 3×12', 'Push-up 3×15'];
    }
    if (f.contains('sırt') || f.contains('back')) {
      return ['Pull-up 4×8', 'Barbell Row 4×8', 'Lat Pulldown 3×10', 'Cable Row 3×12'];
    }
    if (f.contains('bacak') || f.contains('leg')) {
      return ['Squat 4×8', 'Romanian DL 3×10', 'Leg Press 3×12', 'Calf Raise 4×15'];
    }
    if (f.contains('omuz') || f.contains('shoulder')) {
      return ['OHP 4×8', 'Lateral Raise 3×15', 'Front Raise 3×12', 'Face Pull 3×15'];
    }
    if (f.contains('kol') || f.contains('bicep') || f.contains('tricep')) {
      return ['Barbell Curl 4×10', 'Hammer Curl 3×12', 'Tricep Pushdown 4×10', 'Skull Crusher 3×10'];
    }
    return ['Compound lift 4×8', 'Accessory 3×10', 'Isolation 3×12', 'Core 3×15'];
  }

  String _buildPrompt({
    required String goal,
    required String fitnessLevel,
    required int workoutsPerWeek,
    required String focusAreas,
    String? injuries,
    double? bodyWeight,
  }) {
    return '''
Benim için 7 günlük haftalık antrenman planı oluştur:
- Hedef: $goal
- Seviye: $fitnessLevel
- Haftalık antrenman: $workoutsPerWeek gün
- Odak bölgeler: $focusAreas
${injuries != null && injuries.isNotEmpty ? '- Sakatlık/kısıt: $injuries' : ''}
${bodyWeight != null ? '- Vücut ağırlığı: ${bodyWeight.toStringAsFixed(0)} kg' : ''}

Lütfen şu formatta yaz. Her gün için gün adıyla başla (Pazartesi, Salı, vb.), ardından 4-5 egzersizi "- Egzersiz Adı Nx×Nrep" formatında listele:

Pazartesi: [kas grubu]
- Egzersiz 1 4×8
- Egzersiz 2 3×10
...

Salı: [Dinlenme/kas grubu]
- ...

(7 gün boyunca devam et. Dinlenme günlerinde sadece "Dinlenme - hafif yürüyüş önerilir" yaz.)
''';
  }

  Future<void> _persist() async {
    if (_plan == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlanKey, jsonEncode(_plan!.toJson()));
    await prefs.setString(_kPlanDateKey, (_planDate ?? DateTime.now()).toIso8601String());
  }

  void clearError() { _error = null; notifyListeners(); }
  void clearPlan() { _plan = null; _planDate = null; notifyListeners(); }
}

class WeeklyPlan {
  final String summary;
  final List<DayPlan> days;
  WeeklyPlan({required this.summary, required this.days});

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) => WeeklyPlan(
        summary: json['summary'] ?? '',
        days: (json['days'] as List? ?? [])
            .map((d) => DayPlan.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'summary': summary,
        'days': days.map((d) => d.toJson()).toList(),
      };
}

class DayPlan {
  final String dayName;
  final bool isRestDay;
  final String focus;
  final List<String> exercises;
  final String notes;

  DayPlan({
    required this.dayName,
    required this.isRestDay,
    required this.focus,
    required this.exercises,
    required this.notes,
  });

  factory DayPlan.fromJson(Map<String, dynamic> json) => DayPlan(
        dayName: json['dayName'] ?? '',
        isRestDay: json['isRestDay'] ?? false,
        focus: json['focus'] ?? '',
        exercises: List<String>.from(json['exercises'] ?? []),
        notes: json['notes'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'dayName': dayName,
        'isRestDay': isRestDay,
        'focus': focus,
        'exercises': exercises,
        'notes': notes,
      };
}
