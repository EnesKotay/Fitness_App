import 'package:fitness/features/ai_coach/widgets/goal_selector.dart';
import 'package:fitness/features/nutrition/domain/entities/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GoalSelector renders and triggers callback', (tester) async {
    Goal selected = Goal.bulk;

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

    expect(selected, Goal.cut);
  });
}
