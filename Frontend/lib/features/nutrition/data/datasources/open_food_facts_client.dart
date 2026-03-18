import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/entities/food_item.dart';

class OpenFoodFactsClient {
  static const String _baseUrl = 'https://world.openfoodfacts.org/api/v0/product/';
  
  /// Barkoda göre ürünü arar
  Future<FoodItem?> searchByBarcode(String barcode) async {
    try {
       final response = await http.get(
        Uri.parse('$_baseUrl$barcode.json'),
        headers: {'User-Agent': 'FitnessApp - Android/iOS - Version 1.0'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          final nutrients = product['nutriments'] ?? {};
          
          final String name = product['product_name'] ?? product['product_name_tr'] ?? product['product_name_en'] ?? 'Bilinmeyen Ürün';
          final String brand = product['brands']?.split(',').first ?? '';
          
          // Besin değerleri (100g/ml için)
          final double energyKcal = (nutrients['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0;
          final double protein = (nutrients['proteins_100g'] as num?)?.toDouble() ?? 0.0;
          final double carbs = (nutrients['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0;
          final double fat = (nutrients['fat_100g'] as num?)?.toDouble() ?? 0.0;
          
          if (energyKcal == 0 && protein == 0 && carbs == 0 && fat == 0) {
              return null; // Yeterli besin bilgisi yok
          }
          
          return FoodItem(
            id: 'off_$barcode', // OpenFoodFacts prefix'i
            name: name,
            brand: brand.isNotEmpty ? brand : null,
            basis: const FoodBasis(amount: 100, unit: 'g'),
            nutrients: Nutrients(
              protein: protein,
              carb: carbs,
              fat: fat,
              kcal: energyKcal,
            ),
            category: 'Paketli Ürün (OFF)',
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
