import 'package:flutter/foundation.dart';

import '../models/daily_task.dart';
import '../storage/daily_task_storage.dart';

enum DailyTasksFilter { all, todo, done }

class DailyTaskMilestone {
  const DailyTaskMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
  });

  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
}

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
  List<RecurringTemplate> _recurringTemplates = <RecurringTemplate>[];
  DailyTasksFilter _filter = DailyTasksFilter.all;
  bool _isLoading = false;

  DateTime get selectedDate => _selectedDate;
  DailyTasksFilter get filter => _filter;
  bool get isLoading => _isLoading;
  List<DailyTask> get tasks => List<DailyTask>.unmodifiable(_sortedTasks);
  List<RecurringTemplate> get recurringTemplates =>
      List<RecurringTemplate>.unmodifiable(_recurringTemplates);

  List<DailyTask> get _sortedTasks {
    const priorityOrder = {
      TaskPriority.high: 0,
      TaskPriority.medium: 1,
      TaskPriority.low: 2,
    };
    final sorted = List<DailyTask>.from(_tasks);
    sorted.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      final pa = priorityOrder[a.priority] ?? 1;
      final pb = priorityOrder[b.priority] ?? 1;
      if (pa != pb) return pa.compareTo(pb);
      return a.createdAt.compareTo(b.createdAt);
    });
    return sorted;
  }

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
  double get completionRatio =>
      totalCount == 0 ? 0.0 : completedCount / totalCount;

  String get progressTitle {
    if (totalCount == 0) return 'Bugüne bir hedef koy';
    if (completedCount == totalCount) return 'Günlük set tamam';
    if (completionRatio >= 0.5) return 'Ritim yakalandı';
    return 'İlk hamleyi seç';
  }

  String get progressSubtitle {
    if (totalCount == 0) {
      return 'Su, öğün veya antrenman için küçük bir görev ekle.';
    }
    final remaining = totalCount - completedCount;
    if (remaining == 0) {
      return 'Bugünün tüm görevleri bitti. Seri için harika kayıt.';
    }
    return '$remaining görev kaldı. En kısa olanı şimdi bitir.';
  }

  List<DailyTaskMilestone> get milestones {
    final categoriesDone = _tasks
        .where((task) => task.isDone)
        .map((task) => task.category)
        .toSet();
    return <DailyTaskMilestone>[
      DailyTaskMilestone(
        id: 'first_task',
        title: 'İlk Adım',
        description: 'İlk görevi tamamla',
        icon: '1',
        isUnlocked: completedCount >= 1,
      ),
      DailyTaskMilestone(
        id: 'half_day',
        title: 'Ritim',
        description: 'Görevlerin yarısını bitir',
        icon: '50%',
        isUnlocked: totalCount > 0 && completionRatio >= 0.5,
      ),
      DailyTaskMilestone(
        id: 'balanced_day',
        title: 'Denge',
        description: 'Spor, beslenme ve suya dokun',
        icon: '3',
        isUnlocked:
            categoriesDone.contains(TaskCategory.sport) &&
            categoriesDone.contains(TaskCategory.nutrition) &&
            categoriesDone.contains(TaskCategory.water),
      ),
      DailyTaskMilestone(
        id: 'perfect_day',
        title: 'Tam Gün',
        description: 'Tüm görevleri tamamla',
        icon: '100%',
        isUnlocked: totalCount > 0 && completedCount == totalCount,
      ),
    ];
  }

  DailyTaskMilestone? get nextMilestone {
    for (final milestone in milestones) {
      if (!milestone.isUnlocked) return milestone;
    }
    return null;
  }

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
      _recurringTemplates = await _storage.loadRecurringTemplates();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  DailyTask? taskForTitle(String title) {
    final normalized = DailyTask.normalizeTitle(title);
    if (normalized.isEmpty) return null;
    for (final task in _tasks) {
      if (DailyTask.normalizeTitle(task.title) == normalized) return task;
    }
    return null;
  }

  Future<DailyTask?> addFromAiAction(String title) async {
    final existing = taskForTitle(title);
    if (existing != null) return existing;
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

  Future<void> addTask(
    String title, {
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.other,
    bool makeRecurring = false,
  }) async {
    final added = await _storage.addTaskIfNotExists(
      _selectedDate,
      title,
      source: 'manual',
      priority: priority,
      category: category,
      isRecurring: makeRecurring,
    );
    if (added != null) {
      _tasks = <DailyTask>[..._tasks, added];
    }

    if (makeRecurring) {
      final tmpl = await _storage.addRecurringTemplate(
        title: title,
        category: category,
        priority: priority,
      );
      if (tmpl != null) {
        _recurringTemplates = [..._recurringTemplates, tmpl];
      }
    }
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    await _storage.deleteTask(_selectedDate, taskId);
    _tasks = _tasks.where((task) => task.id != taskId).toList();
    notifyListeners();
  }

  Future<bool> toggleTaskDone(String taskId) async {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return false;
    final current = _tasks[index];
    final nextValue = !current.isDone;
    await _storage.toggleDone(_selectedDate, taskId, nextValue);
    _tasks = _tasks
        .map(
          (task) => task.id == taskId ? task.copyWith(isDone: nextValue) : task,
        )
        .toList();
    notifyListeners();
    return _tasks.isNotEmpty && _tasks.every((task) => task.isDone);
  }

  /// Belirtilen kategorideki ilk tamamlanmamış görevi otomatik tamamlar.
  /// Görev bulunup tamamlandıysa true, bulunamazsa false döner.
  Future<bool> autoCompleteFirstUndoneByCategory(TaskCategory category) async {
    DailyTask? target;
    for (final t in _tasks) {
      if (t.category == category && !t.isDone) {
        target = t;
        break;
      }
    }
    if (target == null) return false;
    return toggleTaskDone(target.id);
  }

  Future<void> removeRecurringTemplate(String id) async {
    await _storage.removeRecurringTemplate(id);
    _recurringTemplates = _recurringTemplates.where((t) => t.id != id).toList();
    notifyListeners();
  }

  /// Logout sırasında bellekteki görevleri temizler.
  void reset() {
    _tasks = [];
    _recurringTemplates = [];
    _filter = DailyTasksFilter.all;
    _selectedDate = _normalizeDate(_nowProvider());
    notifyListeners();
  }

  /// Silinmiş bir görevi geri yükler (undo desteği için).
  Future<void> restoreTask(DailyTask task) async {
    if (_tasks.any((t) => t.id == task.id)) return;
    _tasks = [..._tasks, task];
    await _storage.saveForDate(_selectedDate, _tasks);
    notifyListeners();
  }

  void setFilter(DailyTasksFilter filter) {
    if (_filter == filter) return;
    _filter = filter;
    notifyListeners();
  }

  static DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
