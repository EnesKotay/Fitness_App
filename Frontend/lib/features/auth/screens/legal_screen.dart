import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

const _kSupportUrl = String.fromEnvironment(
  'APP_SUPPORT_URL',
  defaultValue: 'mailto:support@fitmentor.app?subject=FitMentor%20Destek',
);
const _kPrivacyEmail = String.fromEnvironment(
  'APP_PRIVACY_EMAIL',
  defaultValue: 'privacy@fitmentor.app',
);
const _kLegalEmail = String.fromEnvironment(
  'APP_LEGAL_EMAIL',
  defaultValue: 'legal@fitmentor.app',
);
// Veri sorumlusu bilgileri — Production build'de --dart-define ile override edin:
//   --dart-define=APP_DATA_CONTROLLER_NAME="Şirket Ünvanı A.Ş."
//   --dart-define=APP_DATA_CONTROLLER_ADDRESS="Örnek Mah. ... İstanbul"
//   --dart-define=APP_DATA_CONTROLLER_TAX_ID="1234567890"
// Bu sabitler App Store review sırasında UI'da görünür olmalıdır.
const _kDataControllerName = String.fromEnvironment(
  'APP_DATA_CONTROLLER_NAME',
  defaultValue: 'FitMentor',
);
const _kDataControllerAddress = String.fromEnvironment(
  'APP_DATA_CONTROLLER_ADDRESS',
  defaultValue: 'Türkiye — Tam adres için: privacy@fitmentor.app',
);
const _kDataControllerTaxId = String.fromEnvironment(
  'APP_DATA_CONTROLLER_TAX_ID',
  defaultValue: 'Tescil bilgisi için iletişim: privacy@fitmentor.app',
);

