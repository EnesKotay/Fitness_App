# App Store Release Checklist

Bu dosya, production sunucu kurulmadan once kod tarafinda hazirlanan App Store oncesi kontrol listesidir.

## Kod Tarafinda Hazirlananlar

- Uygulama ici gercek hesap silme akisi eklendi
- Yasal baglantilar `dart-define` ile konfigurasyonlu hale getirildi
- Premium restore akisi zaten mevcut
- Privacy ayarlari ve veri disa aktarma ekrani mevcut

## Build Sirasinda Verilmesi Gereken Degiskenler

```bash
flutter build ipa \
  --dart-define=API_BASE_URL=https://api.senin-domainin.com \
  --dart-define=APP_PRIVACY_URL=https://senin-domainin.com/privacy \
  --dart-define=APP_TERMS_URL=https://senin-domainin.com/terms \
  --dart-define=APP_SUPPORT_URL=https://senin-domainin.com/support \
  --dart-define=APP_PRIVACY_EMAIL=privacy@senin-domainin.com \
  --dart-define=APP_LEGAL_EMAIL=legal@senin-domainin.com \
  --dart-define=SENTRY_DSN=https://examplePublicKey@o0.ingest.sentry.io/0
```

## Production Sunucu Hazir Olunca Kontrol Et

- `API_BASE_URL` gercek HTTPS domainine bakiyor mu
- App Store sandbox ve production IAP dogrulama ayarlari tamam mi
- App Review icin backend public olarak erisilebilir mi
- Demo reviewer hesabi hazir mi
- Privacy Policy, Terms ve Support sayfalari canli mi
- Sifre sifirlama mail servisi production ortaminda calisiyor mu

## App Store Connect Tarafinda Tamamlanacaklar

- Privacy Nutrition / Health benzeri veriler dogru isaretlendi mi
- Support URL eklendi mi
- Privacy Policy URL eklendi mi
- Screenshots yuklendi mi
- In-App Purchase urunleri onayli ve build'e bagli mi
- Review notes icinde demo hesap ve premium test adimlari yazildi mi

