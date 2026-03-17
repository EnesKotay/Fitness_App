import 'package:flutter_test/flutter_test.dart';
import 'package:fitness/features/workout/data/workout_catalog_data.dart';

void main() {
  test('each primary muscle group exposes at least five catalog exercises', () {
    for (final group in kMuscleGroupInfo.keys) {
      final catalog = buildExerciseCatalogForGroup(group);
      expect(
        catalog.length,
        greaterThanOrEqualTo(5),
        reason: '$group katalogu en az 5 hareket icermeli',
      );
    }
  });
}
