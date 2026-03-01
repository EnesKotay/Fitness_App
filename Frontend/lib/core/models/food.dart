/// Besin veritabanı modeli - 100g başına besin değerleri
class Food {
  final String id;
  final String name;
  final int caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  /// 1 porsiyon = kaç gram (varsayılan 100g)
  final int portionSizeGrams;

  const Food({
    required this.id,
    required this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.portionSizeGrams = 100,
  });

  /// Gram cinsinden toplam kalori hesapla
  int calculateCalories(int totalGrams) {
    if (totalGrams <= 0) return 0;
    return ((caloriesPer100g * totalGrams) / 100).round();
  }

  /// Gram cinsinden protein hesapla
  double calculateProtein(int totalGrams) {
    if (totalGrams <= 0) return 0;
    return (proteinPer100g * totalGrams) / 100;
  }

  /// Gram cinsinden karbonhidrat hesapla
  double calculateCarbs(int totalGrams) {
    if (totalGrams <= 0) return 0;
    return (carbsPer100g * totalGrams) / 100;
  }

  /// Gram cinsinden yağ hesapla
  double calculateFat(int totalGrams) {
    if (totalGrams <= 0) return 0;
    return (fatPer100g * totalGrams) / 100;
  }

  /// Porsiyon sayısından toplam gram hesapla
  int portionToGrams(double portions) {
    return (portions * portionSizeGrams).round();
  }
}
