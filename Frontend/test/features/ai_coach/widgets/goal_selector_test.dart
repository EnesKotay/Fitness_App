import 'package:pusulafit/features/ai_coach/widgets/goal_selector.dart';
import 'package:pusulafit/features/nutrition/domain/entities/user_profile.dart';
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
    expect(find.text('Yağ Yakımı'), findsOneWidget);
    expect(find.text('Güç'), findsOneWidget);

    await tester.tap(find.text('Yağ Yakımı'));
    await tester.pump();

    expect(selected, Goal.cut);
  });
}
