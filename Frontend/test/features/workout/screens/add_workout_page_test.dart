import 'package:fitness/core/models/workout.dart';
import 'package:fitness/core/models/workout_set.dart';
import 'package:fitness/features/auth/providers/auth_provider.dart';
import 'package:fitness/features/nutrition/presentation/state/diet_provider.dart';
import 'package:fitness/features/workout/providers/workout_provider.dart';
import 'package:fitness/features/workout/screens/add_workout_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('AddWorkoutPage edit mode restores set details and superset info', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final workout = Workout(
      id: 7,
      name: 'Bench Press',
      workoutDate: DateTime(2026, 3, 29),
      workoutType: 'Göğüs',
      muscleGroup: 'CHEST',
      sets: 2,
      reps: 8,
      weight: 60,
      isSuperset: true,
      supersetPartner: 'Push Up',
      setDetails: const [
        WorkoutSet(setNumber: 1, setType: 'WARMUP', reps: 12, weight: 20),
        WorkoutSet(setNumber: 2, setType: 'NORMAL', reps: 8, weight: 60),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => WorkoutProvider()),
          ChangeNotifierProvider(create: (_) => DietProvider()),
        ],
        child: MaterialApp(home: AddWorkoutPage(workout: workout)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bench Press', skipOffstage: false), findsWidgets);

    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();

    expect(find.text('Push Up', skipOffstage: false), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Dismissible,
        skipOffstage: false,
      ),
      findsNWidgets(2),
    );
  });
}
