import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/food_item.dart';

/// Local yiyecek listesini assets/foods/foods_tr.json dosyasından yükler.
class AssetFoodLoader {
  static const String _path = 'assets/foods/foods_tr.json';

  static const String _synonymsPath = 'assets/foods/synonyms_tr.json';

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

      final items = <FoodItem>[];
      for (final e in list) {
        try {
          if (e is Map) {
            final item = FoodItem.fromJson(Map<String, dynamic>.from(e));
            items.add(item);
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
}
