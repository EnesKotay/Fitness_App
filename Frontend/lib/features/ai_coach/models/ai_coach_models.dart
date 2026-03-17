import 'package:flutter/foundation.dart';

import '../../nutrition/domain/entities/user_profile.dart';

extension GoalX on Goal {
  String get label {
    switch (this) {
      case Goal.bulk:
        return 'Hacim';
      case Goal.cut:
        return 'Yağ Yakımı';
      case Goal.strength:
        return 'Güç';
      case Goal.maintain:
        return 'Form Koruma';
    }
  }

  String get subtitle {
    switch (this) {
      case Goal.bulk:
        return 'Kontrollü kalori fazlası ile kas kütleni artır.';
      case Goal.cut:
        return 'Performansı koruyarak yağ oranını düşür.';
      case Goal.strength:
        return 'Temel hareketlerde kuvvetini yukarı taşı.';
      case Goal.maintain:
        return 'Mevcut formunu ve kilonu koru.';
    }
  }
}

enum CoachPersonality { motivator, scientist, supportive }

enum CoachTaskMode { plan, nutrition, workout, recovery, analysis }

extension CoachPersonalityX on CoachPersonality {
  String get label {
    switch (this) {
      case CoachPersonality.motivator:
        return 'Motivatör (Sert)';
      case CoachPersonality.scientist:
        return 'Bilimsel Mentor';
      case CoachPersonality.supportive:
        return 'Destekleyici Arkadaş';
    }
  }

  String get instruction {
    switch (this) {
      case CoachPersonality.motivator:
        return 'Sen sert, disiplinli bir fitness antrenörüsün. Kullanıcıyı zorla, bahaneleri kabul etme, kısa ve net konuş.';
      case CoachPersonality.scientist:
        return 'Sen bilimsel verilere önem veren bir mentorsun. Tavsiyelerini araştırmalara dayandır, teknik detaylar ver.';
      case CoachPersonality.supportive:
        return 'Sen nazik ve destekleyici bir arkadaşsın. Kullanıcıyı motive et, küçük başarılarını kutla, yumuşak bir dil kullan.';
    }
  }
}

extension CoachTaskModeX on CoachTaskMode {
  String get label {
    switch (this) {
      case CoachTaskMode.plan:
        return 'Plan';
      case CoachTaskMode.nutrition:
        return 'Beslenme';
      case CoachTaskMode.workout:
        return 'Antrenman';
      case CoachTaskMode.recovery:
        return 'Toparlanma';
      case CoachTaskMode.analysis:
        return 'Analiz';
    }
  }

  String get hint {
    switch (this) {
      case CoachTaskMode.plan:
        return 'Bugün için net bir plan oluştur.';
      case CoachTaskMode.nutrition:
        return 'Kalori, makro ve öğün tavsiyeleri al.';
      case CoachTaskMode.workout:
        return 'Seans, hareket ve yoğunluk önerisi iste.';
      case CoachTaskMode.recovery:
        return 'Uyku, su ve dinlenme odaklı destek al.';
      case CoachTaskMode.analysis:
        return 'Verilerini yorumlat, neyin iyi gittiğini öğren.';
    }
  }

  String get promptLead {
    switch (this) {
      case CoachTaskMode.plan:
        return 'Bugün için uygulanabilir bir plan hazırla.';
      case CoachTaskMode.nutrition:
        return 'Beslenme odaklı yorum yap.';
      case CoachTaskMode.workout:
        return 'Antrenman odaklı yorum yap.';
      case CoachTaskMode.recovery:
        return 'Toparlanma ve enerji yönetimi odaklı yorum yap.';
      case CoachTaskMode.analysis:
        return 'Mevcut verileri analiz edip öne çıkan noktayı söyle.';
    }
  }
}

@immutable
class DailySummary {
  final int steps;
  final int calories;
  final double waterLiters;
  final double sleepHours;
  final int workouts;
  final int workoutMinutes;
  final List<String> workoutHighlights;

  // Phase 8: Historical Context (Averages for personalization)
  final int? avgStepsLast7Days;
  final int? avgCaloriesLast7Days;
  final double? avgWaterLast7Days;
  final int? targetCalories;
  final double? currentWeightKg;
  final double? targetWeightKg;
  final double? bmi;

  // Phase 9: Richer context for smarter AI
  final int? proteinGrams;
  final int? carbsGrams;
  final int? fatGrams;
  final List<String> mealNames;
  final double? weeklyWeightChangeKg;
  final int? weightStreak;
  final int? userAge;
  final double? userHeightCm;
  final String? userGender;
  final String? activityLevel;
  final int? tdee;

