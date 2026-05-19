# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# PusulaFit — Claude Code Kılavuzu

## Uygulama Hakkında

**PusulaFit** bir Flutter tabanlı fitness takip uygulaması.
Platform: iOS + Android | Frontend: Dart/Flutter (Provider) | Backend: Quarkus (Java) + PostgreSQL

---

## Build & Run Komutları

### Frontend (Flutter)

```bash
cd /Users/eneskotay/Development/Fitness_App-main/Frontend

# iOS simülatörde çalıştır
flutter run -d "iPhone 16e" --dart-define=FLUTTER_TEST_MODE=true

# Android emülatörde çalıştır
flutter run -d emulator-5554

# Release build (iOS)
flutter build ios --release

# Release build (Android)
flutter build appbundle --release

# Bağımlılıkları yükle
flutter pub get

# Kod analizi
flutter analyze

# Testleri çalıştır (unit + widget)
flutter test

# Tek test dosyası çalıştır
flutter test test/features/nutrition/diet_provider_test.dart

# Integration test
flutter test integration_test/

# Kod üretici (freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs

# CocoaPods sorunu olursa
rm -rf ios/.symlinks/
cd ios && pod install && cd ..
```

### Backend (Quarkus)

```bash
cd /Users/eneskotay/Development/Fitness_App-main/backend

# Dev mode (hot reload)
./mvnw quarkus:dev

# Testleri çalıştır
./mvnw test

# Production build
./mvnw package -Pnative

# Docker image
docker build -f src/main/docker/Dockerfile.jvm -t pusulafit-backend .
```

---

## Mimari Genel Bakış

### Frontend Mimarisi

```
lib/
├── main.dart              → Hive init, Sentry init, MultiProvider, auth flow
├── core/
│   ├── api/api_client.dart         → Dio HTTP client (base URL, JWT interceptor)
│   ├── models/                     → Shared data models
│   ├── routes/app_routes.dart      → Tüm rotalar (onGenerateRoute)
│   ├── services/ai_service.dart    → Gemini API wrapper (isReady her zaman true)
│   └── theme/                      → AppTheme
└── features/
    ├── shell/
    │   ├── app_providers.dart      → Root MultiProvider (tüm Provider'lar burada)
    │   └── main_shell.dart         → Tab bar + nested navigator yönetimi
    ├── auth/
    │   └── providers/auth_provider.dart  → JWT, login, logout, profil state
    ├── ai_coach/
    │   ├── controllers/ai_coach_controller.dart  → ChangeNotifier, son 12 mesaj history
    │   └── services/ai_coach_service.dart        → Backend /ai/coach endpoint
    ├── nutrition/
    │   ├── presentation/state/diet_provider.dart          → ChangeNotifierProxyProvider3
    │   └── presentation/widgets/meal_suggestion_sheet.dart → AI öğün önerisi (4700+ satır)
    ├── workout/   → Antrenman CRUD
    ├── tracking/  → İlerleme grafikleri
    ├── weight/    → Kilo takibi
    └── tasks/     → Günlük görevler
```

**State akışı:** `app_providers.dart` içindeki `MultiProvider` root'ta sarılıdır. `DietProvider`, `ChangeNotifierProxyProvider3<WeightProvider, WorkoutProvider, AIService, DietProvider>` olarak kayıtlıdır — yani `WeightProvider` veya `WorkoutProvider` değişince `DietProvider` de güncellenir.

**Navigasyon:** Root `MaterialApp` (named routes) + `DietTabContainer` içinde kendi `GlobalKey<NavigatorState>` ile nested navigator. `showMealSuggestionSheet` bu nested navigator'a push eder.

### Backend Mimarisi

```
backend/src/main/java/com/fitness/
├── resource/          → JAX-RS controllers (@Path, @GET, @POST)
├── service/
│   ├── AiProviderRouter.java   → AI yönlendirme (free→Gemini, premium→Claude)
│   ├── GeminiCoachService.java → Google Gemini API entegrasyonu
│   └── ClaudeCoachService.java → Anthropic Claude API entegrasyonu
├── entity/            → Hibernate PanacheEntity (@Entity)
├── repository/        → PanacheRepository
└── dto/               → Request/Response DTO'ları

resources/
├── application.properties      → Tüm konfigürasyon (DB, JWT, AI model)
└── db/migration/               → Flyway: V2__init.sql → V12__...sql
```

**AI Yönlendirme (`AiProviderRouter.java`):**
- Free kullanıcılar → `gemini-2.5-flash` (Gemini API)
- Premium kullanıcılar → Claude API (Anthropic)
- Premium kontrolü: `user.premiumTier == "premium"` AND `premiumExpiresAt` henüz geçmemiş

**JWT:** SmallRye JWT, 7 günlük token (`smallrye.jwt.new-token.lifespan=604800`)

