import 'package:shared_preferences/shared_preferences.dart';

import '../utils/storage_helper.dart';

class PageGuideService {
  static const String _prefix = 'guide_seen_';

  static String _key(String pageKey) {
    return StorageHelper.userScopedKey('$_prefix$pageKey');
  }

  static Future<bool> hasSeenGuide(String pageKey) async {
    // Otomatik sayfa rehberleri güncelleme/yeniden girişlerde tekrar açılmasın.
    // İlk kayıt deneyimi uygulama turu üzerinden yürür; sayfa rehberleri manuel
    // rehber butonuyla her zaman açılabilir.
    if (StorageHelper.getUserEmail()?.trim().isNotEmpty == true) {
      return true;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(pageKey)) ?? false;
  }

  static Future<void> markGuideSeen(String pageKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(pageKey), true);
  }

  static Future<void> resetAllGuides() async {
    final prefs = await SharedPreferences.getInstance();
    final suffix = StorageHelper.getUserStorageSuffix();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith(_prefix) && key.endsWith('_$suffix'))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
