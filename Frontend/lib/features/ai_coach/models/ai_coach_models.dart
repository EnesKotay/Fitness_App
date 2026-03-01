import 'package:flutter/foundation.dart';

enum CoachGoal { bulk, cut, strength }

extension CoachGoalX on CoachGoal {
  String get label {
    switch (this) {
      case CoachGoal.bulk:
        return 'Hacim';
      case CoachGoal.cut:
        return 'Yag Yakimi';
      case CoachGoal.strength:
        return 'Guc';
    }
  }

  String get subtitle {
    switch (this) {
      case CoachGoal.bulk:
        return 'Kontrollu kalori fazlasi ile kas kutleni artir.';
      case CoachGoal.cut:
        return 'Performansi koruyarak yag oranini dusur.';
      case CoachGoal.strength:
        return 'Temel hareketlerde kuvvetini yukari tasi.';
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

  const DailySummary({
    required this.steps,
    required this.calories,
    required this.waterLiters,
    required this.sleepHours,
    required this.workouts,
  });
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

  const CoachResponse({
    required this.focus,
    required this.todoItems,
    required this.nutritionNote,
  });
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