enum LegalTab { privacy, terms, kvkk }

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
      length: 3,
      vsync: this,
      initialIndex: switch (widget.initialTab) {
        LegalTab.terms => 1,
        LegalTab.kvkk => 2,
        _ => 0,
      },
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Gizlilik Politikası'),
            Tab(text: 'Kullanım Koşulları'),
            Tab(text: 'KVKK Aydınlatma'),
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
          _KvkkAydinlatmaView(),
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
          const _LegalDate('Son güncelleme: Nisan 2025'),
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
          const _LegalSection('3. Veri Paylaşımı ve Yurt Dışına Aktarım (KVKK Madde 9)', """
Verileriniz yalnızca aşağıdaki alıcılarla ve belirtilen amaçlarla paylaşılabilir:

• Google LLC (ABD) — AI koç: Beslenme ve fitness analizi. Açık rıza (Md.9). Rıza geri alınırsa AI özelliği devre dışı kalır.
• Apple Inc. / Google Inc. (ABD) — Ödeme: Abonelik doğrulaması. Açık rıza (Md.9). Kart bilgisi FitMentor'da saklanmaz.
• Open Food Facts (Fransa/AB) — Gıda DB: Yalnızca barkod numarası gönderilir; kişisel veri iletilmez.
• Sentry (ABD) — Hata raporlama: Kilitlenme izleri ve teknik log. Meşru menfaat (Md.5/2-f). Ayarlar → Gizlilik → Hata raporları seçeneğiyle kapatılabilir.
• Yasal zorunluluk: Mahkeme kararı veya mevzuat gerektirdiğinde, yalnızca zorunlu minimum veri.

Verileriniz hiçbir koşulda reklam amaçlı üçüncü taraflarla paylaşılmaz."""),
          const _LegalSection('4. Veri Güvenliği (KVKK Madde 12)', """
Teknik önlemler:
• Tüm veriler HTTPS/TLS ile şifreli aktarılır
• Şifreler bcrypt ile hash'lenerek saklanır
• JWT token'lar güvenli depolama (Keychain/Keystore) kullanır
• Veriler Türkiye veya AB sunucularında saklanır

İdari önlemler:
• Kişisel verilere erişim yalnızca yetkili personelle sınırlıdır
• Üçüncü taraf hizmet sağlayıcılarla veri işleme sözleşmesi (DPA) imzalanmaktadır
• Güvenlik açıkları periyodik olarak denetlenmektedir

Veri ihlali bildirimi (KVKK Madde 12/5):
Kişisel veri güvenliği ihlali tespit edilmesi halinde, KVKK Madde 12/5 uyarınca 72 saat içinde Kişisel Verileri Koruma Kurumu'na bildirim yapılır. Risk düzeyine göre ilgili kişiler makul süre içinde bilgilendirilir."""),
          const _LegalSection('5. Veri Saklama Süresi', '''
• Aktif hesaplar: hesap silinene kadar
• Silinen hesaplar: talebin ardından 30 gün içinde kalıcı olarak silinir
• Yedekler: 90 gün içinde temizlenir'''),
          _LegalSection('6. Veri Sorumlusu', '''
6698 sayılı KVKK Madde 10 uyarınca veri sorumlusu:

Unvan  : $_kDataControllerName
Vergi/TC: $_kDataControllerTaxId
Adres  : $_kDataControllerAddress
E-posta: $_kPrivacyEmail

KVKK Madde 11 kapsamındaki başvurularınızı kimliğinizi doğrulayan bilgilerle (ad, e-posta) birlikte yukarıdaki e-posta adresine iletebilirsiniz. Başvurular en geç 30 gün içinde yanıtlanır.'''),
          const _LegalSection('7. KVKK Kapsamındaki Tüm Haklarınız (Madde 11)', '''
a) Kişisel verilerinizin işlenip işlenmediğini öğrenme
b) İşlenmişse buna ilişkin bilgi talep etme
c) İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme
ç) Yurt içinde veya yurt dışında aktarıldığı üçüncü kişileri bilme
d) Eksik veya yanlış işlenmiş ise düzeltilmesini isteme
e) KVKK Madde 7 çerçevesinde silinmesini veya yok edilmesini isteme
f) (d) ve (e) kapsamındaki işlemlerin üçüncü kişilere bildirilmesini isteme
g) Otomatik analiz sonucu aleyhinize karar oluşmasına itiraz etme
ğ) Kanuna aykırı işleme nedeniyle zarara uğramanız halinde tazminat talep etme

Uygulama içinden kullanabileceğiniz haklar:
• Veri dışa aktarma → Ayarlar → Gizlilik → "Verilerimi dışa aktar"
• Hesap silme → Ayarlar → Gizlilik → "Hesabı kalıcı olarak sil"
• Diğer başvurular → $_kPrivacyEmail (Konu: "KVKK Madde 11 Başvurusu")
• KVK Kurumu'na şikâyet → www.kvkk.gov.tr (yanıt verilmezse veya reddedilirse)'''),
          const _LegalSection('8. Reşit Olmayanlar', '''
FitMentor, 18 yaşın altındaki bireyler için tasarlanmamıştır. Türk Medeni Kanunu uyarınca 18 yaş altı kullanıcıların sağlık verisi gibi özel nitelikli kişisel verilerinin işlenebilmesi için yasal temsilcilerinin (ebeveyn/vasi) açık rızası gereklidir.

18 yaşın altındaki bir kullanıcıya ait veri tespit edilmesi halinde söz konusu veriler derhal silinir ve ilgili hesap kapatılır.'''),
          const _LegalSection('9. İletişim', '''
Gizlilik ile ilgili sorularınız için:
E-posta: $_kPrivacyEmail

Bu politika zaman zaman güncellenebilir. Önemli değişikliklerde uygulama içi bildirim gönderilir.'''),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── KVKK Aydınlatma Metni ──────────────────────────────────────────────────────

