# Ödeme Sistemi Kurulum Rehberi (RevenueCat)

Ödeme sistemi RevenueCat tabanlı olarak yeniden yazıldı (Temmuz 2026).
Kod tarafı tamam — aşağıdaki konsol adımları **senin tarafında** yapılmalı.
Adımları sırayla yap; her bölüm bir öncekine bağlı.

## Mimari Özet

```
Flutter (purchases_flutter SDK)
   │  satın alma → App Store / Google Play
   │  app_user_id = backend users.id (login'de otomatik eşlenir)
   ▼
RevenueCat  ← makbuz doğrulama, abonelik takibi burada
   │
   ├─ Uygulama satın alma sonrası → POST /api/user/premium/sync
   │     (Supabase, RevenueCat REST API'den entitlement'ı çeker, DB'yi günceller)
   │
   └─ Webhook → POST /api/webhooks/revenuecat
         (yenileme, iptal, süre bitişi otomatik işlenir)
```

- Entitlement ID: **`premium`** (RevenueCat'te birebir bu isimle açılmalı)
- Ürün ID'leri: **`premium_monthly`**, **`premium_yearly`**

---

## ADIM 1 — App Store Connect

1. **Ödeme sözleşmesi**: Business (Agreements, Tax, and Banking) →
   "Paid Apps" sözleşmesi **Active** olmalı. Banka + vergi bilgileri eksikse
   ürünler asla yüklenmez (şu anki "fiyatlar gelmiyor" sorununun en olası sebebi).

2. **Abonelik grubu ve ürünler**: My Apps → PusulaFit → Monetization →
   Subscriptions:
   - Subscription Group oluştur (ör. "PusulaFit Premium")
   - Grup içine iki abonelik ekle:
     - Product ID: `premium_monthly` — süre: 1 ay — fiyat: ₺149,99
     - Product ID: `premium_yearly` — süre: 1 yıl — fiyat: ₺799,99
   - Her ürüne en az bir **localization** (Türkçe ad + açıklama) ekle
   - Durumları "Ready to Submit" olmalı.
   - ⚠️ İlk IAP ürünleri, bir app binary'siyle birlikte incelemeye gönderilir —
     App Review'a giderken "In-App Purchases" bölümünde ürünleri seçmeyi unutma.

3. **In-App Purchase Key** (RevenueCat'in Apple ile konuşması için):
   Users and Access → Integrations → In-App Purchase → **Generate In-App Purchase Key**
   - `.p8` dosyasını indir (bir kez indirilebilir!)
   - Key ID ve Issuer ID'yi not al.

## ADIM 2 — RevenueCat Dashboard

[app.revenuecat.com](https://app.revenuecat.com) → hesap aç (aylık ~20.000$ gelire kadar ücretsiz).

1. **Proje**: "PusulaFit" projesi oluştur.
2. **App ekle**: Project → Apps → App Store →
   Bundle ID: `com.eneskotay.fitnessapp`
   → ADIM 1.3'teki `.p8` dosyası + Key ID + Issuer ID'yi yükle.
3. **Ürünler**: Product catalog → Products → New →
   `premium_monthly` ve `premium_yearly` (App Store'dan import edebilirsin).
4. **Entitlement** (KRİTİK): Product catalog → Entitlements → New →
   Identifier: **`premium`** (kod birebir bunu arıyor)
   → iki ürünü de bu entitlement'a bağla.
5. **Offering**: Offerings → `default` offering → Packages:
   - `$rc_annual` paketi → `premium_yearly`
   - `$rc_monthly` paketi → `premium_monthly`
6. **API anahtarları**: Project Settings → API Keys:
   - **Public** iOS anahtarı (`appl_...`) → ADIM 3'te Flutter'a
   - **Secret** anahtar (`sk_...`) → ADIM 4'te Supabase'e
7. **Webhook**: Project → Integrations → Webhooks → Add:
   - URL: `https://ibbwfkjrmxdksnalivum.supabase.co/functions/v1/api/webhooks/revenuecat`
   - Authorization header value: güçlü rastgele bir değer üret
     (ör. `openssl rand -hex 32` çıktısı) — aynı değer ADIM 4'te
     `REVENUECAT_WEBHOOK_AUTH` olarak Supabase'e girilecek.

## ADIM 3 — Flutter API Anahtarı

`Frontend/lib/core/constants/revenuecat_keys.dart` dosyasında:

```dart
static const String _iosFallback = 'appl_REPLACE_ME';  // ← appl_... anahtarını yapıştır
```

veya build sırasında geç:

```bash
flutter build ipa --dart-define=REVENUECAT_IOS_API_KEY=appl_XXXX
```

## ADIM 4 — Supabase Secrets + Deploy

```bash
cd /Users/eneskotay/Development/Fitness_App-main

# Secrets (sk_... = RevenueCat secret key, webhook auth = ADIM 2.7'deki değer)
supabase secrets set \
  REVENUECAT_SECRET_API_KEY=sk_XXXX \
  REVENUECAT_WEBHOOK_AUTH='WEBHOOK_AUTH_DEGERI' \
  --project-ref ibbwfkjrmxdksnalivum

# Eski dev modu kapat (varsa) — artık gerçek doğrulama yapılıyor
supabase secrets unset IAP_VERIFY_MODE --project-ref ibbwfkjrmxdksnalivum

# Function'ı deploy et
supabase functions deploy api --project-ref ibbwfkjrmxdksnalivum
```

> Store kurulumu bitmeden uçtan uca akışı denemek istersen geçici olarak
> `IAP_VERIFY_MODE=dev` set edebilirsin — bu modda backend doğrulama yapmadan
> premium açar. **Yayına çıkarken mutlaka kaldır.**

## ADIM 5 — iOS Sandbox Testi

1. App Store Connect → Users and Access → **Sandbox Testers** → test hesabı oluştur.
2. **Gerçek iPhone** kullan (simülatörde StoreKit/sandbox güvenilir çalışmaz):
   - Cihazda: Ayarlar → App Store → Sandbox Account → test hesabıyla gir.
   - Xcode'dan cihaza run et veya TestFlight build'i yükle.
3. Test akışı:
   - Uygulamaya giriş yap → Premium ekranını aç
   - Fiyatlar App Store'dan gelmiş olmalı (fallback "149₺" yerine gerçek mağaza formatı)
   - Satın al → Apple sandbox ödeme ekranı → onayla
   - "Premium aktivasyonu başarılı" görmeli, premium rozeti açılmalı.
4. Doğrulama:
   - RevenueCat dashboard → Customers → user ID'n görünmeli, entitlement `premium` aktif
   - Supabase → users tablosunda `premium_tier = premium`, `premium_expires_at` dolu.
5. Sandbox'ta abonelikler hızlandırılmış yenilenir (aylık ≈ 5 dk) —
   yenileme webhook'unun çalıştığını RevenueCat → Integrations → Webhooks
   → event geçmişinden izleyebilirsin.

## Android (sonraki faz)

iOS bittikten sonra: Play Console'da aynı ID'lerle subscription oluştur,
RevenueCat'e Play Store app ekle (service account JSON ile),
`revenuecat_keys.dart` içine `goog_...` anahtarını koy. Kod hazır.

## Sorun Giderme

| Belirti | Muhtemel sebep |
|---|---|
| Fiyatlar yüklenmiyor | Paid Apps sözleşmesi aktif değil / ürünler "Missing Metadata" / RevenueCat offering boş |
| "Abonelik sistemi yapılandırılmamış" | `revenuecat_keys.dart` içinde hâlâ `REPLACE_ME` |
| Ödeme geçti, premium açılmadı | RevenueCat'te `premium` entitlement'ına ürünler bağlanmamış veya Supabase secret eksik |
| Webhook 401 | RevenueCat'teki Authorization değeri ile `REVENUECAT_WEBHOOK_AUTH` farklı |
