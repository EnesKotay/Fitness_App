import 'package:flutter/foundation.dart';

enum TaskPriority { high, medium, low }

enum TaskCategory { sport, nutrition, water, other }

const _priorityToString = {
  TaskPriority.high: 'high',
  TaskPriority.medium: 'medium',
  TaskPriority.low: 'low',
};

const _priorityFromString = {
  'high': TaskPriority.high,
  'medium': TaskPriority.medium,
  'low': TaskPriority.low,
};

const _categoryToString = {
  TaskCategory.sport: 'sport',
  TaskCategory.nutrition: 'nutrition',
  TaskCategory.water: 'water',
  TaskCategory.other: 'other',
};

const _categoryFromString = {
  'sport': TaskCategory.sport,
  'nutrition': TaskCategory.nutrition,
  'water': TaskCategory.water,
  'other': TaskCategory.other,
};

@immutable
class DailyTask {
  const DailyTask({
    required this.id,
    required this.date,
    required this.title,
    required this.source,
    required this.isDone,
    required this.createdAt,
    this.priority = TaskPriority.medium,
    this.category = TaskCategory.other,
    this.isRecurring = false,
  });

  final String id;
  final String date;
  final String title;
  final String source;
  final bool isDone;
  final DateTime createdAt;
  final TaskPriority priority;
  final TaskCategory category;
  final bool isRecurring;

  DailyTask copyWith({
    String? id,
    String? date,
    String? title,
    String? source,
    bool? isDone,
    DateTime? createdAt,
    TaskPriority? priority,
    TaskCategory? category,
    bool? isRecurring,
  }) {
    return DailyTask(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      source: source ?? this.source,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'date': date,
      'title': title,
      'source': source,
      'isDone': isDone,
      'createdAt': createdAt.toIso8601String(),
      'priority': _priorityToString[priority],
      'category': _categoryToString[category],
      'isRecurring': isRecurring,
    };
  }

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      id: (json['id'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      source: (json['source'] ?? 'ai_coach').toString(),
      isDone: json['isDone'] == true,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      priority: _priorityFromString[json['priority'] ?? ''] ?? TaskPriority.medium,
      category: _categoryFromString[json['category'] ?? ''] ?? TaskCategory.other,
      isRecurring: json['isRecurring'] == true,
    );
  }

  static String normalizeTitle(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}
