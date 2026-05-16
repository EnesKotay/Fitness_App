import 'package:flutter_test/flutter_test.dart';
import 'package:pusulafit/core/models/exercise.dart';
import 'package:pusulafit/features/workout/models/exercise_guide_data.dart';

void main() {
  test('instruction parser strips escaped newlines and numbering', () {
    final guide = buildExerciseGuideData(
      Exercise(
        id: 1,
        muscleGroup: 'BACK',
        name: 'Cable Row',
        instructions:
            r'1\nAyaklarini sabitle.\n2\nGogsunu ac.\n3\nDirseklerini geriye sur.',
      ),
    );

    expect(
      guide.executionSteps,
      containsAll([
        'Ayaklarini sabitle.',
        'Gogsunu ac.',
        'Dirseklerini geriye sur.',
      ]),
    );
    expect(
      guide.executionSteps.any((step) => step == '1' || step == r'\n2'),
      isFalse,
    );
  });

  test('bench press uses exercise-specific override content', () {
    final guide = buildExerciseGuideData(
      Exercise(id: 2, muscleGroup: 'CHEST', name: 'Bench Press'),
    );

    expect(guide.frames, hasLength(5));
    expect(guide.setup, contains('kürek kemiklerini geriye al'));
    expect(guide.tempo, '3-1-1: 3 sn iniş, altta 1 sn duruş, 1 sn güçlü itiş.');
    expect(
      guide.commonMistakes.any(
        (issue) => issue.issue == 'Barı göğüste sektirmek',
      ),
      isTrue,
    );
  });
}
