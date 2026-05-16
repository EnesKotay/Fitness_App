import 'package:flutter/material.dart';
import '../../../core/services/page_guide_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _kSupportEmail = String.fromEnvironment(
  'APP_SUPPORT_EMAIL',
  defaultValue: 'eneskotay23@gmail.com',
);

class SettingsHelpScreen extends StatelessWidget {
  const SettingsHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yardım')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Sık Sorulan Sorular',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const ExpansionTile(
            title: Text('Günlük kalori hedefi nasıl hesaplanır?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Yaş, boy, kilo, aktivite seviyesi ve hedefe göre otomatik hesaplanır. '
                  'Profil → Profili Düzenle adımından güncelleyebilirsin.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Verilerim neden görünmüyor?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'İnternet bağlantını kontrol et ve profil sayfasında aşağı çekip yenile.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Hedefimi nereden değiştiririm?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Profil → Profili Düzenle adımından hedef ve temel bilgileri güncelleyebilirsin.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Premium aboneliği nasıl iptal ederim?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'iPhone: Ayarlar → Apple ID → Abonelikler → PusulaFit → İptal Et.\n'
                  'Android: Google Play → Abonelikler → PusulaFit → İptal Et.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Verilerimi nasıl silerim?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Profil → Gizlilik → Hesabı Sil adımından tüm verilerini kalıcı olarak silebilirsin.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Destek E-posta'),
            subtitle: Text(_kSupportEmail),
            trailing: const Icon(Icons.copy_rounded),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _kSupportEmail));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('E-posta kopyalandı')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.open_in_new_rounded),
            title: const Text('E-posta Gönder'),
            subtitle: Text(_kSupportEmail),
            onTap: () => launchUrl(
              Uri.parse('mailto:$_kSupportEmail?subject=PusulaFit%20Destek'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: const Text('Rehberleri Sıfırla'),
            subtitle: const Text('Tüm sayfa rehberlerini baştan göster'),
            onTap: () async {
              await PageGuideService.resetAllGuides();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Rehberler sıfırlandı — sayfalara girince tekrar gösterilecek')),
              );
            },
          ),
        ],
      ),
    );
  }
}
