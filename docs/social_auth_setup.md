# Social Auth Setup

Bu repo artık backend doğrulamalı Google ve Apple giriş akışını içeriyor.

## Mevcut kimlikler

- Android application id: `com.pusulafit.tracker`
- iOS bundle id: `com.eneskotay.pusulafit`

## Backend env

`backend/.env` veya deploy ortamında şu değişkenleri tanımlayın:

```env
AUTH_GOOGLE_ALLOWED_CLIENT_IDS=976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com,976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com
AUTH_APPLE_ALLOWED_AUDIENCES=com.eneskotay.pusulafit
```

Apple girişini Android/web üstünden de açacaksanız:

```env
AUTH_APPLE_ALLOWED_AUDIENCES=com.eneskotay.pusulafit,com.eneskotay.pusulafit.signin
```

## Flutter dart-define

Google girişi için build/run komutuna en az şu değerleri ekleyin:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8081 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com
```

Apple girişi şu an UI'da iOS için açıldı. Android tarafında da açmak isterseniz ayrıca:

```bash
flutter run \
  --dart-define=APPLE_SERVICE_ID=com.eneskotay.pusulafit.signin \
  --dart-define=APPLE_REDIRECT_URI=https://your-domain.com/auth/apple/callback
```

## Apple tarafı

Gerekli manuel adımlar:

1. Apple Developer hesabında `Sign In with Apple` capability'sini etkinleştirin.
2. `com.eneskotay.pusulafit` bundle id'si için capability'nin aktif olduğundan emin olun.
3. Xcode'da Runner target altında Signing & Capabilities bölümünde `Sign In with Apple` göründüğünü kontrol edin.
4. App Store'a çıkmadan önce provisioning profile'ı capability açıldıktan sonra yeniden oluşturun veya Xcode'un otomatik imzalama ile yenilemesini sağlayın.

Repo içinde `frontend/ios/Runner/Runner.entitlements` eklendi ve target build ayarlarına bağlandı.

## Google tarafı

Gerekli manuel adımlar:

1. Google Cloud Console'da OAuth client'ları oluşturun.
2. Web client id'yi `GOOGLE_SERVER_CLIENT_ID` içinde kullanın.
3. iOS client id'yi `GOOGLE_IOS_CLIENT_ID` içinde kullanın.
4. Backend'de `AUTH_GOOGLE_ALLOWED_CLIENT_IDS` içine Web client id ve iOS client id'yi virgülle ayırarak yazın.
5. Android release imzası kullanıyorsanız Android OAuth client oluşturup SHA-1/SHA-256 fingerprint'leri Google Cloud Console'a ekleyin.

## Local test

Backend dev portu `8081`:

```bash
cd backend
./run-backend.sh
```

Test endpoint:

```text
http://127.0.0.1:8081/api/auth/test
```

Frontend:

```bash
cd frontend
flutter run \
  --dart-define=API_BASE_URL=http://127.0.0.1:8081 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com
```

## Production checklist

1. Production backend'e yeni social auth kodunu deploy edin.
2. Production backend env'e şunları ekleyin:

```env
AUTH_GOOGLE_ALLOWED_CLIENT_IDS=976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com,976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com
AUTH_APPLE_ALLOWED_AUDIENCES=com.eneskotay.pusulafit
```

3. App Store build komutunda production API URL'ini verin:

```bash
flutter build ipa \
  --dart-define=API_BASE_URL=https://fitness-backend-jrcn.onrender.com \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com \
  --dart-define=GOOGLE_IOS_CLIENT_ID=976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com
```

4. Google OAuth consent screen'i test bitince `Production` moduna alın.
5. Apple Developer'da `Sign in with Apple` capability aktif ve provisioning profile güncel olsun.

## Hazır değerler

- `GOOGLE_IOS_CLIENT_ID`: `976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com`
- `GOOGLE_SERVER_CLIENT_ID`: `976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com`
- `AUTH_GOOGLE_ALLOWED_CLIENT_IDS`: `976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com,976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com`

Not:
- Google giriş deneyecek Gmail hesaplarını Google Cloud `Audience > Test users` kısmına ekleyin.
- `Client secret` bu mobil akışta kullanılmıyor.