  const DailySummary({
    required this.steps,
    required this.calories,
    required this.waterLiters,
    required this.sleepHours,
    required this.workouts,
    this.workoutMinutes = 0,
    this.workoutHighlights = const <String>[],
    this.avgStepsLast7Days,
    this.avgCaloriesLast7Days,
    this.avgWaterLast7Days,
    this.targetCalories,
    this.currentWeightKg,
    this.targetWeightKg,
    this.bmi,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
    this.mealNames = const <String>[],
    this.weeklyWeightChangeKg,
    this.weightStreak,
    this.userAge,
    this.userHeightCm,
    this.userGender,
    this.activityLevel,
    this.tdee,
  });

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'calories': calories,
    'waterLiters': waterLiters,
    'sleepHours': sleepHours,
    'workouts': workouts,
    'workoutMinutes': workoutMinutes,
    'workoutHighlights': workoutHighlights,
    'avgStepsLast7Days': avgStepsLast7Days,
    'avgCaloriesLast7Days': avgCaloriesLast7Days,
    'avgWaterLast7Days': avgWaterLast7Days,
    'targetCalories': targetCalories,
    'currentWeightKg': currentWeightKg,
    'targetWeightKg': targetWeightKg,
    'bmi': bmi,
    'proteinGrams': proteinGrams,
    'carbsGrams': carbsGrams,
    'fatGrams': fatGrams,
    'mealNames': mealNames,
    'weeklyWeightChangeKg': weeklyWeightChangeKg,
    'weightStreak': weightStreak,
    'userAge': userAge,
    'userHeightCm': userHeightCm,
    'userGender': userGender,
    'activityLevel': activityLevel,
    'tdee': tdee,
  };
}

@immutable
class CoachConversationTurn {
  final String role;
  final String content;

  const CoachConversationTurn({required this.role, required this.content});

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
  };
}

@immutable
class CoachSuggestion {
  final String title;
  final String description;

  const CoachSuggestion({required this.title, required this.description});
}

@immutable
class CoachResponse {
  final String focus;
  final List<String> todoItems;
  final String nutritionNote;

  // V5: Rich Data
  final List<CoachAction>? actions;
  final List<CoachMedia>? media;
  final bool isAchievement;

  const CoachResponse({
    required this.focus,
    required this.todoItems,
    required this.nutritionNote,
    this.actions,
    this.media,
    this.isAchievement = false,
  });

  factory CoachResponse.fromJson(Map<String, dynamic> json) {
    List<String> parseTodoItems(dynamic v) {
      if (v == null) return [];
      if (v is List) {
        return v
            .map((e) => e?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }

    List<CoachAction>? parseActions(dynamic v) {
      if (v == null || v is! List) return null;
      final result = <CoachAction>[];
      for (final e in v) {
        try {
          final m = e is Map ? Map<String, dynamic>.from(e) : null;
          if (m != null) result.add(CoachAction.fromJson(m));
        } catch (e) {
          debugPrint('CoachAction parse hatası: $e');
        }
      }
      return result.isEmpty ? null : result;
    }

    List<CoachMedia>? parseMedia(dynamic v) {
      if (v == null || v is! List) return null;
      final result = <CoachMedia>[];
      for (final e in v) {
        try {
          final m = e is Map ? Map<String, dynamic>.from(e) : null;
          if (m != null) result.add(CoachMedia.fromJson(m));
        } catch (e) {
          debugPrint('CoachMedia parse hatası: $e');
        }
      }
      return result.isEmpty ? null : result;
    }

    return CoachResponse(
      focus: json['todayFocus']?.toString() ?? '',
      todoItems: parseTodoItems(json['actionItems']),
      nutritionNote: json['nutritionNote']?.toString() ?? '',
      isAchievement: json['isAchievement'] == true,
      actions: parseActions(json['actions']),
      media: parseMedia(json['media']),
    );
  }
}

@immutable
class CoachAction {
  final String label;
  final String type;
  final String? data;

  const CoachAction({required this.label, required this.type, this.data});

  factory CoachAction.fromJson(Map<String, dynamic> json) {
    return CoachAction(
      label: json['label'] ?? '',
      type: json['type'] ?? '',
      data: json['data']?.toString(),
    );
  }
}

@immutable
class CoachMedia {
  final String type;
  final String url;
  final String? title;

  const CoachMedia({required this.type, required this.url, this.title});

  factory CoachMedia.fromJson(Map<String, dynamic> json) {
    return CoachMedia(
      type: json['type'] ?? '',
      url: json['url'] ?? '',
      title: json['title'],
    );
  }
}

@immutable
class CoachAdviceView {
  final String focus;
  final List<String> actions;
  final String nutritionNote;

  const CoachAdviceView({
    this.focus = '',
    this.actions = const <String>[],
    this.nutritionNote = '',
  });
}

@immutable
class CoachRequestSnapshot {
  final String prompt;
  final Goal goal;
  final DailySummary summary;
  final CoachPersonality personality;
  final CoachTaskMode taskMode;
  final List<CoachConversationTurn> conversationHistory;
  final String? imagePath;

  const CoachRequestSnapshot({
    required this.prompt,
    required this.goal,
    required this.summary,
    required this.personality,
    required this.taskMode,
    this.conversationHistory = const <CoachConversationTurn>[],
    this.imagePath,
  });
}
