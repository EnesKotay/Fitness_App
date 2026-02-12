import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../../core/utils/storage_helper.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/food_entry.dart';
import '../../domain/entities/food_item.dart';

/// Yerel diyet verisi (profil, günlük kayıtlar, özel yemekler). Her kullanıcı (userId) kendi box'ında saklanır;
/// hesap değişince başka kullanıcının verisi yüklenir.
class HiveDietStorage {
  static const String _profileKey = 'profile';
  static const String _entriesListKey = 'entries';
  static const String _customFoodsListKey = 'list';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(GenderAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(ActivityLevelAdapter());
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(GoalAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(UserProfileAdapter());
  }

  // Box adları getter; cache yok. closeBoxesForSuffix sonrası bir sonraki erişimde _suffix yeni kullanıcıyı verir, yeni box açılır.
  static String get _suffix => StorageHelper.getUserStorageSuffix();
  static String get _profileBox => 'diet_profile_$_suffix';
  static String get _entriesBox => 'diet_entries_$_suffix';
  static String get _customFoodsBox => 'diet_custom_foods_$_suffix';
  static String get _remoteCacheBox => 'diet_remote_food_cache_$_suffix';

  /// Hesap değişince eski kullanıcının açık box'larını kapat; yeni userId ile tekrar açılacak.
  static Future<void> closeBoxesForSuffix(String suffix) async {
    final names = [
      'diet_profile_$suffix',
      'diet_entries_$suffix',
      'diet_custom_foods_$suffix',
      'diet_remote_food_cache_$suffix',
    ];
    for (final name in names) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).close();
          debugPrint('HiveDietStorage: closed box $name');
        }
      } catch (e) {
        debugPrint('HiveDietStorage.closeBoxesForSuffix: $name $e');
      }
    }
  }

  /// Aktif kullanıcı suffix'i (debug / login-logout akışında hangi box'ların kapatılacağı için).
  static String getCurrentSuffix() => StorageHelper.getUserStorageSuffix();

  Future<UserProfile?> getProfile() async {
    try {
      if (!Hive.isBoxOpen(_profileBox)) {
        await Hive.openBox(_profileBox);
        debugPrint('HiveDietStorage.getProfile: opened box $_profileBox');
      }
      final box = Hive.box(_profileBox);
      var profile = box.get(_profileKey);
      if (profile is UserProfile) return profile;
      final uid = StorageHelper.getUserId();
      final emailSafe = StorageHelper.getUserStorageSuffix();
      // Eski format: userId_email (örn. 5_ahmet_gmail_com) -> yeni format email (ahmet_gmail_com) taşıma
      if (uid != null && !emailSafe.startsWith('user_') && emailSafe != 'guest') {
        final oldBoxName = 'diet_profile_${uid}_$emailSafe';
        if (oldBoxName != _profileBox) {
          try {
            if (!Hive.isBoxOpen(oldBoxName)) await Hive.openBox(oldBoxName);
            final oldBox = Hive.box(oldBoxName);
            profile = oldBox.get(_profileKey);
            if (profile is UserProfile) {
              await box.put(_profileKey, profile);
              return profile;
            }
          } catch (_) {}
        }
      }
      // Eski format: sadece userId
      if (uid != null) {
        final oldBoxName = 'diet_profile_$uid';
        try {
          if (!Hive.isBoxOpen(oldBoxName)) await Hive.openBox(oldBoxName);
          final oldBox = Hive.box(oldBoxName);
          profile = oldBox.get(_profileKey);
          if (profile is UserProfile) {
            await box.put(_profileKey, profile);
            return profile;
          }
        } catch (_) {}
      }
      return null;
    } catch (e) {
      debugPrint('HiveDietStorage.getProfile hatası: $e');
      return null;
    }
  }

  Future<void> saveProfile(UserProfile profile) async {
    try {
      if (!Hive.isBoxOpen(_profileBox)) await Hive.openBox(_profileBox);
      final box = Hive.box(_profileBox);
      await box.put(_profileKey, profile);
      debugPrint('HiveDietStorage.saveProfile: box=$_profileBox name=${profile.name}');
    } catch (e) {
      debugPrint('HiveDietStorage.saveProfile hatası: $e');
      rethrow;
    }
  }

  Future<List<FoodEntry>> getAllEntries() async {
    try {
      if (!Hive.isBoxOpen(_entriesBox)) await Hive.openBox(_entriesBox);
      final box = Hive.box(_entriesBox);
      var list = box.get(_entriesListKey) as List?;
      final uid = StorageHelper.getUserId();
      final emailSafe = StorageHelper.getUserStorageSuffix();
      if (list == null || list.isEmpty) {
        if (uid != null && !emailSafe.startsWith('user_') && emailSafe != 'guest') {
          final oldBoxName = 'diet_entries_${uid}_$emailSafe';
          if (oldBoxName != _entriesBox) {
            try {
              if (!Hive.isBoxOpen(oldBoxName)) await Hive.openBox(oldBoxName);
              list = Hive.box(oldBoxName).get(_entriesListKey) as List?;
              if (list != null && list.isNotEmpty) await box.put(_entriesListKey, list);
            } catch (_) {}
          }
        }
        if ((list == null || list.isEmpty) && uid != null) {
          try {
            final oldBoxName = 'diet_entries_$uid';
            if (!Hive.isBoxOpen(oldBoxName)) await Hive.openBox(oldBoxName);
            list = Hive.box(oldBoxName).get(_entriesListKey) as List?;
            if (list != null && list.isNotEmpty) await box.put(_entriesListKey, list);
          } catch (_) {}
        }
      }
      if (list == null) return [];
      final entries = <FoodEntry>[];
      for (final e in list) {
        try {
          if (e is Map) {
            entries.add(FoodEntry.fromJson(Map<String, dynamic>.from(e)));
          }
        } catch (_) {
          continue;
        }
      }
      return entries;
    } catch (e) {
      debugPrint('HiveDietStorage.getAllEntries hatası: $e');
      return [];
    }
  }

  Future<void> saveAllEntries(List<FoodEntry> entries) async {
    try {
      if (!Hive.isBoxOpen(_entriesBox)) await Hive.openBox(_entriesBox);
      final box = Hive.box(_entriesBox);
      await box.put(_entriesListKey, entries.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('HiveDietStorage.saveAllEntries hatası: $e');
      rethrow;
    }
  }

  Future<List<String>> getRecentFoodIds(int limit) async {
    try {
      if (!Hive.isBoxOpen(_entriesBox)) await Hive.openBox(_entriesBox);
      final box = Hive.box(_entriesBox);
      final list = box.get(_entriesListKey) as List?;
      if (list == null || list.isEmpty) return [];

      // Ters sırayla (sondan başa) tarayarak unique foodId'leri bul
      final recentIds = <String>{};
      final result = <String>[];
      
      for (int i = list.length - 1; i >= 0; i--) {
        final e = list[i];
        if (e is Map) {
          final foodId = e['foodId'] as String?;
          if (foodId != null && !recentIds.contains(foodId)) {
            recentIds.add(foodId);
            result.add(foodId);
            if (result.length >= limit) break;
          }
        }
      }
      return result;
    } catch (e) {
      debugPrint('HiveDietStorage.getRecentFoodIds hatası: $e');
      return [];
    }
  }

  Future<List<String>> getFrequentFoodIds(int limit) async {
    try {
      if (!Hive.isBoxOpen(_entriesBox)) await Hive.openBox(_entriesBox);
      final box = Hive.box(_entriesBox);
      final list = box.get(_entriesListKey) as List?;
      if (list == null || list.isEmpty) return [];

      // foodId bazlı kullanım sayılarını hesapla
      final counts = <String, int>{};
      for (final e in list) {
        if (e is Map) {
          final foodId = e['foodId'] as String?;
          if (foodId != null) {
            counts[foodId] = (counts[foodId] ?? 0) + 1;
          }
        }
      }

      // En çok kullanılanları sırala
      final sortedIds = counts.keys.toList()
        ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

      return sortedIds.take(limit).toList();
    } catch (e) {
      debugPrint('HiveDietStorage.getFrequentFoodIds hatası: $e');
      return [];
    }
  }
  Future<List<FoodItem>> getCustomFoods() async {
    try {
      if (!Hive.isBoxOpen(_customFoodsBox)) await Hive.openBox(_customFoodsBox);
      final box = Hive.box(_customFoodsBox);
      final list = box.get(_customFoodsListKey) as List?;
      if (list == null) return [];
      final items = <FoodItem>[];
      for (final e in list) {
        try {
          if (e is Map) {
            items.add(FoodItem.fromJson(Map<String, dynamic>.from(e)));
          }
        } catch (_) {
          continue;
        }
      }
      return items;
    } catch (e) {
      debugPrint('HiveDietStorage.getCustomFoods hatası: $e');
      return [];
    }
  }

  Future<void> addCustomFood(FoodItem food) async {
    try {
      if (!Hive.isBoxOpen(_customFoodsBox)) await Hive.openBox(_customFoodsBox);
      final box = Hive.box(_customFoodsBox);
      final list = box.get(_customFoodsListKey) as List? ?? [];
      final items = <FoodItem>[];
      for (final e in list) {
        try {
          if (e is Map) {
            items.add(FoodItem.fromJson(Map<String, dynamic>.from(e)));
          }
        } catch (_) {
          continue;
        }
      }
      items.add(food);
      await box.put(_customFoodsListKey, items.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('HiveDietStorage.addCustomFood hatası: $e');
      rethrow;
    }
  }

  // --- Remote (Open Food Facts) sonuç önbelleği: query -> sonuç listesi ---
  Future<List<FoodItem>?> getRemoteCached(String query) async {
    if (query.trim().isEmpty) return null;
    try {
      if (!Hive.isBoxOpen(_remoteCacheBox)) await Hive.openBox(_remoteCacheBox);
      final box = Hive.box(_remoteCacheBox);
      final key = 'q_${query.trim().toLowerCase()}';
      final list = box.get(key) as List?;
      if (list == null) return null;
      final items = <FoodItem>[];
      for (final e in list) {
        try {
          if (e is Map) {
            items.add(FoodItem.fromJson(Map<String, dynamic>.from(e)));
          }
        } catch (_) {
          continue;
        }
      }
      return items.isEmpty ? null : items;
    } catch (e) {
      debugPrint('HiveDietStorage.getRemoteCached hatası: $e');
      return null;
    }
  }

  Future<void> saveRemoteCache(String query, List<FoodItem> items) async {
    if (query.trim().isEmpty) return;
    try {
      if (!Hive.isBoxOpen(_remoteCacheBox)) await Hive.openBox(_remoteCacheBox);
      final box = Hive.box(_remoteCacheBox);
      final key = 'q_${query.trim().toLowerCase()}';
      await box.put(key, items.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('HiveDietStorage.saveRemoteCache hatası: $e');
    }
  }

  /// Barkod ile tek ürün cache (key: barcode).
  Future<FoodItem?> getRemoteCachedByBarcode(String barcode) async {
    try {
      if (!Hive.isBoxOpen(_remoteCacheBox)) await Hive.openBox(_remoteCacheBox);
      final box = Hive.box(_remoteCacheBox);
      final key = 'b_$barcode';
      final map = box.get(key) as Map?;
      if (map == null) return null;
      return FoodItem.fromJson(Map<String, dynamic>.from(map));
    } catch (e) {
      debugPrint('HiveDietStorage.getRemoteCachedByBarcode hatası: $e');
      return null;
    }
  }

  Future<void> saveRemoteCacheByBarcode(String barcode, FoodItem item) async {
    try {
      if (!Hive.isBoxOpen(_remoteCacheBox)) await Hive.openBox(_remoteCacheBox);
      final box = Hive.box(_remoteCacheBox);
      await box.put('b_$barcode', item.toJson());
    } catch (e) {
      debugPrint('HiveDietStorage.saveRemoteCacheByBarcode hatası: $e');
    }
  }
}
