import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _currentVersion = '1.1.1';
const String _appStoreId = '6762379939';
const String _appStoreUrl =
    'https://apps.apple.com/app/pusulafit/id$_appStoreId';

// SharedPreferences keys
const String _keyLastCheckedDate = 'update_last_checked_date';
const String _keyDismissedVersion = 'update_dismissed_version';

class UpdateCheckerService {
  /// Uygulama açıldığında çağır.
  ///
  /// - API'ye günde en fazla 1 kez istek atar
  /// - Kullanıcı "Sonra" dediyse o sürüm için bir daha göstermez
  /// - Daha yeni bir sürüm çıkarsa tekrar gösterir
  static Future<void> checkAndPrompt(BuildContext context) async {
    if (!Platform.isIOS) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Günde 1 kez API çağrısı yap
      final lastChecked = prefs.getString(_keyLastCheckedDate);
      final today = DateTime.now().toIso8601String().substring(0, 10); // 'yyyy-MM-dd'
      if (lastChecked == today) return;

      final storeVersion = await _fetchStoreVersion();
      if (storeVersion == null) return;

      await prefs.setString(_keyLastCheckedDate, today);

      // Yeni sürüm yok
      if (!_isNewerVersion(storeVersion, _currentVersion)) return;

      // Bu sürüm için kullanıcı zaten "Sonra" dedi
      final dismissed = prefs.getString(_keyDismissedVersion);
      if (dismissed == storeVersion) return;

      if (context.mounted) {
        final didUpdate = await _showUpdateDialog(context, storeVersion);
        if (!didUpdate) {
          // "Sonra" seçildi — bu sürümü hatırla, tekrar gösterme
          await prefs.setString(_keyDismissedVersion, storeVersion);
        }
      }
    } catch (_) {
      // Ağ hatası vs. — sessizce geç
    }
  }

  static Future<String?> _fetchStoreVersion() async {
    final uri = Uri.parse(
        'https://itunes.apple.com/lookup?id=$_appStoreId&country=tr');
    final response =
        await http.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    return results.first['version'] as String?;
  }

  /// true → kullanıcı "Güncelle"ye bastı, false → "Sonra"
  static Future<bool> _showUpdateDialog(
      BuildContext context, String storeVersion) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🚀', style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              'Yeni Sürüm Var!',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'PusulaFit $storeVersion sürümü çıktı!\n\n'
          'Yeni özellikler ve iyileştirmeler için hemen güncelleyin.',
          style: const TextStyle(color: Color(0xFFB0B0C0), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Sonra',
              style: TextStyle(color: Color(0xFF888899)),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD89A6A),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop(true);
              final uri = Uri.parse(_appStoreUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text(
              'Güncelle',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static bool _isNewerVersion(String storeVersion, String currentVersion) {
    final store = _parseParts(storeVersion);
    final current = _parseParts(currentVersion);
    for (int i = 0; i < 3; i++) {
      final s = i < store.length ? store[i] : 0;
      final c = i < current.length ? current[i] : 0;
      if (s > c) return true;
      if (s < c) return false;
    }
    return false;
  }

  static List<int> _parseParts(String version) => version
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
