import 'package:fitness/features/ai_coach/models/ai_coach_models.dart';
import 'package:fitness/features/ai_coach/widgets/goal_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GoalSelector renders and triggers callback', (tester) async {
    CoachGoal selected = CoachGoal.bulk;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalSelector(
            goal: selected,
            onChanged: (goal) {
              selected = goal;
            },
          ),
        ),
      ),
    );

    expect(find.text('Hedefin'), findsOneWidget);
    expect(find.text('Hacim'), findsOneWidget);
    expect(find.text('Yag Yakimi'), findsOneWidget);
    expect(find.text('Guc'), findsOneWidget);

    await tester.tap(find.text('Yag Yakimi'));
    await tester.pump();

    expect(selected, CoachGoal.cut);
  });
}
