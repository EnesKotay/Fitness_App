import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _healthConsent = false;
  bool _transferConsent = false;
  bool _paymentTransferConsent = false;
  bool _exporting = false;
  bool _processingDelete = false;

  @override
  void initState() {
    super.initState();
    _analytics = StorageHelper.getPrivacyAnalytics();
    _personalization = StorageHelper.getPrivacyPersonalization();
    _crashReports = StorageHelper.getPrivacyCrashReports();
    _healthConsent = StorageHelper.getPrivacyHealthConsent();
    _transferConsent = StorageHelper.getPrivacyTransferConsent();
    _paymentTransferConsent = StorageHelper.getPrivacyPaymentTransferConsent();
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
      final box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Fitness hesap verisi dışa aktarma',
          sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
        );
      } else {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Fitness hesap verisi dışa aktarma',
        );
      }
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
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı Sil'),
        content: const Text(
          'Bu işlem hesabını ve bağlı verilerini kalıcı olarak siler. Bu işlem geri alınamaz. Aktif App Store aboneliğin varsa, faturalandırma iptalini ayrıca Apple aboneliklerinden yönetmelisin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kalıcı Olarak Sil'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => _processingDelete = true);
    try {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final ok = await auth.deleteAccount();
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hesabın silindi.')),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Hesap silinemedi.'),
        ),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'KVKK AÇIK RIZA YÖNETİMİ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 1.0,
              ),
            ),
          ),
          SwitchListTile(
            value: _healthConsent,
            onChanged: (v) async {
              if (!v) {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sağlık Verisi Rızasını Geri Al'),
                    content: const Text(
                      'Bu onayı kapatırsanız sağlık verileriniz (kilo, beslenme, egzersiz) '
                      'artık işlenemez ve uygulama temel işlevlerini kaybeder. '
                      'Devam etmek istiyor musunuz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Vazgeç'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Rızayı Geri Al'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
              }
              setState(() => _healthConsent = v);
              await StorageHelper.savePrivacyHealthConsent(v);
            },
            title: const Text('Sağlık verisi işleme (KVKK Md.6)'),
            subtitle: const Text(
              'Kilo, beslenme, egzersiz verilerinin işlenmesine rıza. '
              'Kapatırsanız temel özellikler devre dışı kalır.',
            ),
          ),
          SwitchListTile(
            value: _transferConsent,
            onChanged: (v) async {
              if (!v) {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Yurt Dışı Aktarım Rızasını Geri Al'),
                    content: const Text(
                      'Bu onayı kapatırsanız verileriniz Google Gemini (ABD) ve '
                      'Apple/Google\'a (ABD) aktarılamaz. AI koç özelliği devre dışı kalır. '
                      'Devam etmek istiyor musunuz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Vazgeç'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Rızayı Geri Al'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
              }
              setState(() => _transferConsent = v);
              await StorageHelper.savePrivacyTransferConsent(v);
            },
            title: const Text('Google AI aktarımı (KVKK Md.9)'),
            subtitle: const Text(
              'Sağlık verilerinin Google Gemini (ABD)\'ye AI analizi için aktarımına rıza. '
              'Kapatırsanız AI koç devre dışı kalır.',
            ),
          ),
          SwitchListTile(
            value: _paymentTransferConsent,
            onChanged: (v) async {
              if (!v) {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Ödeme Aktarımı Rızasını Geri Al'),
                    content: const Text(
                      'Bu onayı kapatırsanız abonelik doğrulaması için Apple/Google\'a aktarım yapılamaz. '
                      'Premium özellikler devre dışı kalabilir. Devam etmek istiyor musunuz?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Vazgeç'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Rızayı Geri Al'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
              }
              setState(() => _paymentTransferConsent = v);
              await StorageHelper.savePrivacyPaymentTransferConsent(v);
            },
            title: const Text('Apple/Google ödeme aktarımı (KVKK Md.9)'),
            subtitle: const Text(
              'Abonelik doğrulaması için Apple/Google\'a aktarıma rıza. '
              'Kart bilgisi FitMentor\'da saklanmaz.',
            ),
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
            title: const Text('Hesabı kalıcı olarak sil'),
            subtitle: const Text('Hesabını ve bağlı verilerini uygulama içinden sil'),
            trailing: _processingDelete
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_rounded),
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
          const Divider(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'KVKK Haklarım',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.4),
                letterSpacing: 0.8,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded),
            title: const Text('KVKK Aydınlatma Metni'),
            subtitle: const Text('Hangi veriler, neden, nasıl işleniyor'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const LegalScreen(initialTab: LegalTab.kvkk),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('KVKK Başvurusu Yap'),
            subtitle: const Text(
              'Veri erişim, düzeltme, silme veya itiraz talebi',
            ),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse(
                'mailto:eneskotay23@gmail.com?subject=KVKK%20Madde%2011%20Ba%C5%9Fvurusu',
              ),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_outlined),
            title: const Text('KVK Kurumu\'na Başvur'),
            subtitle: const Text(
              'Başvurunuz reddedilirse veya yanıt alınmazsa',
            ),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('https://www.kvkk.gov.tr'),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
    );
  }
}
