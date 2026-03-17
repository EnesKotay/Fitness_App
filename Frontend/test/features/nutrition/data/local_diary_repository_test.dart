import 'package:fitness/core/models/meal.dart';
import 'package:fitness/core/models/meal_models.dart';
import 'package:fitness/features/nutrition/data/datasources/hive_diet_storage.dart';
import 'package:fitness/features/nutrition/data/repositories/local_diary_repository.dart';
import 'package:fitness/features/nutrition/domain/entities/food_entry.dart';
import 'package:fitness/features/nutrition/domain/entities/meal_type.dart';
import 'package:fitness/features/nutrition/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalDiaryRepository remote sync', () {
    test('uploads unsynced local entries before fetching day data', () async {
      final storage = _FakeStorage(
        entries: [
          _entry(
            id: 'local_1',
            date: '2026-03-02',
            grams: 150,
            kcal: 330,
          ),
        ],
      );
      final remote = _FakeRemoteGateway(
        createdMeal: _meal(
          id: 99,
          name: 'Tavuk Sote',
          notes: '__app_meta__:food_tavuk|150.00',
          calories: 330,
        ),
        dayMeals: [
          _meal(
            id: 99,
            name: 'Tavuk Sote',
            notes: '__app_meta__:food_tavuk|150.00',
            calories: 330,
          ),
        ],
      );

      final repo = LocalDiaryRepository(
        storage: storage,
        remote: remote,
        userIdOverride: 1,
        tokenOverride: 'token',
      );

      final result = await repo.getEntriesByDate('2026-03-02');

      expect(remote.createCalls, 1);
      expect(result, hasLength(1));
      expect(result.first.id, 'api_99');
      expect(storage.entries.any((e) => e.id == 'local_1'), isFalse);
      expect(storage.entries.any((e) => e.id == 'api_99'), isTrue);
    });

    test('keeps local api entry when remote delete fails', () async {
      final storage = _FakeStorage(
        entries: [
          _entry(
            id: 'api_7',
            date: '2026-03-02',
            grams: 100,
            kcal: 220,
          ),
        ],
      );
      final remote = _FakeRemoteGateway(deleteThrows: true);
      final repo = LocalDiaryRepository(
        storage: storage,
        remote: remote,
        userIdOverride: 1,
        tokenOverride: 'token',
      );

      await expectLater(repo.deleteEntry('api_7'), throwsA(isA<Exception>()));
      expect(storage.entries.any((e) => e.id == 'api_7'), isTrue);
    });

    test('updates unsynced local entry by creating remote and replacing id', () async {
      final storage = _FakeStorage(
        entries: [
          _entry(
            id: 'temp_1',
            date: '2026-03-02',
            grams: 100,
            kcal: 220,
          ),
        ],
      );
      final remote = _FakeRemoteGateway(
        createdMeal: _meal(
          id: 42,
          name: 'Omlet',
          notes: '__app_meta__:food_omlet|180.00',
          calories: 396,
        ),
      );
      final repo = LocalDiaryRepository(
        storage: storage,
        remote: remote,
        userIdOverride: 1,
        tokenOverride: 'token',
      );

      await repo.updateEntry(
        _entry(
          id: 'temp_1',
          date: '2026-03-02',
          grams: 180,
          kcal: 396,
        ),
      );

      expect(remote.createCalls, 1);
      expect(storage.entries.any((e) => e.id == 'temp_1'), isFalse);
      expect(storage.entries.any((e) => e.id == 'api_42'), isTrue);
    });
  });
}

FoodEntry _entry({
  required String id,
  required String date,
  required double grams,
  required double kcal,
}) {
  return FoodEntry(
    id: id,
    date: date,
    mealType: MealType.lunch,
    foodId: 'food_tavuk',
    foodName: 'Tavuk Sote',
    grams: grams,
    calculatedKcal: kcal,
    protein: 20,
    carb: 10,
    fat: 8,
    createdAt: DateTime(2026, 3, 2, 12, 0, 0),
  );
}

Meal _meal({
  required int id,
  required String name,
  required String notes,
  required int calories,
}) {
  return Meal(
    id: id,
    name: name,
    mealType: 'LUNCH',
    calories: calories,
    protein: 20,
    carbs: 10,
    fat: 8,
    mealDate: DateTime(2026, 3, 2, 12, 0, 0),
    notes: notes,
    createdAt: DateTime(2026, 3, 2, 12, 0, 0),
    updatedAt: DateTime(2026, 3, 2, 12, 0, 0),
  );
}

class _FakeRemoteGateway implements NutritionRemoteGateway {
  _FakeRemoteGateway({
    this.createdMeal,
    List<Meal>? dayMeals,
    this.deleteThrows = false,
  }) : dayMeals = dayMeals ?? const [];

  final Meal? createdMeal;
  final List<Meal> dayMeals;
  final bool deleteThrows;
  int createCalls = 0;

  @override
  Future<Meal> createMeal(int userId, MealRequest request) async {
    createCalls++;
    if (createdMeal != null) return createdMeal!;
    return _meal(
      id: 1,
      name: request.name ?? 'Meal',
      notes: request.notes ?? '',
      calories: request.calories ?? 0,
    );
  }

  @override
  Future<void> deleteMeal(int userId, int mealId) async {
    if (deleteThrows) {
      throw Exception('delete failed');
    }
  }

  @override
  Future<List<Meal>> getMealsByDate(int userId, DateTime date) async => dayMeals;

  @override
  Future<List<Meal>> getUserMeals(int userId) async => dayMeals;

  @override
  Future<Meal> updateMeal(int userId, int mealId, MealRequest request) async {
    return _meal(
      id: mealId,
      name: request.name ?? 'Updated',
      notes: request.notes ?? '',
      calories: request.calories ?? 0,
    );
  }
}

class _FakeStorage extends HiveDietStorage {
  _FakeStorage({List<FoodEntry>? entries}) : entries = entries ?? [];

  List<FoodEntry> entries;
  UserProfile? _profile;

  @override
  Future<UserProfile?> getProfile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }

  @override
  Future<List<FoodEntry>> getAllEntries() async => List<FoodEntry>.from(entries);

  @override
  Future<void> saveAllEntries(List<FoodEntry> updatedEntries) async {
    entries = List<FoodEntry>.from(updatedEntries);
  }

  @override
  Future<List<String>> getRecentFoodIds(int limit) async {
    final ids = <String>{};
    final result = <String>[];
    for (final entry in entries.reversed) {
      if (ids.add(entry.foodId)) {
        result.add(entry.foodId);
      }
      if (result.length >= limit) break;
    }
    return result;
  }

  @override
  Future<List<String>> getFrequentFoodIds(int limit) async {
    final counts = <String, int>{};
    for (final entry in entries) {
      counts[entry.foodId] = (counts[entry.foodId] ?? 0) + 1;
    }
    final sorted = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
    return sorted.take(limit).toList();
  }
}
