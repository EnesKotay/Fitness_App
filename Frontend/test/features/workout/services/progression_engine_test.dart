import 'package:pusulafit/core/models/workout.dart';
import 'package:pusulafit/features/workout/services/progression_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'ProgressionEngine uses the latest workouts for trend and suggestion',
    () {
      final history = <Workout>[
        Workout(
          id: 1,
          name: 'Bench Press',
          workoutDate: DateTime(2026, 3, 10),
          reps: 8,
          weight: 60,
        ),
        Workout(
          id: 2,
          name: 'Bench Press',
          workoutDate: DateTime(2026, 3, 17),
          reps: 9,
          weight: 62.5,
        ),
        Workout(
          id: 3,
          name: 'Bench Press',
          workoutDate: DateTime(2026, 3, 24),
          reps: 10,
          weight: 65,
        ),
      ];

      final hint = ProgressionEngine.compute(
        history: history,
        exerciseName: 'Bench Press',
        targetReps: 10,
      );

      expect(hint.lastWeight, 65);
      expect(hint.lastReps, 10);
      expect(hint.trendDirection, TrendDirection.up);
      expect(hint.suggestedWeight, 65);
      expect(hint.readilyProgressed, isTrue);
    },
  );
}
