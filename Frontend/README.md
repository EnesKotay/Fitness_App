# Fitness App

Kişiselleştirilmiş antrenman ve beslenme deneyimi sunan, yapay zeka (Google Gemini) destekli fitness uygulaması.

## ✨ Öne Çıkan Özellikler

- **🏋️ Antrenman Takibi:** Güç ve kardiyo egzersizlerinizi takip edin, setleri ve tekrarları kaydedin.
- **🏆 Kişisel Rekorlar (PR):** Egzersiz bazlı maksimum ağırlıklarınızı (PR) ve gelişim trendinizi otomatik ölçer.
- **❤️ Toparlanma Skoru:** Uyku, su tüketimi ve bölgesel kas yorgunluğunu analiz ederek antrenmana ne kadar hazır olduğunuzu hesaplar.
- **🥗 Akıllı Beslenme:** Kalori ve makro hedeflerinizi takip edin, akıllı öneriler alın.
- **🤖 AI Koç (Gemini):** Tüm antrenman, kilo ve beslenme verilerinizi sentezleyerek size o güne özel aksiyon planı ve tavsiyeler çıkarır.

## 🚀 AI (Gemini) Kurulumu

Uygulamanın sohbet asistanı ve akıllı koçluk özelliklerinin çalışması için API anahtarı gereklidir:

1. **API Anahtarı Al:** [Google AI Studio](https://aistudio.google.com/app/apikey) üzerinden "Create API key" ile ücretsiz anahtar oluşturun.
2. **.env Dosyası:** Proje kök dizininde (pubspec.yaml ile aynı yerde) bir `.env` dosyası oluşturun.
3. İçerisine anahtarınızı ekleyin:
   ```env
   GEMINI_API_KEY=buraya_aldigin_anahtari_yapistir
   ```
4. Projeyi çalıştırın: `flutter run`

*(Not: `.env` dosyası yoksa veya anahtar girilmemişse uygulama çalışmaya devam eder ancak AI özellikleri (Yapay Zeka Koçu) pasif olur.)*

## 🛠 Geliştirme (Getting Started)

- Projeyi klonladıktan sonra bağımlılıkları yüklemek için: `flutter pub get`
- Uygulamayı çalıştırmak için: `flutter run`

Daha fazla Flutter dokümantasyonu için: [docs.flutter.dev](https://docs.flutter.dev/)
