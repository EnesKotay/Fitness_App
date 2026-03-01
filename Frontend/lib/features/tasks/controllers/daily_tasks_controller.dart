import 'package:flutter/foundation.dart';

import '../models/daily_task.dart';
import '../storage/daily_task_storage.dart';

enum DailyTasksFilter { all, todo, done }

class DailyTasksController extends ChangeNotifier {
  DailyTasksController({
    DailyTaskStorage? storage,
    DateTime Function()? nowProvider,
  }) : _storage = storage ?? DailyTaskStorage(),
       _nowProvider = nowProvider ?? DateTime.now,
       _selectedDate = _normalizeDate((nowProvider ?? DateTime.now)());

  final DailyTaskStorage _storage;
  final DateTime Function() _nowProvider;

  DateTime _selectedDate;
  List<DailyTask> _tasks = <DailyTask>[];
  DailyTasksFilter _filter = DailyTasksFilter.all;
  bool _isLoading = false;

  DateTime get selectedDate => _selectedDate;
  DailyTasksFilter get filter => _filter;
  bool get isLoading => _isLoading;
  List<DailyTask> get tasks => List<DailyTask>.unmodifiable(_tasks);

  List<DailyTask> get filteredTasks {
    switch (_filter) {
      case DailyTasksFilter.all:
        return tasks;
      case DailyTasksFilter.todo:
        return tasks.where((task) => !task.isDone).toList();
      case DailyTasksFilter.done:
        return tasks.where((task) => task.isDone).toList();
    }
  }

  int get totalCount => _tasks.length;
  int get completedCount => _tasks.where((task) => task.isDone).length;

  Map<String, DailyTask> get tasksByNormalizedTitle {
    final map = <String, DailyTask>{};
    for (final task in _tasks) {
      map[DailyTask.normalizeTitle(task.title)] = task;
    }
    return map;
  }

  Future<void> loadToday() {
    return loadForDate(_nowProvider());
  }

  Future<void> loadForDate(DateTime date) async {
    final normalizedDate = _normalizeDate(date);
    _selectedDate = normalizedDate;
    _isLoading = true;
    notifyListeners();
    try {
      _tasks = await _storage.loadForDate(normalizedDate);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DailyTask? taskForTitle(String title) {
    final normalized = DailyTask.normalizeTitle(title);
    if (normalized.isEmpty) {
      return null;
    }
    for (final task in _tasks) {
      if (DailyTask.normalizeTitle(task.title) == normalized) {
        return task;
      }
    }
    return null;
  }

  Future<DailyTask?> addFromAiAction(String title) async {
    final existing = taskForTitle(title);
    if (existing != null) {
      return existing;
    }
    final added = await _storage.addTaskIfNotExists(_selectedDate, title);
    if (added == null) {
      _tasks = await _storage.loadForDate(_selectedDate);
      notifyListeners();
      return taskForTitle(title);
    }
    _tasks = <DailyTask>[..._tasks, added];
    notifyListeners();
    return added;
  }

  Future<void> toggleTaskDone(String taskId) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) {
      return;
    }
    final current = _tasks[index];
    final nextValue = !current.isDone;
    await _storage.toggleDone(_selectedDate, taskId, nextValue);
    _tasks = _tasks
        .map(
          (task) => task.id == taskId ? task.copyWith(isDone: nextValue) : task,
        )
        .toList();
    notifyListeners();
  }

  void setFilter(DailyTasksFilter filter) {
    if (_filter == filter) {
      return;
    }
    _filter = filter;
    notifyListeners();
  }

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
