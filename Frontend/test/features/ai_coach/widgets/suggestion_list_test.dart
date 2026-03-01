import 'package:fitness/features/ai_coach/models/ai_coach_models.dart';
import 'package:fitness/features/ai_coach/widgets/suggestion_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SuggestionList renders grouped sections and actions', (
    tester,
  ) async {
    const advice = CoachAdviceView(
      focus: 'Formu bozmadan temiz tekrarlar yap.',
      actions: [
        'Aksam yemeginden sonra 20 dakika yuru.',
        '3 set plank uygula.',
      ],
      nutritionNote: 'Aksam protein ve sebze agirlikli ilerle.',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SuggestionList(advice: advice, isLoading: true),
          ),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('Bugunun Odagi'), findsOneWidget);
    expect(find.text('Yapilacaklar'), findsOneWidget);
    expect(find.text('Beslenme Notu'), findsOneWidget);
    expect(find.text('Aksam yemeginden sonra 20 dakika yuru.'), findsOneWidget);
    expect(find.text('3 set plank uygula.'), findsOneWidget);
  });

  testWidgets('SuggestionList shows placeholders and error state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SuggestionList(
              advice: CoachAdviceView(),
              errorMessage: 'Istek basarisiz.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Istek basarisiz.'), findsOneWidget);
    expect(find.text('Henuz yok'), findsNWidgets(3));
  });

  testWidgets('SuggestionList prioritizes cooldown bar over error bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SuggestionList(
              advice: CoachAdviceView(),
              errorMessage: 'Istek basarisiz.',
              cooldownSecondsRemaining: 5,
            ),
          ),
        ),
      ),
    );

    expect(
      find.text('Rate limit. 5s sonra tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    expect(find.text('Istek basarisiz.'), findsNothing);
  });
}
