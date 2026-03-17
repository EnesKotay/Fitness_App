import 'package:fitness/core/api/api_exception.dart';
import 'package:fitness/features/ai_coach/controllers/ai_coach_controller.dart';
import 'package:fitness/features/ai_coach/models/ai_coach_models.dart';
import 'package:fitness/features/ai_coach/screens/ai_coach_screen.dart';
import 'package:fitness/features/ai_coach/services/ai_coach_service.dart';
import 'package:fitness/features/nutrition/domain/entities/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _RateLimitService extends AiCoachService {
  @override
  Future<CoachResponse> generatePlan({
    required Goal goal,
    required DailySummary summary,
    required String userPrompt,
  }) async {
    throw ApiException(
      message: 'Cok fazla istek. 3s sonra tekrar dene.',
      statusCode: 429,
      data: {'retryAfterSeconds': 3},
    );
  }
}

void main() {
  testWidgets('AiCoachScreen renders core sections', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiCoachScreen()));

    expect(find.text('AI Koc'), findsOneWidget);
    expect(find.text('Hedefin'), findsOneWidget);
    expect(find.text('Gunluk Ozet'), findsOneWidget);
    expect(find.text('Koca Sor'), findsOneWidget);

    final verticalList = find.byWidgetPredicate(
      (widget) => widget is ListView && widget.scrollDirection == Axis.vertical,
    );
    await tester.drag(verticalList.first, const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(find.text('Oneriler'), findsOneWidget);
  });

  testWidgets('429 starts cooldown and re-enables prompt after countdown', (
    tester,
  ) async {
    final controller = AiCoachController(service: _RateLimitService());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<AiCoachController>.value(
        value: controller,
        child: const MaterialApp(home: AiCoachScreenBody()),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Plan hazirla');
    await tester.pump();
    await tester.tap(find.text('Gonder'));
    await tester.pump();

    expect(controller.isCooldownActive, isTrue);
    expect(controller.cooldownSecondsRemaining, 3);
    expect(find.textContaining('3s bekle'), findsOneWidget);

    final sendButton = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(sendButton.onPressed, isNull);

    await tester.pump(const Duration(seconds: 1));
    expect(controller.cooldownSecondsRemaining, 2);

    await tester.pump(const Duration(seconds: 2));
    expect(controller.isCooldownActive, isFalse);
    expect(find.text('Gonder'), findsOneWidget);
  });
}
