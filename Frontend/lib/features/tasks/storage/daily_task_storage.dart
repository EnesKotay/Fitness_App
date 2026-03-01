import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_task.dart';

class DailyTaskStorage {
  DailyTaskStorage({SharedPreferences? prefs, DateTime Function()? nowProvider})
    : _prefs = prefs,
      _nowProvider = nowProvider ?? DateTime.now;

  static const String _keyPrefix = 'daily_tasks_';

  SharedPreferences? _prefs;
  final DateTime Function() _nowProvider;

  Future<SharedPreferences> _getPrefs() async {
    final existing = _prefs;
    if (existing != null) {
      return existing;
    }
    final created = await SharedPreferences.getInstance();
    _prefs = created;
    return created;
  }

  String storageKeyForDate(DateTime date) => '$_keyPrefix${dateKey(date)}';

  String dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  Future<List<DailyTask>> loadForDate(DateTime date) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(storageKeyForDate(date));
    if (raw == null || raw.trim().isEmpty) {
      return <DailyTask>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <DailyTask>[];
      }
      return decoded
          .whereType<Map>()
          .map((item) => DailyTask.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return <DailyTask>[];
    }
  }

  Future<void> saveForDate(DateTime date, List<DailyTask> tasks) async {
    final prefs = await _getPrefs();
    final payload = jsonEncode(tasks.map((task) => task.toJson()).toList());
    await prefs.setString(storageKeyForDate(date), payload);
  }

  Future<DailyTask?> addTaskIfNotExists(
    DateTime date,
    String title, {
    String source = 'ai_coach',
  }) async {
    final cleanedTitle = title.trim();
    if (cleanedTitle.isEmpty) {
      return null;
    }

    final normalizedTitle = DailyTask.normalizeTitle(cleanedTitle);
    final tasks = await loadForDate(date);
    final alreadyExists = tasks.any(
      (task) => DailyTask.normalizeTitle(task.title) == normalizedTitle,
    );
    if (alreadyExists) {
      return null;
    }

    final now = _nowProvider();
    final task = DailyTask(
      id: 'task_${now.microsecondsSinceEpoch}_${normalizedTitle.hashCode.abs()}',
      date: dateKey(date),
      title: cleanedTitle,
      source: source,
      isDone: false,
      createdAt: now,
    );
    final updated = <DailyTask>[...tasks, task];
    await saveForDate(date, updated);
    return task;
  }

  Future<void> toggleDone(DateTime date, String taskId, bool isDone) async {
    final tasks = await loadForDate(date);
    final updated = tasks
        .map((task) => task.id == taskId ? task.copyWith(isDone: isDone) : task)
        .toList();
    await saveForDate(date, updated);
  }
}
