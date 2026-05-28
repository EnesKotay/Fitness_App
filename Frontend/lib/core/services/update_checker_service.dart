import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _appStoreId = '6762379939';
const String _playStorePackage = 'com.pusulafit.tracker';

const String _appStoreUrl = 'https://apps.apple.com/app/pusulafit/id$_appStoreId';
const String _playStoreUrl =
    'https://play.google.com/store/apps/details?id=$_playStorePackage';

const String _keyLastCheckedDate = 'update_last_checked_date';
const String _keySnoozedUntil = 'update_snoozed_until';
const int _snoozeDays = 3;

class UpdateCheckerService {
  /// Uygulama açıldığında çağır.
  ///
  /// - Günde en fazla 1 kez API isteği atar
  /// - "3 Gün Sonra" seçilirse o kadar süre dialog göstermez
  /// - Yeni sürümde snooze sıfırlanır
  static Future<void> checkAndPrompt(BuildContext context) async {
    if (!Platform.isIOS && !Platform.isAndroid) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Günde 1 kez kontrol et
      final lastChecked = prefs.getString(_keyLastCheckedDate);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      if (lastChecked == today) return;

      // Snooze aktif mi?
      final snoozedUntil = prefs.getString(_keySnoozedUntil);
      if (snoozedUntil != null) {
        final snoozeDate = DateTime.tryParse(snoozedUntil);
        if (snoozeDate != null && DateTime.now().isBefore(snoozeDate)) return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final storeVersion = Platform.isIOS
          ? await _fetchAppStoreVersion()
          : await _fetchPlayStoreVersion();
      if (storeVersion == null) return;

      await prefs.setString(_keyLastCheckedDate, today);

      if (!_isNewerVersion(storeVersion, currentVersion)) return;

      if (context.mounted) {
        final didUpdate = await _showUpdateDialog(context, storeVersion);
        if (!didUpdate) {
          final snoozeUntil =
              DateTime.now().add(const Duration(days: _snoozeDays));
          await prefs.setString(
              _keySnoozedUntil, snoozeUntil.toIso8601String().substring(0, 10));
        } else {
          await prefs.remove(_keySnoozedUntil);
        }
      }
    } catch (_) {
      // Ağ hatası vs. — sessizce geç
    }
  }

  static Future<String?> _fetchAppStoreVersion() async {
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

  static Future<String?> _fetchPlayStoreVersion() async {
    try {
      final uri = Uri.parse(
          'https://play.google.com/store/apps/details?id=$_playStorePackage&hl=tr');
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'Mozilla/5.0'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final match =
          RegExp(r'\[\[\["(\d+\.\d+(?:\.\d+)?)"\]\]').firstMatch(response.body);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _showUpdateDialog(
      BuildContext context, String storeVersion) async {
    final storeUrl =
        Platform.isIOS ? _appStoreUrl : _playStoreUrl;

    final result = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Güncelleme var!'),
        content: const Text(
          'İyi haber! Uygulamanın yeni bir sürümü var.',
        ),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: false,
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Daha Sonra'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              Navigator.of(ctx).pop(true);
              final uri = Uri.parse(storeUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Güncelle'),
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
