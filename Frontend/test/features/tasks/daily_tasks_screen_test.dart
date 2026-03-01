import 'package:fitness/features/tasks/controllers/daily_tasks_controller.dart';
import 'package:fitness/features/tasks/screens/daily_tasks_screen.dart';
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

  testWidgets('DailyTasksScreen renders progress and filters tasks', (
    tester,
  ) async {
    final date = DateTime(2026, 2, 15);
    final prefs = await SharedPreferences.getInstance();
    final storage = DailyTaskStorage(prefs: prefs);

    final first = await storage.addTaskIfNotExists(date, 'Yuruyus');
    final second = await storage.addTaskIfNotExists(date, 'Protein ogunu');
    await storage.toggleDone(date, second!.id, true);

    final controller = DailyTasksController(
      storage: storage,
      nowProvider: () => date,
    );
    addTearDown(controller.dispose);
    await controller.loadToday();

    await tester.pumpWidget(
      ChangeNotifierProvider<DailyTasksController>.value(
        value: controller,
        child: const MaterialApp(home: DailyTasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gunluk Gorevler'), findsOneWidget);
    expect(find.text('1/2 tamamlandi'), findsOneWidget);
    expect(find.text('Yuruyus'), findsOneWidget);
    expect(find.text('Protein ogunu'), findsOneWidget);

    await tester.tap(find.text('Yapilacak'));
    await tester.pumpAndSettle();
    expect(find.text('Yuruyus'), findsOneWidget);
    expect(find.text('Protein ogunu'), findsNothing);

    await tester.tap(find.text('Tamamlanan'));
    await tester.pumpAndSettle();
    expect(find.text('Yuruyus'), findsNothing);
    expect(find.text('Protein ogunu'), findsOneWidget);

    await tester.tap(find.text('Tumu'));
    await tester.pumpAndSettle();
    expect(find.text('Yuruyus'), findsOneWidget);
    expect(find.text('Protein ogunu'), findsOneWidget);
    expect(first, isNotNull);
  });
}
