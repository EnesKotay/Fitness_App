import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness/features/nutrition/models/nutrition_ai_response.dart';
import 'package:fitness/features/nutrition/presentation/widgets/meal_card.dart';

void main() {
  group('MealCard Widget Tests', () {
    testWidgets('renders meal card with name and calories', (
      WidgetTester tester,
    ) async {
      final meal = SuggestedMealModel(
        name: 'Tavuklu Salata',
        reason: 'Düşük kalorili ve proteinli',
        macros: MealMacrosModel(kcal: 350, proteinG: 30, carbsG: 15, fatG: 12),
        prepMinutes: 15,
        tags: ['düşük kalorili', 'akşam'],
        ingredients: ['tavuk', 'marul', 'domates'],
        steps: ['Tavugu pisir', 'Sebzeleri doğra', 'Karıştır'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MealCard(meal: meal)),
          ),
        ),
      );

      // Verify meal name is displayed
      expect(find.text('Tavuklu Salata'), findsOneWidget);

      // Verify calories are displayed
      expect(find.text('350 kcal'), findsOneWidget);

      // Verify prep time is displayed
      expect(find.text('15 dk'), findsOneWidget);
    });

    testWidgets('displays meal macros correctly', (WidgetTester tester) async {
      final meal = SuggestedMealModel(
        name: 'Test Meal',
        reason: 'Test reason',
        macros: MealMacrosModel(kcal: 500, proteinG: 40, carbsG: 50, fatG: 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MealCard(meal: meal)),
          ),
        ),
      );

      expect(find.text('500 kcal'), findsOneWidget);
      expect(find.text('P: 40g'), findsOneWidget);
      expect(find.text('K: 50g'), findsOneWidget);
      expect(find.text('Y: 20g'), findsOneWidget);
    });

    testWidgets('displays tags correctly', (WidgetTester tester) async {
      final meal = SuggestedMealModel(
        name: 'Test Meal',
        reason: 'Test reason',
        tags: ['kahvaltı', 'vegan', 'düşük karbonhidrat'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: MealCard(meal: meal)),
          ),
        ),
      );

      expect(find.text('kahvaltı'), findsOneWidget);
      expect(find.text('vegan'), findsOneWidget);
      expect(find.text('düşük karbonhidrat'), findsOneWidget);
    });

    testWidgets('shows follow-up question chips', (WidgetTester tester) async {
      // This tests the follow-up questions in the chat page
      const questions = [
        'Bu yemeği nasıl hazırlarım?',
        'Malzemeleri nereden alabilirim?',
        'Kaç kalori?',
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              spacing: 8,
              children: questions
                  .map((q) => ActionChip(label: Text(q), onPressed: () {}))
                  .toList(),
            ),
          ),
        ),
      );

      expect(find.text('Bu yemeği nasıl hazırlarım?'), findsOneWidget);
      expect(find.text('Malzemeleri nereden alabilirim?'), findsOneWidget);
      expect(find.text('Kaç kalori?'), findsOneWidget);
    });

    testWidgets('MealCard has add to diary button', (
      WidgetTester tester,
    ) async {
      bool addButtonPressed = false;

      final meal = SuggestedMealModel(name: 'Test Meal', reason: 'Test reason');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MealCard(
                meal: meal,
                onAddToDiary: () {
                  addButtonPressed = true;
                },
              ),
            ),
          ),
        ),
      );

      // Find and tap the add to diary button
      expect(find.text('Günlüğe ekle'), findsOneWidget);

      await tester.tap(find.text('Günlüğe ekle'));
      await tester.pump();

      expect(addButtonPressed, isTrue);
    });
  });
}
