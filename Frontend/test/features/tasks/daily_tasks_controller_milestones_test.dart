import 'package:flutter_test/flutter_test.dart';
import 'package:pusulafit/features/tasks/controllers/daily_tasks_controller.dart';
import 'package:pusulafit/features/tasks/models/daily_task.dart';
import 'package:pusulafit/features/tasks/storage/daily_task_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('milestones unlock from task completion and category spread', () async {
    final date = DateTime(2026, 5, 25);
    final prefs = await SharedPreferences.getInstance();
    final storage = DailyTaskStorage(prefs: prefs);
    final controller = DailyTasksController(
      storage: storage,
      nowProvider: () => date,
    );
    addTearDown(controller.dispose);

    await controller.addTask('30 dk yürüyüş', category: TaskCategory.sport);
    await controller.addTask(
      'Proteinli öğün',
      category: TaskCategory.nutrition,
    );
    await controller.addTask('2 litre su', category: TaskCategory.water);

    expect(controller.progressTitle, 'İlk hamleyi seç');
    expect(controller.nextMilestone?.id, 'first_task');

    await controller.toggleTaskDone(
      controller.taskForTitle('30 dk yürüyüş')!.id,
    );
    expect(controller.milestones.first.isUnlocked, isTrue);
    expect(
      controller.milestones
          .firstWhere((milestone) => milestone.id == 'half_day')
          .isUnlocked,
      isFalse,
    );

    await controller.toggleTaskDone(
      controller.taskForTitle('Proteinli öğün')!.id,
    );
    await controller.toggleTaskDone(controller.taskForTitle('2 litre su')!.id);

    expect(controller.completedCount, 3);
    expect(controller.progressTitle, 'Günlük set tamam');
    expect(controller.nextMilestone, isNull);
  });
}
