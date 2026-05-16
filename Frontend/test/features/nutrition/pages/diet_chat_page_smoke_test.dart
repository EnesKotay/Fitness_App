import 'package:pusulafit/features/nutrition/presentation/pages/diet_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../test_helpers/app_test_wrappers.dart';

void main() {
  testWidgets('DietChatPage renders basic chat UI', (tester) async {
    await tester.pumpWidget(buildTestApp(const DietChatPage()));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(IconButton), findsWidgets);
    expect(find.text('Nasıl yardımcı olabilirim?'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
