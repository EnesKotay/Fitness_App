import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/storage_keys.dart';

class StorageHelper {
  static SharedPreferences? _prefs;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static String? _cachedToken;
  static int? _cachedUserId;
  static String? _cachedUserEmail;
  /// init() çağrılmadan getToken() kullanılmamalı; aksi halde null dönüp yanlışlıkla login'e atar.
  static bool _initialized = false;

  /// Uygulama açılışında main() içinde mutlaka await edilmeli. Bitmeden getToken()/getUserId() kullanılmamalı.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      _cachedToken = await _secureStorage.read(key: StorageKeys.authToken);
      // Eski sürümde SharedPreferences'ta kalan token'ı güvenli depolamaya taşı
      if (_cachedToken == null || _cachedToken!.isEmpty) {
        final oldToken = _prefs?.getString(StorageKeys.authToken);
        if (oldToken != null && oldToken.isNotEmpty) {
          await _secureStorage.write(key: StorageKeys.authToken, value: oldToken);
          await _prefs?.remove(StorageKeys.authToken);
          _cachedToken = oldToken;
        }
      }
    } catch (_) {
      _cachedToken = null;
    }
    _cachedUserId = _prefs?.getInt(StorageKeys.userId);
    _cachedUserEmail = _prefs?.getString(StorageKeys.userEmail);
    _initialized = true;
  }

  // Token: güvenli depolama (Keychain / Keystore). Senkron erişim için bellekte cache.
  static Future<bool> saveToken(String token) async {
    try {
      await _secureStorage.write(key: StorageKeys.authToken, value: token);
      _cachedToken = token;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// init() çağrılmadan kullanılırsa null döner (yanlışlıkla login'e atanmasın diye).
  static String? getToken() => _initialized ? _cachedToken : null;

  static Future<bool> removeToken() async {
    try {
      await _secureStorage.delete(key: StorageKeys.authToken);
      _cachedToken = null;
      return true;
    } catch (_) {
      _cachedToken = null;
      return false;
    }
  }

  // User işlemleri (token gibi cache'lenir; hesap değişiminde tutarlı okuma için)
  static Future<bool> saveUserId(int userId) async {
    if (_prefs == null) return false;
    try {
      final ok = await _prefs!.setInt(StorageKeys.userId, userId);
      if (ok) _cachedUserId = userId;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static int? getUserId() => _cachedUserId;

  static Future<void> removeUserId() async {
    await _prefs?.remove(StorageKeys.userId);
    _cachedUserId = null;
  }

  /// Hesap bazlı benzersiz suffix: önce email (girişte yazılan), yoksa user_$id veya guest.
  /// Farklı emailler her zaman farklı kutu kullanır; backend aynı userId dönse bile karışmaz.
  static String getUserStorageSuffix() {
    final email = _safeEmail(getUserEmail());
    if (email.isNotEmpty) return email;
    final id = getUserId();
    if (id != null) return 'user_$id';
    return 'guest';
  }

  static String _safeEmail(String? e) {
    if (e == null || e.trim().isEmpty) return '';
    return e.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Kullanıcıya özel pref key (her hesap kendi verisini görsün).
  static String _userKey(String base) => '${base}_${getUserStorageSuffix()}';

  static Future<bool> saveUserEmail(String email) async {
    if (_prefs == null) return false;
    try {
      final ok = await _prefs!.setString(StorageKeys.userEmail, email);
      if (ok) _cachedUserEmail = email;
      return ok;
    } catch (_) {
      return false;
    }
  }

  static String? getUserEmail() => _cachedUserEmail;

  static Future<void> removeUserEmail() async {
    await _prefs?.remove(StorageKeys.userEmail);
    _cachedUserEmail = null;
  }

  static Future<bool> saveUserName(String name) async {
    if (_prefs == null) return false;
    try {
      return await _prefs!.setString(StorageKeys.userName, name);
    } catch (_) {
      return false;
    }
  }

  // Hedef kilo (Takip ekranı için) - kullanıcıya göre ayrı
  static Future<bool> saveTargetWeight(double weight) async {
    return await _prefs?.setDouble(_userKey(StorageKeys.targetWeight), weight) ?? false;
  }
  static double? getTargetWeight() => _prefs?.getDouble(_userKey(StorageKeys.targetWeight));

  // Hedef kalori (Beslenme ekranı için) - kullanıcıya göre ayrı
  static Future<bool> saveTargetCalories(int calories) async {
    return await _prefs?.setInt(_userKey(StorageKeys.targetCalories), calories) ?? false;
  }
  static int? getTargetCalories() => _prefs?.getInt(_userKey(StorageKeys.targetCalories));

  // Hedef makrolar - kullanıcıya göre ayrı
  static Future<bool> saveTargetProtein(double g) async {
    return await _prefs?.setDouble(_userKey(StorageKeys.targetProtein), g) ?? false;
  }
  static double? getTargetProtein() => _prefs?.getDouble(_userKey(StorageKeys.targetProtein));
  static Future<bool> saveTargetCarbs(double g) async {
    return await _prefs?.setDouble(_userKey(StorageKeys.targetCarbs), g) ?? false;
  }
  static double? getTargetCarbs() => _prefs?.getDouble(_userKey(StorageKeys.targetCarbs));
  static Future<bool> saveTargetFat(double g) async {
    return await _prefs?.setDouble(_userKey(StorageKeys.targetFat), g) ?? false;
  }
  static double? getTargetFat() => _prefs?.getDouble(_userKey(StorageKeys.targetFat));

  // Favori besinler - kullanıcıya göre ayrı
  static Future<bool> saveFavoriteFoodIds(List<String> ids) async {
    return await _prefs?.setStringList(_userKey(StorageKeys.favoriteFoodIds), ids) ?? false;
  }
  static List<String> getFavoriteFoodIds() {
    try {
      return _prefs?.getStringList(_userKey(StorageKeys.favoriteFoodIds)) ?? [];
    } catch (_) {
      return [];
    }
  }
  static Future<bool> toggleFavorite(String foodId) async {
    final ids = getFavoriteFoodIds();
    if (ids.contains(foodId)) {
      ids.remove(foodId);
    } else {
      ids.add(foodId);
    }
    return saveFavoriteFoodIds(ids);
  }
  static bool isFavorite(String foodId) => getFavoriteFoodIds().contains(foodId);

  // Son yenenler - kullanıcıya göre ayrı
  static Future<bool> addRecentFoodEntry(String foodId, int grams, String mealType) async {
    final entries = getRecentFoodEntries();
    entries.insert(0, {'foodId': foodId, 'grams': grams, 'mealType': mealType});
    if (entries.length > 15) entries.removeLast();
    final jsonList = entries.map((e) => '${e['foodId']}|${e['grams']}|${e['mealType']}').toList();
    return await _prefs?.setStringList(_userKey(StorageKeys.recentFoodEntries), jsonList) ?? false;
  }
  static List<Map<String, dynamic>> getRecentFoodEntries() {
    try {
      final list = _prefs?.getStringList(_userKey(StorageKeys.recentFoodEntries)) ?? [];
      return list.map((s) {
        if (s.isEmpty) return <String, dynamic>{'foodId': '', 'grams': 0, 'mealType': 'SNACK'};
        final parts = s.split('|');
        return <String, dynamic>{
          'foodId': parts.isNotEmpty ? parts[0] : '',
          'grams': int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
          'mealType': parts.length > 2 ? parts[2] : 'SNACK',
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // Su takibi - kullanıcıya göre ayrı
  static Future<bool> saveWaterGoalML(int ml) async {
    return await _prefs?.setInt(_userKey(StorageKeys.waterGoalML), ml) ?? false;
  }
  static int getWaterGoalML() => _prefs?.getInt(_userKey(StorageKeys.waterGoalML)) ?? 2000;
  static Future<bool> saveWaterForDate(String dateKey, int ml) async {
    return await _prefs?.setInt(_userKey('${StorageKeys.waterEntriesPrefix}$dateKey'), ml) ?? false;
  }
  static int getWaterForDate(String dateKey) => _prefs?.getInt(_userKey('${StorageKeys.waterEntriesPrefix}$dateKey')) ?? 0;

  // Beni hatırla - son giriş yapılan email
  static Future<bool> saveRememberedEmail(String email) async {
    return await _prefs?.setString(StorageKeys.rememberedEmail, email) ?? false;
  }

  static String? getRememberedEmail() {
    return _prefs?.getString(StorageKeys.rememberedEmail);
  }

  static Future<bool> clearRememberedEmail() async {
    return await _prefs?.remove(StorageKeys.rememberedEmail) ?? false;
  }

  static String? getUserName() {
    return _prefs?.getString(StorageKeys.userName);
  }

  /// Sadece oturum bilgilerini temizler (çıkış yapınca). Cache sıfırlanır; guest suffix kullanılır.
  static Future<bool> clearUserData() async {
    if (_prefs == null) return false;
    await removeToken();
    await _prefs!.remove(StorageKeys.userId);
    await _prefs!.remove(StorageKeys.userEmail);
    await _prefs!.remove(StorageKeys.userName);
    _cachedUserId = null;
    _cachedUserEmail = null;
    return true;
  }
}
