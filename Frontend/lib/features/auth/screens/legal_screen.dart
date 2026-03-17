import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

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
        children: const [
          _LegalTitle('Gizlilik Politikası'),
          _LegalDate('Son güncelleme: Mart 2025'),
          _LegalSection('1. Toplanan Veriler', '''
FitMentor uygulaması ("Uygulama") aşağıdaki verileri toplar:

• Hesap bilgileri: ad, e-posta adresi, şifre (şifrelenmiş)
• Profil bilgileri: yaş, boy, kilo, cinsiyet, hedefler
• Beslenme verileri: yemek günlüğü, kalori takibi
• Antrenman verileri: egzersiz geçmişi, setler, tekrarlar
• Vücut ölçümleri: ağırlık, beden ölçüleri
• Cihaz bilgileri: cihaz türü, işletim sistemi versiyonu
• Kullanım istatistikleri: özellik kullanımı, hata raporları (isteğe bağlı)'''),
          _LegalSection('2. Verilerin Kullanım Amacı', '''
Toplanan veriler yalnızca aşağıdaki amaçlarla kullanılır:

• Kişiselleştirilmiş fitness ve beslenme takibi sağlamak
• AI koç özelliğini çalıştırmak (Gemini/Claude AI)
• Uygulama performansını iyileştirmek
• Hesap güvenliğini sağlamak
• Premium üyelik yönetimi
• Yasal yükümlülükleri yerine getirmek'''),
          _LegalSection('3. Veri Paylaşımı', """
Verileriniz üçüncü taraflarla şu durumlarda paylaşılabilir:

• AI servisleri: Beslenme ve fitness analizleri için Google Gemini veya Anthropic Claude API'sine anonim veri gönderilir
• Ödeme altyapısı: Premium üyelik için ödeme işlemcileri (Apple App Store / Google Play)
• Barcode & gıda veritabanı: Open Food Facts (açık kaynak, anonim)
• Yasal zorunluluk: Mahkeme kararı veya yasal mevzuat gerektirdiğinde

Verileriniz hiçbir koşulda reklam amaçlı üçüncü taraflarla paylaşılmaz."""),
          _LegalSection('4. Veri Güvenliği', """
• Tüm veriler HTTPS/TLS ile şifreli aktarılır
• Şifreler bcrypt ile hash'lenerek saklanır
• JWT token'lar güvenli depolama (Keychain/Keystore) kullanır
• Veriler Türkiye veya AB sunucularında saklanır"""),
          _LegalSection('5. Veri Saklama Süresi', '''
• Aktif hesaplar: hesap silinene kadar
• Silinen hesaplar: talebin ardından 30 gün içinde kalıcı olarak silinir
• Yedekler: 90 gün içinde temizlenir'''),
          _LegalSection('6. Kullanıcı Hakları (KVKK)', '''
6698 sayılı Kişisel Verilerin Korunması Kanunu kapsamında şu haklarınız vardır:

• Verilerinizin işlenip işlenmediğini öğrenme
• İşlenme amacını ve buna uygun kullanılıp kullanılmadığını öğrenme
• Verilerinizin düzeltilmesini isteme
• Verilerinizin silinmesini veya yok edilmesini isteme
• İşlemeye itiraz etme
• Verilerinizin JSON formatında dışa aktarılmasını isteme

Bu haklarınızı Ayarlar → Gizlilik bölümünden kullanabilirsiniz.'''),
          _LegalSection('7. Çocukların Gizliliği', '''
Uygulamamız 13 yaşın altındaki çocuklara yönelik değildir. 13 yaşın altındaki bir kullanıcıya ait veri tespit edilirse derhal silinir.'''),
          _LegalSection('8. İletişim', '''
Gizlilik ile ilgili sorularınız için:
E-posta: privacy@fitnessapp.com

Bu politika zaman zaman güncellenebilir. Önemli değişikliklerde uygulama içi bildirim gönderilir.'''),
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
        children: const [
          _LegalTitle('Kullanım Koşulları'),
          _LegalDate('Son güncelleme: Mart 2025'),
          _LegalSection('1. Kabul', """
FitMentor uygulamasını kullanarak bu Kullanım Koşulları'nı kabul etmiş sayılırsınız. Koşulları kabul etmiyorsanız uygulamayı kullanmamalısınız."""),
          _LegalSection('2. Hesap', '''
• Hesap oluşturmak için doğru ve güncel bilgi sağlamalısınız
• Hesabınızın güvenliğinden siz sorumlusunuz
• Şüpheli bir erişim fark ederseniz hemen şifrenizi değiştirin
• Bir kişi yalnızca bir hesap oluşturabilir'''),
          _LegalSection('3. Kullanım Kuralları', '''
Aşağıdaki davranışlar yasaktır:

• Uygulamayı yasadışı amaçlarla kullanmak
• Başka kullanıcıların hesaplarına yetkisiz erişim sağlamak
• Uygulamanın altyapısına zarar verecek işlemler yapmak
• Yanlış sağlık veya tıbbi bilgi yaymak
• Uygulamayı tersine mühendislik ile analiz etmek'''),
          _LegalSection('4. Premium Üyelik', '''
• Premium özellikler aylık veya yıllık abonelik gerektirir
• Abonelikler App Store veya Google Play üzerinden yönetilir
• Ödeme, satın alma onayında Apple/Google hesabınızdan çekilir
• Abonelik, mevcut dönem sona ermeden en az 24 saat önce iptal edilmezse otomatik yenilenir
• İptal işlemi için cihazınızın App Store/Google Play abonelik yönetimini kullanın
• Kullanılmamış abonelik süresine geri ödeme yapılmaz (platform kuralları gereği)'''),
          _LegalSection('5. Sağlık Uyarısı', '''
FitMentor bir tıbbi cihaz veya sağlık hizmeti değildir.

• Uygulama yalnızca genel sağlıklı yaşam bilgisi sunar
• Herhangi bir sağlık sorununda mutlaka bir doktora başvurun
• AI koç önerileri profesyonel tıbbi tavsiye yerine geçmez
• Aşırı egzersiz veya yetersiz beslenme ile ilgili kararlardan kullanıcı sorumludur'''),
          _LegalSection('6. Fikri Mülkiyet', '''
• Uygulamanın tüm içeriği, tasarımı ve kodu telif hakkı ile korunmaktadır
• Kullanıcılar uygulamayı yalnızca kişisel, ticari olmayan amaçlarla kullanabilir
• Uygulama içeriğinin izinsiz kopyalanması, dağıtılması yasaktır'''),
          _LegalSection('7. Sorumluluk Sınırlaması', '''
Uygulama "olduğu gibi" sunulmaktadır. Şu konularda sorumluluk kabul edilmez:

• Kullanıcının verdiği yanlış bilgilerden kaynaklanan sonuçlar
• İnternet bağlantısı kesintilerinden kaynaklanan veri kaybı
• Üçüncü taraf servislerden (AI, barcode DB) kaynaklanan hatalar'''),
          _LegalSection('8. Değişiklikler', '''
Bu koşullar zaman zaman güncellenebilir. Devam eden kullanım güncel koşulları kabul ettiğiniz anlamına gelir.'''),
          _LegalSection('9. Geçerli Hukuk', '''
Bu sözleşme Türkiye Cumhuriyeti yasalarına tabidir. Anlaşmazlıklarda İstanbul mahkemeleri yetkilidir.'''),
          _LegalSection('10. İletişim', '''
Sorularınız için:
E-posta: legal@fitnessapp.com'''),
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
