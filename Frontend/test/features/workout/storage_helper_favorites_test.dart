import 'package:fitness/core/utils/storage_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageHelper.init();
    await StorageHelper.saveUserEmail('tester@example.com');
  });

  test('favorite exercises persist metadata alongside legacy names', () async {
    final saved = await StorageHelper.toggleFavoriteExercise(
      'Bench Press',
      muscleGroup: 'CHEST',
      exerciseId: 42,
    );

    expect(saved, isTrue);
    expect(StorageHelper.getFavoriteExerciseNames(), ['Bench Press']);

    final entries = StorageHelper.getFavoriteExercises();
    expect(entries, hasLength(1));
    expect(entries.first.name, 'Bench Press');
    expect(entries.first.muscleGroup, 'CHEST');
    expect(entries.first.exerciseId, 42);
    expect(
      StorageHelper.isFavoriteExercise('Bench Press', muscleGroup: 'CHEST'),
      isTrue,
    );
  });
}
