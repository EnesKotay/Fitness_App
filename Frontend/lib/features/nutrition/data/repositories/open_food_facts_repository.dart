import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/repositories/remote_food_repository.dart';
import '../datasources/hive_diet_storage.dart';

/// Open Food Facts API ile uzaktan yiyecek araması. Sonuçlar Hive'da cache'lenir.
class OpenFoodFactsRepository implements RemoteFoodRepository {
  static const String _searchUrl = 'https://world.openfoodfacts.org/cgi/search.pl';
  static const String _productUrl = 'https://world.openfoodfacts.net/api/v2/product';
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));
  final HiveDietStorage _hive = HiveDietStorage();

  @override
  Future<List<FoodItem>> searchRemoteFoods(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final cached = await _hive.getRemoteCached(q);
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final response = await _dio.get(
        _searchUrl,
        queryParameters: {
          'search_terms': q,
          'page_size': 80,
          'page': 1,
          'json': 1,
        },
      );
      final data = response.data as Map<String, dynamic>?;
      final products = data?['products'] as List<dynamic>? ?? [];
      final items = <FoodItem>[];
      for (final e in products) {
        try {
          if (e is Map) {
            final item = _productToFoodItem(Map<String, dynamic>.from(e));
            if (item != null) items.add(item);
          }
        } catch (_) {
          continue;
        }
      }
      if (items.isNotEmpty) {
        try {
          await _hive.saveRemoteCache(q, items);
        } catch (_) {
          // Cache hatası önemli değil, sonuçları döndür
        }
      }
      return items;
    } catch (e) {
      debugPrint('OpenFoodFactsRepository.searchRemoteFoods hatası: $e');
      return [];
    }
  }

  @override
  Future<FoodItem?> getByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final cached = await _hive.getRemoteCachedByBarcode(code);
    if (cached != null) return cached;

    try {
      final response = await _dio.get('$_productUrl/$code');
      final data = response.data as Map<String, dynamic>?;
      final product = data?['product'] as Map<String, dynamic>?;
      if (product == null) return null;
      final item = _productToFoodItem(product);
      if (item != null) await _hive.saveRemoteCacheByBarcode(code, item);
      return item;
    } catch (_) {
      return null;
    }
  }

  static FoodItem? _productToFoodItem(Map<String, dynamic> p) {
    final code = p['code']?.toString();
    final name = p['product_name']?.toString()?.trim();
    if (code == null || code.isEmpty || name == null || name.isEmpty) return null;
    final nut = p['nutriments'] as Map<String, dynamic>? ?? {};
    num? kcal = nut['energy-kcal_100g'] ?? nut['energy_100g'];
    if (kcal == null && nut['energy-kcal_100g'] == null) {
      final kj = nut['energy-kj_100g'] ?? nut['energy_100g'];
      if (kj != null) kcal = (kj as num) / 4.184;
    }
    final protein = (nut['proteins_100g'] as num?)?.toDouble() ?? 0.0;
    final carb = (nut['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0;
    final fat = (nut['fat_100g'] as num?)?.toDouble() ?? 0.0;
    return FoodItem(
      id: 'off_$code',
      name: name,
      category: 'Diğer',
      basis: const FoodBasis(amount: 100, unit: 'g'),
      nutrients: Nutrients(
        kcal: kcal != null ? kcal.toDouble() : 0,
        protein: protein,
        carb: carb,
        fat: fat,
      ),
    );
  }
}
