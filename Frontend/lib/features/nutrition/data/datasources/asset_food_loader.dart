import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/food_item.dart';

/// Local yiyecek listesini assets/foods/foods_tr.json dosyasından yükler.
class AssetFoodLoader {
  static const String _path = 'assets/foods/foods_tr.json';
  static const String _synonymsPath = 'assets/foods/synonyms_tr.json';
  static const String _coreFoodsPath = 'assets/foods/core_foods_tr.json';
  static const String _verifiedExtrasPath = 'assets/foods/verified_tr_extras.json';

  /// JSON asset'ini okuyup [FoodItem] listesine dönüştürür.
  /// Schema v1 (List) ve Schema v2 (Map -> foods) destekler.
  static Future<List<FoodItem>> loadFoods() async {
    try {
      final String raw = await rootBundle.loadString(_path);
      final dynamic decoded = jsonDecode(raw);
      
      List<dynamic> list;
      if (decoded is List) {
        // v1: Direkt liste
        list = decoded;
      } else if (decoded is Map && decoded['foods'] is List) {
        // v2: "foods" alanı altında liste
        list = decoded['foods'];
      } else {
        return [];
      }

      final verifiedExtras = await _loadVerifiedExtras();
      if (verifiedExtras.isNotEmpty) {
        list = [...list, ...verifiedExtras];
      }

      final coreFoodMap = await _loadCoreFoodMetadata();
      final items = <FoodItem>[];
      for (final e in list) {
        try {
          if (e is Map) {
            final item = FoodItem.fromJson(Map<String, dynamic>.from(e));
            items.add(_mergeCoreFoodMetadata(item, coreFoodMap[item.name]));
          }
        } catch (_) {
          continue;
        }
      }
      return items;
    } catch (e) {
      debugPrint('AssetFoodLoader.loadFoods hatası: $e');
      return [];
    }
  }

  /// Eş anlamlı kelimeler haritasını yükler.
  static Future<Map<String, List<String>>> loadSynonyms() async {
    try {
      final String raw = await rootBundle.loadString(_synonymsPath);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final Map<String, dynamic> map = Map<String, dynamic>.from(decoded);
      final result = <String, List<String>>{};
      
      map.forEach((key, value) {
        if (value is List) {
          result[key] = value.map((e) => e.toString()).toList();
        }
      });
      return result;
    } catch (e) {
      debugPrint('AssetFoodLoader.loadSynonyms hatası: $e');
      return {};
    }
  }

  static Future<List<dynamic>> _loadVerifiedExtras() async {
    try {
      final String raw = await rootBundle.loadString(_verifiedExtrasPath);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['foods'] is List) {
        return decoded['foods'] as List<dynamic>;
      }
      return const [];
    } catch (e) {
      debugPrint('AssetFoodLoader._loadVerifiedExtras hatası: $e');
      return const [];
    }
  }

  static Future<Map<String, Map<String, dynamic>>> _loadCoreFoodMetadata() async {
    try {
      final String raw = await rootBundle.loadString(_coreFoodsPath);
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['coreFoods'] is! List) return {};

      final result = <String, Map<String, dynamic>>{};
      for (final item in decoded['coreFoods'] as List<dynamic>) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final matchName = map['matchName']?.toString().trim();
        if (matchName == null || matchName.isEmpty) continue;
        result[matchName] = map;
      }
      return result;
    } catch (e) {
      debugPrint('AssetFoodLoader._loadCoreFoodMetadata hatası: $e');
      return {};
    }
  }

  static FoodItem _mergeCoreFoodMetadata(
    FoodItem item,
    Map<String, dynamic>? metadata,
  ) {
    if (metadata == null) return item;

    final displayName =
        (metadata['displayName'] as String?)?.trim().isNotEmpty == true
            ? metadata['displayName'] as String
            : item.name;
    final category =
        (metadata['category'] as String?)?.trim().isNotEmpty == true
            ? metadata['category'] as String
            : item.category;

    final aliases = <String>{
      ...item.aliases,
      if (displayName != item.name) item.name,
      ...((metadata['aliases'] as List?) ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
    }.toList()
      ..sort();

    final tags = <String>{
      ...item.tags,
      'tr-core',
      ...((metadata['tags'] as List?) ?? [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty),
    }.toList()
      ..sort();

    return FoodItem(
      id: item.id,
      name: displayName,
      category: category,
      basis: item.basis,
      nutrients: item.nutrients,
      servings: item.servings,
      aliases: aliases,
      tags: tags,
      brand: item.brand,
      barcode: item.barcode,
      imageUrl: item.imageUrl,
    );
  }
}
