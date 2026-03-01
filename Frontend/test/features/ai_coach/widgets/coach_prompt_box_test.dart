import 'package:fitness/features/ai_coach/widgets/coach_prompt_box.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CoachPromptBox sends trimmed text and clears input', (
    tester,
  ) async {
    String? sent;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachPromptBox(
            onSend: (text) {
              sent = text;
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      '  Build me a quick workout  ',
    );
    await tester.pump();
    await tester.tap(find.text('Gonder'));
    await tester.pump();

    expect(sent, 'Build me a quick workout');
    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text ?? '', '');
  });

  testWidgets('CoachPromptBox fills input when quick prompt tapped', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoachPromptBox(
            quickPrompts: const ['Ornek soru'],
            onSend: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Ornek soru'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, 'Ornek soru');
  });
}
