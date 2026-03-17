import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/storage_helper.dart';
import '../models/daily_task.dart';

class RecurringTemplate {
  const RecurringTemplate({
    required this.id,
    required this.title,
    this.category = TaskCategory.other,
    this.priority = TaskPriority.medium,
  });

  final String id;
  final String title;
  final TaskCategory category;
  final TaskPriority priority;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': _categoryToString[category],
        'priority': _priorityToString[priority],
      };

  factory RecurringTemplate.fromJson(Map<String, dynamic> json) =>
      RecurringTemplate(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        category: _categoryFromString[json['category'] ?? ''] ?? TaskCategory.other,
        priority: _priorityFromString[json['priority'] ?? ''] ?? TaskPriority.medium,
      );
}

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

class DailyTaskStorage {
  DailyTaskStorage({SharedPreferences? prefs, DateTime Function()? nowProvider})
    : _prefs = prefs,
      _nowProvider = nowProvider ?? DateTime.now;

  static const String _keyPrefix = 'daily_tasks_';
  static const String _recurringPrefix = 'recurring_tasks_';

  SharedPreferences? _prefs;
  final DateTime Function() _nowProvider;

  Future<SharedPreferences> _getPrefs() async {
    final existing = _prefs;
    if (existing != null) return existing;
    final created = await SharedPreferences.getInstance();
    _prefs = created;
    return created;
  }

  String storageKeyForDate(DateTime date) {
    final suffix = StorageHelper.getUserStorageSuffix();
    return '$_keyPrefix${suffix}_${dateKey(date)}';
  }

  String get _recurringKey {
    final suffix = StorageHelper.getUserStorageSuffix();
    return '$_recurringPrefix$suffix';
  }

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
    List<DailyTask> tasks = [];

    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          tasks = decoded
              .whereType<Map>()
              .map((item) => DailyTask.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      } catch (_) {}
    }

    // Auto-inject recurring tasks that are missing for this day
    final templates = await loadRecurringTemplates();
    bool changed = false;
    for (final tmpl in templates) {
      final normalized = DailyTask.normalizeTitle(tmpl.title);
      final exists = tasks.any(
        (t) => DailyTask.normalizeTitle(t.title) == normalized,
      );
      if (!exists) {
        final now = _nowProvider();
        tasks = [
          ...tasks,
          DailyTask(
            id: 'task_recurring_${tmpl.id}_${dateKey(date)}',
            date: dateKey(date),
            title: tmpl.title,
            source: 'recurring',
            isDone: false,
            createdAt: now,
            priority: tmpl.priority,
            category: tmpl.category,
            isRecurring: true,
          ),
        ];
        changed = true;
      }
    }
    if (changed) {
      await saveForDate(date, tasks);
    }

    return tasks;
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
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.other,
    bool isRecurring = false,
  }) async {
    final cleanedTitle = title.trim();
    if (cleanedTitle.isEmpty) return null;

    final normalizedTitle = DailyTask.normalizeTitle(cleanedTitle);
    final tasks = await loadForDate(date);
    final alreadyExists = tasks.any(
      (task) => DailyTask.normalizeTitle(task.title) == normalizedTitle,
    );
    if (alreadyExists) return null;

    final now = _nowProvider();
    final task = DailyTask(
      id: 'task_${now.microsecondsSinceEpoch}_${normalizedTitle.hashCode.abs()}',
      date: dateKey(date),
      title: cleanedTitle,
      source: source,
      isDone: false,
      createdAt: now,
      priority: priority,
      category: category,
      isRecurring: isRecurring,
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

  Future<void> deleteTask(DateTime date, String taskId) async {
    final tasks = await loadForDate(date);
    final updated = tasks.where((task) => task.id != taskId).toList();
    await saveForDate(date, updated);
  }

  // ─── Recurring Templates ──────────────────────────────────────────────────

  Future<List<RecurringTemplate>> loadRecurringTemplates() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_recurringKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => RecurringTemplate.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveRecurringTemplates(List<RecurringTemplate> templates) async {
    final prefs = await _getPrefs();
    final payload = jsonEncode(templates.map((t) => t.toJson()).toList());
    await prefs.setString(_recurringKey, payload);
  }

  Future<RecurringTemplate?> addRecurringTemplate({
    required String title,
    TaskCategory category = TaskCategory.other,
    TaskPriority priority = TaskPriority.medium,
  }) async {
    final cleanedTitle = title.trim();
    if (cleanedTitle.isEmpty) return null;

    final templates = await loadRecurringTemplates();
    final normalized = DailyTask.normalizeTitle(cleanedTitle);
    final exists = templates.any(
      (t) => DailyTask.normalizeTitle(t.title) == normalized,
    );
    if (exists) return null;

    final now = DateTime.now();
    final tmpl = RecurringTemplate(
      id: 'rec_${now.microsecondsSinceEpoch}',
      title: cleanedTitle,
      category: category,
      priority: priority,
    );
    await saveRecurringTemplates([...templates, tmpl]);
    return tmpl;
  }

  Future<void> removeRecurringTemplate(String id) async {
    final templates = await loadRecurringTemplates();
    await saveRecurringTemplates(
      templates.where((t) => t.id != id).toList(),
    );
  }
}
