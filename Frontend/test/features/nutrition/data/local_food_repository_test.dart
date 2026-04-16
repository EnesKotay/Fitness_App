import 'package:fitness/features/nutrition/data/repositories/local_food_repository.dart';
import 'package:fitness/features/nutrition/domain/entities/food_item.dart';
import 'package:flutter_test/flutter_test.dart';

FoodItem _food({
  required String id,
  required String name,
  required String category,
  List<String> aliases = const [],
  List<String> tags = const [],
}) {
  return FoodItem(
    id: id,
    name: name,
    category: category,
    basis: const FoodBasis(amount: 100, unit: 'g'),
    nutrients: const Nutrients(kcal: 100, protein: 10, carb: 10, fat: 5),
    aliases: aliases,
    tags: tags,
  );
}

void main() {
  test(
    'single-word search prioritizes exact egg items over derived words',
    () async {
      final repository = LocalFoodRepository(
        assetCache: [
          _food(
            id: 'yumurtali_pide',
            name: 'Yumurtali pide',
            category: 'Firin & Pide',
            aliases: const ['yumurtali pide', 'pide yumurta'],
            tags: const ['pide', 'yumurta', 'turk-mutfagi'],
          ),
          _food(
            id: 'yumurta',
            name: 'Yumurta (tam, buyuk)',
            category: 'Et & Protein',
            aliases: const ['yumurta', 'egg', 'tavuk yumurtasi'],
            tags: const ['yumurta', 'protein', 'kahvalti'],
          ),
        ],
        customCache: const [],
        recipeCache: const [],
        synonyms: const {},
      );

      final results = await repository.searchFoods('yumurta');

      expect(results, hasLength(2));
      expect(results.first.id, 'yumurta');
      expect(results.last.id, 'yumurtali_pide');
    },
  );
}