class _KvkkAydinlatmaView extends StatelessWidget {
  const _KvkkAydinlatmaView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LegalTitle('KVKK Aydınlatma Metni'),
          const _LegalDate('6698 Sayılı Kişisel Verilerin Korunması Kanunu Madde 10'),
          _LegalSection('1. Veri Sorumlusu', '''
6698 sayılı KVKK Madde 10 uyarınca, kişisel verilerinizi işleyen veri sorumlusu:

Unvan  : $_kDataControllerName
Vergi/TC: $_kDataControllerTaxId
Adres  : $_kDataControllerAddress
E-posta: $_kPrivacyEmail
Başvuru: $_kPrivacyEmail — Konu: "KVKK Madde 11 Başvurusu"

Not: Veri sorumlusuna yönelik başvurularda kimliğinizi doğrulayan bilgileri (ad, e-posta adresi) eklemeniz gerekmektedir. Başvurular KVKK Madde 13 gereği en geç 30 gün içinde yanıtlanır.'''),
          const _LegalSection('2. İşlenen Kişisel Veri Kategorileri ve Hukuki Sebepleri', '''
Kimlik / iletişim verisi
  Örnekler: Ad, e-posta adresi
  Hukuki sebep: Sözleşmenin kurulması ve ifası (Md. 5/2-c)

Özel nitelikli sağlık verisi
  Örnekler: Boy, kilo, vücut ölçüleri, yemek tüketimi, egzersiz geçmişi
  Hukuki sebep: Açık rıza (Md. 6/3)

Teknik / cihaz verisi
  Örnekler: Cihaz türü, işletim sistemi, uygulama sürümü
  Hukuki sebep: Sözleşmenin kurulması ve ifası (Md. 5/2-c)
  Gerekçe: Teknik veriler olmadan hizmet teknik olarak sunulamaz.

Analitik ve hata raporlama verisi
  Örnekler: Özellik kullanım istatistikleri, kilitlenme raporları (Sentry)
  Hukuki sebep: Meşru menfaat (Md. 5/2-f)
  Gerekçe: Hizmet kalitesi ve kararlılığı iyileştirme. Ayarlar → Gizlilik → Hata raporları / Anonim analiz seçenekleriyle kullanıcı tarafından devre dışı bırakılabilir.

Ödeme / abonelik verisi
  Örnekler: İşlem tarihi, abonelik durumu (kart bilgisi saklanmaz)
  Hukuki sebep: Sözleşmenin ifası (Md. 5/2-c)'''),
          const _LegalSection('3. Kişisel Verilerin İşlenme Amaçları', '''
• Uygulama hizmetinin ve kullanıcı hesabının yönetimi
• Kişiselleştirilmiş fitness ve beslenme takibinin sağlanması
• AI koç özelliğinin çalıştırılması (Google Gemini)
• Hesap güvenliği ve kimlik doğrulaması
• Premium üyelik süreçlerinin yönetimi
• Anonim kullanım analitiği ile hizmet kalitesinin artırılması
• Yasal yükümlülüklerin yerine getirilmesi'''),
          const _LegalSection('4. Kişisel Verilerin Aktarımı', '''
Yurt İçi: Veriler doğrudan FitMentor sunucu altyapısında saklanır; üçüncü taraf reklam amaçlı aktarım yapılmaz.

Yurt Dışı Aktarım (KVKK Madde 9 — Açık Rıza):
• Google LLC (ABD) — Google Gemini API: Beslenme ve fitness AI analizi için sağlık verisi aktarılır. Kayıt sırasında kullanıcının açık rızası alınmaktadır. Rıza geri alındığında AI koç özelliği devre dışı kalır.
• Apple Inc. / Google Inc. (ABD) — App Store / Google Play: Abonelik durumu ve satın alma doğrulaması. Kart veya ödeme bilgisi FitMentor tarafından işlenmez ya da saklanmaz. Kayıt sırasında kullanıcının açık rızası alınmaktadır.
• Open Food Facts (Fransa/AB): Barkod sorgularında yalnızca ürün barkod numarası iletilmekte olup ad, e-posta veya sağlık verisi gibi kişisel veri gönderilmemektedir.
• Sentry (ABD) — Hata raporlama: Uygulama kilitlenme izleri ve teknik log verisi. Hukuki sebep: Meşru menfaat (Md. 5/2-f). Ayarlar → Gizlilik → Hata raporları seçeneğiyle devre dışı bırakılabilir.'''),
          const _LegalSection('5. Kişisel Veri Toplamanın Yöntemi', '''
• Elektronik ortam: Kayıt formu, profil kurulumu, uygulama içi girişler
• Otomatik yöntem: Uygulama kullanımı sırasında kaydedilen teknik log verileri
• Üçüncü taraf: App Store / Google Play abonelik durum bildirimleri'''),
          const _LegalSection('6. Otomatik Karar Verme ve Profilleme', '''
AI koç önerileri (antrenman planı, beslenme tavsiyesi) Google Gemini tarafından otomatik olarak üretilmektedir. Bu öneriler:

• Kullanıcı tarafından kabul ya da reddedilebilir
• Hukuki sonuç veya benzer önemde bir etki doğurmaz
• İnsan gözetimi olmaksızın bağlayıcı karar oluşturmaz

KVKK Madde 11/g kapsamında bu otomatik işleme itiraz hakkınız saklıdır.'''),
          const _LegalSection('7. Veri Saklama Süreleri', '''
• Aktif hesap: Hesap kapatma talebine kadar
• Kapatılan hesap: Talepten itibaren 30 gün içinde kalıcı silme
• Yedek sistemler: 90 gün içinde imha
• Anonim analitik veriler: Süresiz (kişisel veri içermez)'''),
          const _LegalSection('8. KVKK Madde 11 Kapsamındaki Tüm Haklarınız', '''
a) Kişisel verilerinizin işlenip işlenmediğini öğrenme
b) İşlenmişse buna ilişkin bilgi talep etme
c) İşlenme amacını ve amacına uygun kullanılıp kullanılmadığını öğrenme
ç) Yurt içinde veya yurt dışında kişisel verilerinizin aktarıldığı üçüncü kişileri bilme
d) Eksik veya yanlış işlenmiş ise düzeltilmesini isteme
e) KVKK Madde 7 çerçevesinde silinmesini veya yok edilmesini isteme
f) (d) ve (e) kapsamındaki işlemlerin aktarılan üçüncü kişilere bildirilmesini isteme
g) Otomatik sistemler vasıtasıyla analiz sonucu aleyhinize bir kararın oluşmasına itiraz etme
ğ) Kanuna aykırı işleme nedeniyle zarara uğramanız halinde tazminat talep etme'''),
          const _LegalSection('9. Başvuru Yöntemi ve Yanıt Süresi', '''
Haklarınızı kullanmak için:

• E-posta: $_kPrivacyEmail
  Konu satırı: "KVKK Madde 11 Başvurusu"
  Kimliğinizi doğrulayan bilgileri (ad, e-posta) ekleyin.

• Uygulama içi: Ayarlar → Gizlilik → KVKK Başvurusu

Başvurular en geç 30 (otuz) gün içinde yanıtlanır (KVKK Madde 13). Başvurunun reddedilmesi veya 30 gün içinde yanıt alınamaması halinde Kişisel Verileri Koruma Kurumu'na (www.kvkk.gov.tr) şikâyette bulunabilirsiniz.'''),
          const SizedBox(height: 8),
          _ExternalLinkButton(
            label: 'KVK Kurumu',
            url: 'https://www.kvkk.gov.tr',
          ),
          const SizedBox(height: 12),
          _ExternalLinkButton(
            label: 'KVKK Başvurusu Gönder',
            url: 'mailto:$_kPrivacyEmail?subject=KVKK%20Madde%2011%20Ba%C5%9Fvurusu',
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
