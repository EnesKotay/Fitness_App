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

## App Store Metadata - PusulaFit

App Store Connect > Distribution > iOS App Version ekraninda kullanilacak metinler:

### Promotional Text

```text
PusulaFit ile antrenmanını planla, beslenmeni takip et ve hedeflerine akıllı koç desteğiyle ilerle.
```

### Description

```text
PusulaFit, antrenman, beslenme ve gelişim takibini tek yerde birleştiren yapay zeka destekli fitness asistanıdır. Hedefine uygun planlar oluştur, günlük kalorini ve makrolarını takip et, antrenmanlarını kaydet ve ilerlemeni anlaşılır grafiklerle gör.

ANTRENMAN
- Hedefine göre kişiselleştirilmiş haftalık planlar
- Egzersiz ve set takibi
- Antrenman geçmişi ve gelişim kayıtları

BESLENME
- Kalori, protein, karbonhidrat ve yağ takibi
- Türk mutfağına uygun yemek kayıtları
- Barkod, etiket ve yemek fotoğrafı ile pratik kayıt
- Su ve öğün takibi

AI KOÇ
- Hedeflerine göre öneriler
- Antrenman ve beslenme sorularına kişisel yanıtlar
- Premium kullanıcılar için gelişmiş analizler ve haftalık planlar

GELİŞİM
- Kilo, vücut ölçüsü ve ilerleme takibi
- Haftalık raporlar
- Motivasyon görevleri ve seri takibi

PusulaFit tıbbi tavsiye sunmaz; sağlıklı yaşam ve fitness takibi için destek aracıdır. Sağlık durumunla ilgili kararlar için bir uzmana danış.
```

### Keywords

```text
fitness,antrenman,beslenme,diyet,kalori,makro,egzersiz,spor,kilo,sağlık,ai koç,pusulafit
```

### URLs

```text
Support URL: https://pusulafit-landing.onrender.com
Marketing URL: https://pusulafit-landing.onrender.com
```

### Copyright

```text
© 2026 PusulaFit
```
