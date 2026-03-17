import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SettingsHelpScreen extends StatelessWidget {
  const SettingsHelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yardim')),
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
                  'Yas, boy, kilo, aktivite seviyesi ve hedefe gore otomatik hesaplanir.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Verilerim neden gorunmuyor?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Internet baglantini kontrol et ve profil sayfasinda asagi cekip yenile.',
                ),
              ),
            ],
          ),
          const ExpansionTile(
            title: Text('Hedefimi nereden degistiririm?'),
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Profil > Profili Duzenle adimindan hedef ve temel bilgileri guncelleyebilirsin.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Destek E-posta'),
            subtitle: const Text('support@fitnessapp.local'),
            trailing: const Icon(Icons.copy_rounded),
            onTap: () async {
              await Clipboard.setData(
                const ClipboardData(text: 'support@fitnessapp.local'),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('E-posta kopyalandi')),
              );
            },
          ),
        ],
      ),
    );
  }
}
