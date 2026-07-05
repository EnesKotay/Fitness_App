import 'package:flutter_test/flutter_test.dart';
import 'package:pusulafit/core/services/page_guide_service.dart';
import 'package:pusulafit/core/utils/storage_helper.dart';
import 'package:pusulafit/features/ai_coach/services/ai_coach_session_service.dart';
import 'package:pusulafit/features/ai_coach/services/ai_coach_usage_service.dart';
import 'package:pusulafit/features/workout/models/training_phase.dart';
import 'package:pusulafit/features/workout/services/training_phase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageHelper.init();
  });

  test('page guide seen state is scoped by account email', () async {
    await StorageHelper.saveUserEmail('one@example.com');
    expect(await PageGuideService.hasSeenGuide('nutrition'), isFalse);

    await PageGuideService.markGuideSeen('nutrition');
    expect(await PageGuideService.hasSeenGuide('nutrition'), isTrue);

    await StorageHelper.saveUserEmail('two@example.com');
    expect(await PageGuideService.hasSeenGuide('nutrition'), isFalse);

    await StorageHelper.saveUserEmail('one@example.com');
    expect(await PageGuideService.hasSeenGuide('nutrition'), isTrue);
  });

  test('US experience prompt seen state is scoped by account email', () async {
    await StorageHelper.saveUserEmail('one@example.com');
    expect(StorageHelper.getUsExperiencePromptSeen(), isFalse);

    await StorageHelper.saveUsExperiencePromptSeen(true);
    expect(StorageHelper.getUsExperiencePromptSeen(), isTrue);

    await StorageHelper.saveUserEmail('two@example.com');
    expect(StorageHelper.getUsExperiencePromptSeen(), isFalse);
  });

  test(
    'app preferences and onboarding state are scoped by account email',
    () async {
      await StorageHelper.saveUserEmail('one@example.com');
      await StorageHelper.saveAppLanguageCode('en');
      await StorageHelper.saveAppUnitSystem('imperial');
      await StorageHelper.saveAppMarketRegion('us');
      await StorageHelper.saveOnboardingDone(true);

      await StorageHelper.saveUserEmail('two@example.com');
      expect(StorageHelper.getAppLanguageCode(), isNull);
      expect(StorageHelper.getAppUnitSystem(), isNull);
      expect(StorageHelper.getAppMarketRegion(), isNull);
      expect(StorageHelper.getOnboardingDone(), isFalse);

      await StorageHelper.saveUserEmail('one@example.com');
      expect(StorageHelper.getAppLanguageCode(), 'en');
      expect(StorageHelper.getAppUnitSystem(), 'imperial');
      expect(StorageHelper.getAppMarketRegion(), 'us');
      expect(StorageHelper.getOnboardingDone(), isTrue);
    },
  );

  test('training phase is scoped by account email', () async {
    final service = TrainingPhaseService();

    await StorageHelper.saveUserEmail('one@example.com');
    await service.savePhase(TrainingPhase.strength);
    expect(await service.loadPhase(), TrainingPhase.strength);

    await StorageHelper.saveUserEmail('two@example.com');
    expect(await service.loadPhase(), TrainingPhase.hypertrophy);
  });

  test('AI usage and current session are scoped by account email', () async {
    final usage = AiCoachUsageService();
    final sessions = AiCoachSessionService();

    await StorageHelper.saveUserEmail('one@example.com');
    await usage.incrementPromptCount(userId: 1, date: DateTime(2026, 6, 30));
    await sessions.saveSession(
      userId: 1,
      messages: const [
        {'role': 'user', 'content': 'program ver'},
      ],
    );
    expect(
      await usage.getRemainingFreePrompts(
        userId: 1,
        date: DateTime(2026, 6, 30),
      ),
      1,
    );
    expect(await sessions.loadSession(userId: 1), hasLength(1));

    await StorageHelper.saveUserEmail('two@example.com');
    expect(
      await usage.getRemainingFreePrompts(
        userId: 1,
        date: DateTime(2026, 6, 30),
      ),
      AiCoachUsageService.freeDailyPromptLimit,
    );
    expect(await sessions.loadSession(userId: 1), isEmpty);
  });
}
