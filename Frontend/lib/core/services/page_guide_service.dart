import 'package:shared_preferences/shared_preferences.dart';

class PageGuideService {
  static const String _prefix = 'guide_seen_';

  static Future<bool> hasSeenGuide(String pageKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_prefix$pageKey') ?? false;
  }

  static Future<void> markGuideSeen(String pageKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix$pageKey', true);
  }

  static Future<void> resetAllGuides() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
