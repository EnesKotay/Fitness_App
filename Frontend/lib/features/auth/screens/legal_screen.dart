import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

const _kPrivacyPolicyUrl = String.fromEnvironment(
  'APP_PRIVACY_URL',
  defaultValue: '',
);
const _kTermsOfServiceUrl = String.fromEnvironment(
  'APP_TERMS_URL',
  defaultValue: '',
);
const _kSupportUrl = String.fromEnvironment(
  'APP_SUPPORT_URL',
  defaultValue: '',
);
const _kPrivacyEmail = String.fromEnvironment(
  'APP_PRIVACY_EMAIL',
  defaultValue: 'privacy@fitmentor.app',
);
const _kLegalEmail = String.fromEnvironment(
  'APP_LEGAL_EMAIL',
  defaultValue: 'legal@fitmentor.app',
);

enum LegalTab { privacy, terms }

class LegalScreen extends StatefulWidget {
  final LegalTab initialTab;
  const LegalScreen({super.key, this.initialTab = LegalTab.privacy});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == LegalTab.terms ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yasal Bilgiler'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Gizlilik Politikası'),
            Tab(text: 'Kullanım Koşulları'),
          ],
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white54,
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [
          _PrivacyPolicyView(),
          _TermsOfServiceView(),
        ],
      ),
    );
  }
}

// ── Privacy Policy ─────────────────────────────────────────────────────────────

