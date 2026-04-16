import 'package:fitness/core/api/api_exception.dart';
import 'package:fitness/features/ai_coach/controllers/ai_coach_controller.dart';
import 'package:fitness/features/ai_coach/models/ai_coach_models.dart';
import 'package:fitness/features/ai_coach/screens/ai_coach_screen.dart';
import 'package:fitness/features/ai_coach/services/ai_coach_service.dart';
import 'package:fitness/features/nutrition/domain/entities/user_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import '../../../test_helpers/app_test_wrappers.dart';

class _RateLimitService extends AiCoachService {
  @override
  Future<CoachResponse> generatePlan({
    required Goal goal,
    required DailySummary summary,
    required String userPrompt,
    CoachPersonality personality = CoachPersonality.supportive,
    CoachTaskMode taskMode = CoachTaskMode.plan,
    List<CoachConversationTurn> conversationHistory =
        const <CoachConversationTurn>[],
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
    await tester.pumpWidget(buildTestApp(const AiCoachScreen()));
    await tester.pump();

    expect(find.text('AI Koç'), findsOneWidget);
    expect(find.text('Koç karakterini seç'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('429 starts cooldown and re-enables prompt after countdown', (
    tester,
  ) async {
    final controller = AiCoachController(service: _RateLimitService());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      buildTestApp(
        const AiCoachScreenBody(),
        extraProviders: [
          ChangeNotifierProvider<AiCoachController>.value(value: controller),
        ],
      ),
    );
    await tester.pump();

    await controller.submitPrompt('Plan hazirla');
    await tester.pump();

    expect(controller.isCooldownActive, isTrue);
    expect(controller.cooldownSecondsRemaining, 3);
    expect(
      find.textContaining('3s sonra tekrar deneyebilirsin'),
      findsWidgets,
    );

    await tester.pump(const Duration(seconds: 1));
    expect(controller.cooldownSecondsRemaining, 2);

    await tester.pump(const Duration(seconds: 2));
    expect(controller.isCooldownActive, isFalse);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
