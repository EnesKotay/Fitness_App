import 'package:fitness/features/nutrition/presentation/pages/diet_chat_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DietChatPage renders basic chat UI', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DietChatPage()));

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(IconButton), findsWidgets);
    expect(find.textContaining('Merhaba'), findsOneWidget);
  });
}
