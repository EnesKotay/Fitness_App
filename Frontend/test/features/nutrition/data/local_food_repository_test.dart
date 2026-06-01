import 'package:pusulafit/features/nutrition/data/repositories/local_food_repository.dart';
import 'package:pusulafit/features/nutrition/domain/entities/food_item.dart';
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

  test('generic egg search shows common egg options in a tidy order', () async {
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
          id: 'yumurta_aki',
          name: 'Yumurta akı',
          category: 'Et & Protein',
          aliases: const ['yumurta beyazi', 'egg white'],
          tags: const ['yumurta', 'protein'],
        ),
        _food(
          id: 'yumurta_sarisi',
          name: 'Yumurta sarısı',
          category: 'Et & Protein',
          aliases: const ['egg yolk'],
          tags: const ['yumurta', 'protein'],
        ),
        _food(
          id: 'yumurta_orta',
          name: 'Yumurta (tam, orta)',
          category: 'Et & Protein',
          aliases: const ['yumurta', 'orta yumurta'],
          tags: const ['yumurta', 'protein'],
        ),
        _food(
          id: 'haslanmis_yumurta',
          name: 'Haşlanmış Yumurta',
          category: 'Yumurta',
          aliases: const ['yumurta haşlama'],
          tags: const ['yumurta', 'protein'],
        ),
        _food(
          id: 'pose_yumurta',
          name: 'Poşe Yumurta',
          category: 'Yumurta',
          aliases: const ['pose yumurta', 'poached egg'],
          tags: const ['yumurta', 'protein'],
        ),
        _food(
          id: 'sahanda_2_yumurta',
          name: 'Sahanda (2 Yumurta)',
          category: 'Kahvaltılık',
          tags: const ['sahanda', 'yumurta'],
        ),
        _food(
          id: 'sahanda_yumurta',
          name: 'Sahanda yumurta',
          category: 'Kahvaltılık',
          tags: const ['sahanda', 'yumurta'],
        ),
        _food(
          id: 'tr_food_1331_yumurta_tam',
          name: 'Yumurta (tam, büyük)',
          category: 'Et & Protein',
          aliases: const ['yumurta', 'egg', 'tavuk yumurtasi'],
          tags: const ['yumurta', 'protein', 'kahvalti'],
        ),
        _food(
          id: 'cirpilmis_yumurta',
          name: 'Çırpılmış Yumurta',
          category: 'Yumurta',
          aliases: const ['scrambled egg'],
          tags: const ['yumurta', 'protein'],
        ),
      ],
      customCache: const [],
      recipeCache: const [],
      synonyms: const {},
    );

    final results = await repository.searchFoods('yumurta');
    final ids = results.map((food) => food.id).toList();

    expect(ids.take(5), [
      'tr_food_1331_yumurta_tam',
      'haslanmis_yumurta',
      'pose_yumurta',
      'sahanda_yumurta',
      'yumurta_aki',
    ]);
    expect(
      ids.indexOf('cirpilmis_yumurta'),
      greaterThan(ids.indexOf('yumurta_sarisi')),
    );
    expect(ids, isNot(contains('yumurta_orta')));
    expect(ids, isNot(contains('sahanda_2_yumurta')));
  });

  test(
    'specific egg size searches still show matching size variants',
    () async {
      final repository = LocalFoodRepository(
        assetCache: [
          _food(
            id: 'yumurta_buyuk',
            name: 'Yumurta (tam, büyük)',
            category: 'Et & Protein',
            aliases: const ['yumurta', 'buyuk yumurta'],
            tags: const ['yumurta'],
          ),
          _food(
            id: 'yumurta_orta',
            name: 'Yumurta (tam, orta)',
            category: 'Et & Protein',
            aliases: const ['orta yumurta'],
            tags: const ['yumurta'],
          ),
        ],
        customCache: const [],
        recipeCache: const [],
        synonyms: const {},
      );

      final results = await repository.searchFoods('orta yumurta');

      expect(results.first.id, 'yumurta_orta');
    },
  );
}
