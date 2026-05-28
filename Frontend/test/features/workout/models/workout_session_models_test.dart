import 'package:flutter_test/flutter_test.dart';
import 'package:pusulafit/core/models/workout_models.dart';
import 'package:pusulafit/core/models/workout_set.dart';

void main() {
  test('WorkoutSessionRequest serializes exercises and RPE set details', () {
    final request = WorkoutSessionRequest(
      title: 'Push Day',
      startedAt: DateTime(2026, 5, 28, 18),
      finishedAt: DateTime(2026, 5, 28, 19),
      plannedSetCount: 2,
      completedSetCount: 1,
      difficulty: 'Orta',
      exercises: [
        WorkoutSessionExerciseRequest(
          name: 'Bench Press',
          muscleGroup: 'CHEST',
          plannedSets: 2,
          completedSets: 1,
          reps: 8,
          weight: 80,
          restSeconds: 120,
          setDetails: const [
            WorkoutSet(setNumber: 1, reps: 8, weight: 80, rpe: 8.5),
          ],
        ),
      ],
    );

    final json = request.toJson();
    final exercises = json['exercises'] as List<dynamic>;
    final first = exercises.first as Map<String, dynamic>;
    final sets = first['setDetails'] as List<dynamic>;

    expect(json['title'], 'Push Day');
    expect(first['name'], 'Bench Press');
    expect(first['weight'], 80);
    expect((sets.first as Map<String, dynamic>)['rpe'], 8.5);

    final parsed = WorkoutSessionRequest.fromJson(json);
    expect(parsed.exercises.single.setDetails.single.rpe, 8.5);
  });
}