class _PrivacyPolicyView extends StatelessWidget {
  const _PrivacyPolicyView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LegalTitle('Gizlilik Politikası'),
          const _LegalDate('Son güncelleme: Mart 2025'),
          const _LegalSection('1. Toplanan Veriler', '''
FitMentor uygulaması ("Uygulama") aşağıdaki verileri toplar:

• Hesap bilgileri: ad, e-posta adresi, şifre (şifrelenmiş)
• Profil bilgileri: yaş, boy, kilo, cinsiyet, hedefler
• Beslenme verileri: yemek günlüğü, kalori takibi
• Antrenman verileri: egzersiz geçmişi, setler, tekrarlar
• Vücut ölçümleri: ağırlık, beden ölçüleri
• Cihaz bilgileri: cihaz türü, işletim sistemi versiyonu
• Kullanım istatistikleri: özellik kullanımı, hata raporları (isteğe bağlı)'''),
          const _LegalSection('2. Verilerin Kullanım Amacı', '''
Toplanan veriler yalnızca aşağıdaki amaçlarla kullanılır:

• Kişiselleştirilmiş fitness ve beslenme takibi sağlamak
• AI koç özelliğini çalıştırmak (Gemini/Claude AI)
• Uygulama performansını iyileştirmek
• Hesap güvenliğini sağlamak
• Premium üyelik yönetimi
• Yasal yükümlülükleri yerine getirmek'''),
          const _LegalSection('3. Veri Paylaşımı', """
Verileriniz üçüncü taraflarla şu durumlarda paylaşılabilir:

• AI servisleri: Beslenme ve fitness analizleri için Google Gemini veya Anthropic Claude API'sine anonim veri gönderilir
• Ödeme altyapısı: Premium üyelik için ödeme işlemcileri (Apple App Store / Google Play)
• Barcode & gıda veritabanı: Open Food Facts (açık kaynak, anonim)
• Yasal zorunluluk: Mahkeme kararı veya yasal mevzuat gerektirdiğinde

Verileriniz hiçbir koşulda reklam amaçlı üçüncü taraflarla paylaşılmaz."""),
          const _LegalSection('4. Veri Güvenliği', """
• Tüm veriler HTTPS/TLS ile şifreli aktarılır
• Şifreler bcrypt ile hash'lenerek saklanır
• JWT token'lar güvenli depolama (Keychain/Keystore) kullanır
• Veriler Türkiye veya AB sunucularında saklanır"""),
          const _LegalSection('5. Veri Saklama Süresi', '''
• Aktif hesaplar: hesap silinene kadar
• Silinen hesaplar: talebin ardından 30 gün içinde kalıcı olarak silinir
• Yedekler: 90 gün içinde temizlenir'''),
          const _LegalSection('6. Kullanıcı Hakları (KVKK)', '''
6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında şu haklarınız vardır:

• Verilerinizin işlenip işlenmediğini öğrenme
• İşlenme amacını ve buna uygun kullanılıp kullanılmadığını öğrenme
• Verilerinizin düzeltilmesini isteme
• Verilerinizin silinmesini veya yok edilmesini isteme
• İşlemeye itiraz etme
• Verilerinizin JSON formatında dışa aktarılmasını isteme

Bu haklarınızı Ayarlar → Gizlilik bölümünden kullanabilirsiniz.'''),
          const _LegalSection('7. Çocukların Gizliliği', '''
Uygulamamız 13 yaşın altındaki çocuklara yönelik değildir. 13 yaşın altındaki bir kullanıcıya ait veri tespit edilirse derhal silinir.'''),
          const _LegalSection('8. İletişim', '''
Gizlilik ile ilgili sorularınız için:
E-posta: $_kPrivacyEmail

Bu politika zaman zaman güncellenebilir. Önemli değişikliklerde uygulama içi bildirim gönderilir.'''),
          const SizedBox(height: 8),
          _ExternalLinkButton(
            label: 'Tam Politikayı Tarayıcıda Aç',
            url: _kPrivacyPolicyUrl,
          ),
          const SizedBox(height: 8),
          _ExternalLinkButton(
            label: 'Destek',
            url: _kSupportUrl,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Terms of Service ───────────────────────────────────────────────────────────

class _TermsOfServiceView extends StatelessWidget {
  const _TermsOfServiceView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LegalTitle('Kullanım Koşulları'),
          const _LegalDate('Son güncelleme: Mart 2025'),
          const _LegalSection('1. Kabul', """
FitMentor uygulamasını kullanarak bu Kullanım Koşulları'nı kabul etmiş sayılırsınız. Koşulları kabul etmiyorsanız uygulamayı kullanmamalısınız."""),
          const _LegalSection('2. Hesap', '''
• Hesap oluşturmak için doğru ve güncel bilgi sağlamalısınız
• Hesabınızın güvenliğinden siz sorumlusunuz
• Şüpheli bir erişim fark ederseniz hemen şifrenizi değiştirin
• Bir kişi yalnızca bir hesap oluşturabilir'''),
          const _LegalSection('3. Kullanım Kuralları', '''
Aşağıdaki davranışlar yasaktır:

• Uygulamayı yasadışı amaçlarla kullanmak
• Başka kullanıcıların hesaplarına yetkisiz erişim sağlamak
• Uygulamanın altyapısına zarar verecek işlemler yapmak
• Yanlış sağlık veya tıbbi bilgi yaymak
• Uygulamayı tersine mühendislik ile analiz etmek'''),
          const _LegalSection('4. Premium Üyelik', '''
• Premium özellikler aylık veya yıllık abonelik gerektirir
• Abonelikler App Store veya Google Play üzerinden yönetilir
• Ödeme, satın alma onayında Apple/Google hesabınızdan çekilir
• Abonelik, mevcut dönem sona ermeden en az 24 saat önce iptal edilmezse otomatik yenilenir
• İptal işlemi için cihazınızın App Store/Google Play abonelik yönetimini kullanın
• Kullanılmamış abonelik süresine geri ödeme yapılmaz (platform kuralları gereği)'''),
          const _LegalSection('5. Sağlık Uyarısı', '''
FitMentor bir tıbbi cihaz veya sağlık hizmeti değildir.

• Uygulama yalnızca genel sağlıklı yaşam bilgisi sunar
• Herhangi bir sağlık sorununda mutlaka bir doktora başvurun
• AI koç önerileri profesyonel tıbbi tavsiye yerine geçmez
• Aşırı egzersiz veya yetersiz beslenme ile ilgili kararlardan kullanıcı sorumludur'''),
          const _LegalSection('6. Fikri Mülkiyet', '''
• Uygulamanın tüm içeriği, tasarımı ve kodu telif hakkı ile korunmaktadır
• Kullanıcılar uygulamayı yalnızca kişisel, ticari olmayan amaçlarla kullanabilir
• Uygulama içeriğinin izinsiz kopyalanması, dağıtılması yasaktır'''),
          const _LegalSection('7. Sorumluluk Sınırlaması', '''
Uygulama "olduğu gibi" sunulmaktadır. Şu konularda sorumluluk kabul edilmez:

• Kullanıcının verdiği yanlış bilgilerden kaynaklanan sonuçlar
• İnternet bağlantısı kesintilerinden kaynaklanan veri kaybı
• Üçüncü taraf servislerden (AI, barcode DB) kaynaklanan hatalar'''),
          const _LegalSection('8. Değişiklikler', '''
Bu koşullar zaman zaman güncellenebilir. Devam eden kullanım güncel koşulları kabul ettiğiniz anlamına gelir.'''),
          const _LegalSection('9. Geçerli Hukuk', '''
Bu sözleşme Türkiye Cumhuriyeti yasalarına tabidir. Anlaşmazlıklarda İstanbul mahkemeleri yetkilidir.'''),
          const _LegalSection('10. İletişim', '''
Sorularınız için:
E-posta: $_kLegalEmail'''),
          const SizedBox(height: 8),
          _ExternalLinkButton(
            label: 'Tam Koşulları Tarayıcıda Aç',
            url: _kTermsOfServiceUrl,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────────

class _LegalTitle extends StatelessWidget {
  final String text;
  const _LegalTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _LegalDate extends StatelessWidget {
  final String text;
  const _LegalDate(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      child: Text(
        text,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String body;
  const _LegalSection(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 13.5,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalLinkButton extends StatelessWidget {
  final String label;
  final String url;
  const _ExternalLinkButton({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = url.trim();
    return OutlinedButton.icon(
      onPressed: trimmedUrl.isEmpty
          ? null
          : () => launchUrl(
                Uri.parse(trimmedUrl),
                mode: LaunchMode.externalApplication,
              ),
      icon: const Icon(Icons.open_in_new, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
      ),
    );
  }
}
