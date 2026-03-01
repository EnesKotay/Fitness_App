import 'package:fitness/features/ai_coach/models/ai_coach_models.dart';
import 'package:fitness/features/ai_coach/widgets/suggestion_list.dart';
import 'package:fitness/features/tasks/controllers/daily_tasks_controller.dart';
import 'package:fitness/features/tasks/storage/daily_task_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Action item can be added to plan and toggled done', (
    tester,
  ) async {
    final date = DateTime(2026, 2, 15);
    final prefs = await SharedPreferences.getInstance();
    final controller = DailyTasksController(
      storage: DailyTaskStorage(prefs: prefs),
      nowProvider: () => date,
    );
    addTearDown(controller.dispose);
    await controller.loadToday();

    const advice = CoachAdviceView(
      focus: 'Forma odaklan.',
      actions: ['Aksam 20 dakika yuruyus yap'],
      nutritionNote: 'Su tuketimini artir.',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<DailyTasksController>.value(
        value: controller,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer<DailyTasksController>(
              builder: (context, tasks, _) {
                return SuggestionList(
                  advice: advice,
                  plannedActionsByTitle: tasks.tasksByNormalizedTitle,
                  onAddActionToPlan: (title) {
                    tasks.addFromAiAction(title);
                  },
                  onToggleActionTaskDone: (taskId) {
                    tasks.toggleTaskDone(taskId);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan\'a ekle'), findsOneWidget);

    await tester.tap(find.text('Plan\'a ekle'));
    await tester.pumpAndSettle();

    expect(controller.totalCount, 1);
    expect(find.textContaining('Plan\'da'), findsOneWidget);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    final task = controller.taskForTitle('Aksam 20 dakika yuruyus yap');
    expect(task, isNotNull);
    expect(task!.isDone, isTrue);
  });
}
