import 'package:fitness/features/tasks/storage/daily_task_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('addTaskIfNotExists dedupes same title for same day', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = DailyTaskStorage(prefs: prefs);
    final date = DateTime(2026, 2, 15);

    final first = await storage.addTaskIfNotExists(date, ' 20 dk yuruyus ');
    final second = await storage.addTaskIfNotExists(date, '20  DK   YURUYUS');

    expect(first, isNotNull);
    expect(second, isNull);

    final loaded = await storage.loadForDate(date);
    expect(loaded, hasLength(1));
    expect(loaded.first.title, '20 dk yuruyus');
  });

  test('toggleDone updates completion state', () async {
    final prefs = await SharedPreferences.getInstance();
    final storage = DailyTaskStorage(prefs: prefs);
    final date = DateTime(2026, 2, 15);

    final task = await storage.addTaskIfNotExists(date, '3 set plank');
    expect(task, isNotNull);

    await storage.toggleDone(date, task!.id, true);
    final doneList = await storage.loadForDate(date);
    expect(doneList.single.isDone, isTrue);

    await storage.toggleDone(date, task.id, false);
    final todoList = await storage.loadForDate(date);
    expect(todoList.single.isDone, isFalse);
  });
}
