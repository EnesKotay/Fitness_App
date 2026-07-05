import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const String _appStoreId = '6762379939';
const String _playStorePackage = 'com.pusulafit.tracker';

const String _appStoreUrl =
    'https://apps.apple.com/app/pusulafit/id$_appStoreId';
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
        final didUpdate = await _showUpdateDialog(
          context,
          currentVersion: currentVersion,
          storeVersion: storeVersion,
        );
        if (!didUpdate) {
          final snoozeUntil = DateTime.now().add(
            const Duration(days: _snoozeDays),
          );
          await prefs.setString(
            _keySnoozedUntil,
            snoozeUntil.toIso8601String().substring(0, 10),
          );
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
      'https://itunes.apple.com/lookup?id=$_appStoreId&country=tr',
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) return null;
    return results.first['version'] as String?;
  }

  static Future<String?> _fetchPlayStoreVersion() async {
    try {
      final uri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_playStorePackage&hl=tr',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;
      final match = RegExp(
        r'\[\[\["(\d+\.\d+(?:\.\d+)?)"\]\]',
      ).firstMatch(response.body);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String storeVersion,
  }) async {
    final storeUrl = Platform.isIOS ? _appStoreUrl : _playStoreUrl;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF151A20),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF43A047).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF43A047).withValues(alpha: 0.30),
                  ),
                ),
                child: const Icon(
                  Icons.system_update_rounded,
                  color: Color(0xFF69D07D),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Yeni güncelleme var',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PusulaFit’in yeni sürümü hazır. Otomatik güncelleme kapalıysa mağazadan elle güncellemen gerekir.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13.5,
                  height: 1.42,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.045),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _VersionLabel(
                        label: 'Mevcut',
                        value: currentVersion,
                        color: Colors.white54,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white.withValues(alpha: 0.32),
                      size: 18,
                    ),
                    Expanded(
                      child: _VersionLabel(
                        label: 'Yeni',
                        value: storeVersion,
                        color: const Color(0xFF69D07D),
                        alignEnd: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Daha Sonra',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () async {
                Navigator.of(ctx).pop(true);
                final uri = Uri.parse(storeUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Güncelle',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
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

class _VersionLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool alignEnd;

  const _VersionLabel({
    required this.label,
    required this.value,
    required this.color,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.38),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
