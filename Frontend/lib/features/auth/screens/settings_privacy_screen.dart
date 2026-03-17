import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/auth_provider.dart';
import '../../../core/utils/storage_helper.dart';
import 'legal_screen.dart';

class SettingsPrivacyScreen extends StatefulWidget {
  const SettingsPrivacyScreen({super.key});

  @override
  State<SettingsPrivacyScreen> createState() => _SettingsPrivacyScreenState();
}

class _SettingsPrivacyScreenState extends State<SettingsPrivacyScreen> {
  bool _analytics = true;
  bool _personalization = true;
  bool _crashReports = true;
  bool _exporting = false;
  bool _processingDelete = false;

  @override
  void initState() {
    super.initState();
    _analytics = StorageHelper.getPrivacyAnalytics();
    _personalization = StorageHelper.getPrivacyPersonalization();
    _crashReports = StorageHelper.getPrivacyCrashReports();
  }

  Future<void> _save() async {
    await StorageHelper.savePrivacyAnalytics(_analytics);
    await StorageHelper.savePrivacyPersonalization(_personalization);
    await StorageHelper.savePrivacyCrashReports(_crashReports);
  }

  Map<String, dynamic> _buildExportPayload() {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    return <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'account': <String, dynamic>{
        'id': user?.id,
        'email': user?.email ?? StorageHelper.getUserEmail(),
        'name': user?.name ?? StorageHelper.getUserName(),
      },
      'preferences': <String, dynamic>{
        'notificationEnabled': StorageHelper.getNotifEnabled(),
        'notificationWater': StorageHelper.getNotifWater(),
        'notificationWorkout': StorageHelper.getNotifWorkout(),
        'notificationDailySummary': StorageHelper.getNotifDailySummary(),
        'privacyAnalytics': _analytics,
        'privacyPersonalization': _personalization,
        'privacyCrashReports': _crashReports,
      },
      'targets': <String, dynamic>{
        'targetWeight': StorageHelper.getTargetWeight(),
        'targetCalories': StorageHelper.getTargetCalories(),
        'targetProtein': StorageHelper.getTargetProtein(),
        'targetCarbs': StorageHelper.getTargetCarbs(),
        'targetFat': StorageHelper.getTargetFat(),
        'waterGoalML': StorageHelper.getWaterGoalML(),
      },
    };
  }

  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final payload = _buildExportPayload();
      final pretty = const JsonEncoder.withIndent('  ').convert(payload);
      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/fitness_privacy_export_$now.json');
      await file.writeAsString(pretty);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Fitness hesap verisi dışa aktarma',
        ),
      );
    } catch (_) {
      final fallback = const JsonEncoder.withIndent(
        '  ',
      ).convert(_buildExportPayload());
      await Clipboard.setData(ClipboardData(text: fallback));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dosya paylaşımı olmadı, veri panoya kopyalandı.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _deleteRequestFlow() async {
    if (_processingDelete) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silme Talebi'),
        content: const Text(
          'Bu işlem hesabını hemen silmez. Silme talebi metnini kopyalayıp destek ekibine iletebilirsin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Talep Metni Oluştur'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => _processingDelete = true);
    try {
      final message = StringBuffer()
        ..writeln('Konu: Hesap Silme Talebi')
        ..writeln('Tarih: ${DateTime.now().toIso8601String()}')
        ..writeln('Kullanıcı ID: ${user?.id ?? '-'}')
        ..writeln(
          'Email: ${user?.email ?? StorageHelper.getUserEmail() ?? '-'}',
        )
        ..writeln(
          'Açıklama: Hesabımın ve bağlı verilerimin silinmesini talep ediyorum.',
        );
      await Clipboard.setData(ClipboardData(text: message.toString()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silme talebi metni panoya kopyalandı.')),
      );
    } finally {
      if (mounted) {
        setState(() => _processingDelete = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: _analytics,
            onChanged: (v) async {
              setState(() => _analytics = v);
              await _save();
            },
            title: const Text('Anonim analiz verisi'),
            subtitle: const Text(
              'Uygulamayı iyileştirmek için anonim kullanım verisi',
            ),
          ),
          SwitchListTile(
            value: _personalization,
            onChanged: (v) async {
              setState(() => _personalization = v);
              await _save();
            },
            title: const Text('Kişiselleştirme'),
            subtitle: const Text(
              'İçerik önerilerini hedeflerine göre özelleştir',
            ),
          ),
          SwitchListTile(
            value: _crashReports,
            onChanged: (v) async {
              setState(() => _crashReports = v);
              await _save();
            },
            title: const Text('Hata raporları'),
            subtitle: const Text('Beklenmeyen hata bilgilerini anonim gönder'),
          ),
          const Divider(height: 22),
          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Verilerimi dışa aktar'),
            subtitle: const Text('JSON dosyası olarak indir ve paylaş'),
            trailing: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_rounded),
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
            title: const Text('Hesap silme talebi'),
            subtitle: const Text('Talep metni oluşturup panoya kopyala'),
            trailing: _processingDelete
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy_rounded),
            onTap: _deleteRequestFlow,
          ),
          const Divider(height: 22),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Gizlilik Politikası'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LegalScreen(initialTab: LegalTab.privacy),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Kullanım Koşulları'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const LegalScreen(initialTab: LegalTab.terms),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
