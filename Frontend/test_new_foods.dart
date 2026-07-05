import 'lib/core/data/food_database.dart';

void main() {
  print('📊 Toplam Yemek Sayısı: ${FoodDatabase.foods.length}\n');

  // Yeni eklenen yaygın tatlılar
  final desserts = [
    'cikolatali-milfoy',
    'cikolatali-kruvasan',
    'browni',
    'cheesecake',
    'tiramisu',
    'profiterol',
    'tulumba-tatlisi',
    'lokma',
    'kunefe',
  ];

  print('🍰 Yeni Eklenen Tatlılar:');
  for (final id in desserts) {
    final food = FoodDatabase.findById(id);
    if (food != null) {
      print('  ✅ ${food.name}: ${food.caloriesPer100g} kcal/100g (Porsiyon: ${food.portionSizeGrams}g)');
    }
  }

  // Fast Food
  final fastFood = [
    'pizza-margherita',
    'hamburger',
    'big-mac',
    'doner-tavuk',
    'lahmacun',
    'patates-kizartmasi',
  ];

  print('\n🍔 Fast Food:');
  for (final id in fastFood) {
    final food = FoodDatabase.findById(id);
    if (food != null) {
      print('  ✅ ${food.name}: ${food.caloriesPer100g} kcal/100g');
    }
  }

  // Hamur işleri
  final pastries = [
    'peynirli-poaca',
    'sigara-boregi',
    'su-boregi',
    'kol-boregi',
  ];

  print('\n🥐 Hamur İşleri:');
  for (final id in pastries) {
    final food = FoodDatabase.findById(id);
    if (food != null) {
      print('  ✅ ${food.name}: ${food.caloriesPer100g} kcal/100g');
    }
  }

  // Arama testi
  print('\n🔍 Arama Testi ("çikolata"):');
  final results = FoodDatabase.search('çikolata');
  for (final food in results.take(5)) {
    print('  - ${food.name}: ${food.caloriesPer100g} kcal');
  }

  print('\n✅ Tüm yemekler başarıyla yüklendi!');
}
