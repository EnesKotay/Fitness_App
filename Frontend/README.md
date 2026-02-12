# fitness

Fitness ve beslenme takip uygulaması.

## AI (Gemini) Kurulumu

Sohbet asistanı ve akıllı yemek önerisi için:

1. **API anahtarı al:** [Google AI Studio](https://aistudio.google.com/app/apikey) → "Create API key" (ücretsiz).
2. **Proje kökünde** (pubspec.yaml ile aynı klasörde) `.env` dosyası oluştur.
3. İçine ekle:
   ```env
   GEMINI_API_KEY=buraya_aldigin_anahtari_yapistir
   ```
4. Uygulamayı **proje klasöründen** çalıştır: `flutter run`.

`.env` yoksa veya anahtar boşsa uygulama yine açılır; AI özellikleri devre dışı kalır.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
