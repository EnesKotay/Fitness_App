import 'package:flutter/foundation.dart';

@immutable
class DailyTask {
  const DailyTask({
    required this.id,
    required this.date,
    required this.title,
    required this.source,
    required this.isDone,
    required this.createdAt,
  });

  final String id;
  final String date;
  final String title;
  final String source;
  final bool isDone;
  final DateTime createdAt;

  DailyTask copyWith({
    String? id,
    String? date,
    String? title,
    String? source,
    bool? isDone,
    DateTime? createdAt,
  }) {
    return DailyTask(
      id: id ?? this.id,
      date: date ?? this.date,
      title: title ?? this.title,
      source: source ?? this.source,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt ?? this.createdAt,
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
    );
  }

  static String normalizeTitle(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}