**Database:** PostgreSQL, Flyway migration V2→V12 (V1 yoktur, V2'den başlar)

---

## Önemli Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `Frontend/lib/main.dart` | App başlangıcı, Hive/Sentry init, auth akışı |
| `Frontend/lib/features/shell/app_providers.dart` | Root MultiProvider — tüm provider kayıtları |
| `Frontend/lib/core/routes/app_routes.dart` | Tüm named route tanımları |
| `Frontend/lib/features/shell/main_shell.dart` | Tab bar + nested navigator yönetimi |
| `Frontend/lib/core/api/api_client.dart` | Dio HTTP client, JWT interceptor |
| `Frontend/lib/features/auth/providers/auth_provider.dart` | Auth state, login/logout |
| `Frontend/lib/features/ai_coach/controllers/ai_coach_controller.dart` | AI Coach ChangeNotifier, 12 mesaj history |
| `Frontend/lib/features/nutrition/presentation/state/diet_provider.dart` | Beslenme state, makro hedefleri |
| `backend/src/main/java/com/fitness/service/AiProviderRouter.java` | Free/premium AI yönlendirme |
| `backend/src/main/resources/application.properties` | DB, JWT, Gemini model konfigürasyonu |

---

## Geliştirme Notları

**Flutter paketler:**
- State: `provider`
- HTTP: `dio`
- Local storage: `shared_preferences` + `hive` + `flutter_secure_storage`
- AI: `google_generative_ai` (Gemini)
- Monitoring: `sentry_flutter`

**Kritik davranışlar:**
- `DietProvider.macroTargets`: `carbG` sıfır olabilir eğer protein+fat toplamı toplam kcal'ı aşarsa — bölme öncesi kontrol et
- `DietProvider.addEntry()`: catch bloğu `rethrow` eder; UI'de try-catch ile sarılmalı
- `AiCoachController._buildConversationMemory()`: son 12 mesajı tutar, daha eskiler atılır
- Beslenme tab'ı kendi nested navigator'ını kullanır; `meal_suggestion_sheet.dart`'daki `showMealSuggestionSheet` bunu kullanır

**Flyway migration kuralı:** V1 atlanmıştır; en son migration V12'dir. Yeni migration eklerken `V13__description.sql` ile devam et.

---

## iOS Simülatör Test Protokolü

### Başlatma

```bash
# Simülatör ID'sini al
xcrun simctl list devices | grep -E "iPhone.*Booted|iPhone 1[5-9]"

# Uygulamayı başlat
cd /Users/eneskotay/Development/Fitness_App-main/Frontend
flutter run -d "iPhone 16e" --dart-define=FLUTTER_TEST_MODE=true

# Zaten çalışıyorsa
xcrun simctl launch booted com.example.fitness
```

### Etkileşim Komutları (iPhone 16e: 393×852 pt)

```bash
xcrun simctl io booted screenshot /tmp/pusulafit_screen.png
xcrun simctl io booted tap <X> <Y>
xcrun simctl io booted swipe 200 600 200 200   # yukarı kaydır
xcrun simctl io booted swipe 200 200 200 600   # aşağı kaydır
xcrun simctl io booted swipe 10 400 300 400    # geri (sol→sağ)
xcrun simctl io booted type "metin"
xcrun simctl io booted button home
```

### Ekran Koordinatları

**Login:**
- Email: `(196, 300)` | Şifre: `(196, 380)` | Giriş: `(196, 460)`

**Ana Tab Bar (alt):**
| Tab | Koordinat |
|-----|-----------|
| Ana Sayfa | `(50, 830)` |
| Antrenman | `(130, 830)` |
| Takip | `(260, 830)` |
| Beslenme | `(340, 830)` |

### Sayfa Rotaları

```
/login              → LoginScreen
/onboarding         → OnboardingPage
/home               → MainShell
  ├── Tab 0         → DashboardScreen
  ├── Tab 1         → WorkoutScreen
  ├── Tab 2         → TrackingScreen
  └── Tab 3         → DietTabContainer (nested navigator)
/ai-coach           → AiCoachScreen
/weekly-plan        → WeeklyPlanScreen
/daily-tasks        → DailyTasksScreen
/profile            → ProfileScreen
/profile-setup      → ProfileSetupPage
/achievements       → AchievementsScreen
/forgot-password    → ForgotPasswordScreen
/settings-password  → SettingsPasswordScreen
/settings-notifications → SettingsNotificationsScreen
/settings-privacy   → SettingsPrivacyScreen
/settings-nutrition → SettingsNutritionScreen
/settings-theme     → SettingsThemeScreen
/settings-help      → SettingsHelpScreen
```

### Otonom Test Talimatı

```
iOS simülatörde PusulaFit uygulamasını test et.
Her adımdan önce screenshot al (/tmp/screen_NNN.png),
ekranı analiz et, sonraki aksiyonu belirle.
Bulgularını yapılandırılmış rapor olarak sun:
- Ziyaret edilen ekranlar
- Tespit edilen bug'lar
- UI/UX sorunları
- Başarıyla çalışan akışlar
```
