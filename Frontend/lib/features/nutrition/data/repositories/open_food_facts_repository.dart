import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/food_item.dart';
import '../../domain/repositories/remote_food_repository.dart';
import '../datasources/hive_diet_storage.dart';

/// Open Food Facts API ile uzaktan yiyecek araması. Sonuçlar Hive'da cache'lenir.
class OpenFoodFactsRepository implements RemoteFoodRepository {
  static const String _searchUrl =
      'https://world.openfoodfacts.org/cgi/search.pl';
  static const String _productUrl =
      'https://world.openfoodfacts.org/api/v2/product';
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: const {
        'Accept': 'application/json',
        'User-Agent': 'FitnessApp/1.0 (contact: support@fitness.app)',
      },
    ),
  );
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
  Future<FoodItem?> getFoodById(String id) async {
    final barcode = id.startsWith('off_') ? id.substring(4) : id;
    return getByBarcode(barcode);
  }

  @override
  Future<FoodItem?> getByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final cached = await _hive.getRemoteCachedByBarcode(code);
    if (cached != null &&
        !_looksSuspiciousProductName(cached.name, cached.brand)) {
      return cached;
    }

    try {
      final response = await _dio.get('$_productUrl/$code');
      final data = response.data as Map<String, dynamic>?;
      final status = data?['status'] as num?;
      if (status != null && status.toInt() == 0) {
        return null;
      }
      final product = data?['product'] as Map<String, dynamic>?;
      if (product == null) return null;
      final item = _productToFoodItem(product);
      if (item != null) await _hive.saveRemoteCacheByBarcode(code, item);
      return item;
    } catch (_) {
      return cached != null ? _sanitizeCachedItem(cached) : null;
    }
  }

  static FoodItem? _productToFoodItem(Map<String, dynamic> p) {
    final code = p['code']?.toString();
    final brand = p['brands']?.toString().split(',').first.trim();
    final name = _bestProductName(p, brand);
    if (code == null || code.isEmpty || name == null) {
      return null;
    }
    final nut = p['nutriments'] as Map<String, dynamic>? ?? {};
    final kcal = _kcalPer100g(nut);
    final protein = _asDouble(nut['proteins_100g']) ?? 0.0;
    final carb = _asDouble(nut['carbohydrates_100g']) ?? 0.0;
    final fat = _asDouble(nut['fat_100g']) ?? 0.0;
    return FoodItem(
      id: 'off_$code',
      name: name,
      category: 'Paketli Ürün (Etiket)',
      basis: const FoodBasis(amount: 100, unit: 'g'),
      nutrients: Nutrients(
        kcal: kcal ?? 0,
        protein: protein,
        carb: carb,
        fat: fat,
      ),
      tags: const ['verified-source', 'etiket-verisi', 'open-food-facts'],
      brand: brand != null && brand.isNotEmpty ? brand : null,
    );
  }

  static FoodItem _sanitizeCachedItem(FoodItem item) {
    if (!_looksSuspiciousProductName(item.name, item.brand)) return item;

    return FoodItem(
      id: item.id,
      name: _fallbackProductName(item.brand, item.category),
      category: item.category,
      basis: item.basis,
      nutrients: item.nutrients,
      servings: item.servings,
      aliases: item.aliases,
      tags: item.tags,
      brand: item.brand,
      barcode: item.barcode,
      imageUrl: item.imageUrl,
    );
  }

  static String? _bestProductName(Map<String, dynamic> p, String? brand) {
    final candidates = [
      p['product_name_tr'],
      p['generic_name_tr'],
      p['product_name_en'],
      p['generic_name_en'],
      p['product_name'],
      p['generic_name'],
      p['abbreviated_product_name'],
    ];

    for (final candidate in candidates) {
      final name = candidate?.toString().trim();
      if (name == null || name.isEmpty) continue;
      if (_looksSuspiciousProductName(name, brand)) continue;
      return _withBrandIfUseful(name, brand);
    }

    return _fallbackProductName(brand, p['categories']?.toString());
  }

  static String _withBrandIfUseful(String name, String? brand) {
    final cleanBrand = brand?.trim();
    if (cleanBrand == null || cleanBrand.isEmpty) return name;
    if (name.toLowerCase().contains(cleanBrand.toLowerCase())) return name;
    return '$cleanBrand $name';
  }

  static String _fallbackProductName(String? brand, String? category) {
    final cleanBrand = brand?.trim();
    final categoryLabel = _categoryLabel(category);
    if (cleanBrand != null && cleanBrand.isNotEmpty) {
      return '$cleanBrand $categoryLabel';
    }
    return categoryLabel;
  }

  static String _categoryLabel(String? category) {
    final normalized = category?.toLowerCase() ?? '';
    if (normalized.contains('crisps') ||
        normalized.contains('chips') ||
        normalized.contains('cips')) {
      return 'Cips';
    }
    if (normalized.contains('chocolate') || normalized.contains('çikolata')) {
      return 'Çikolata';
    }
    if (normalized.contains('biscuit') || normalized.contains('bisküvi')) {
      return 'Bisküvi';
    }
    if (normalized.contains('snack') || normalized.contains('atıştırmalık')) {
      return 'Atıştırmalık';
    }
    return 'Paketli Ürün';
  }

  static bool _looksSuspiciousProductName(String name, String? brand) {
    final normalized = name.trim().toLowerCase();
    if (normalized.length < 3) return true;
    if (normalized == 'unknown' ||
        normalized == 'undefined' ||
        normalized == 'bilinmeyen ürün') {
      return true;
    }

    final cleanBrand = brand?.trim().toLowerCase();
    if (cleanBrand != null &&
        cleanBrand.isNotEmpty &&
        normalized.contains(cleanBrand)) {
      return false;
    }
    if (_containsProductHint(normalized)) return false;

    final words = normalized
        .split(RegExp(r'\s+'))
        .where((word) => word.length > 1)
        .toList();
    final looksLikePersonName =
        words.length >= 2 &&
        words.length <= 3 &&
        words.every((word) => RegExp(r'^[a-zçğıöşü]+$').hasMatch(word));
    return looksLikePersonName;
  }

  static bool _containsProductHint(String value) {
    const hints = [
      'cips',
      'chips',
      'crisps',
      'patates',
      'mısır',
      'baharat',
      'peynir',
      'ketçap',
      'yoğurt',
      'süt',
      'çikolata',
      'bisküvi',
      'kraker',
      'gofret',
      'kuruyemiş',
      'fıstık',
      'fındık',
      'bar',
      'protein',
      'içecek',
      'meyve',
      'aromalı',
      'acılı',
      'sade',
      'tuzlu',
      'light',
    ];
    return hints.any(value.contains);
  }

  static double? _kcalPer100g(Map<String, dynamic> nutriments) {
    final explicitKcal = _asDouble(nutriments['energy-kcal_100g']);
    if (explicitKcal != null) return explicitKcal;

    final kj =
        _asDouble(nutriments['energy-kj_100g']) ??
        _asDouble(nutriments['energy_100g']);
    if (kj == null) return null;
    return kj / 4.184;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }
}
