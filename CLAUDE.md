# FitMentor — Claude Code Kılavuzu

## Uygulama Hakkında

**FitMentor** bir Flutter tabanlı fitness takip uygulaması.
Platform: iOS + Android | Dil: Dart/Flutter | State: Provider

---

## iOS Simülatör Test Protokolü

Claude'un uygulamayı otonom test etmesi için bu adımları izle:

### 1. Simülatörü Başlat ve Uygulamayı Çalıştır

```bash
# Simülatör ID'sini al
xcrun simctl list devices | grep -E "iPhone.*Booted|iPhone 1[5-9]"

# Uygulamayı Flutter ile başlat (bir kez yapılır)
cd /Users/eneskotay/Development/Fitness_App-main/Frontend
flutter run -d "iPhone 16e" --dart-define=FLUTTER_TEST_MODE=true

# Veya zaten çalışıyorsa bundle ID ile launch et
xcrun simctl launch booted com.example.fitness
```

### 2. Ekran Görüntüsü Al ve Analiz Et

```bash
# Anlık ekran görüntüsü al
xcrun simctl io booted screenshot /tmp/fitmentor_screen.png
```
Sonra bu dosyayı Read tool ile oku: `/tmp/fitmentor_screen.png`

### 3. UI ile Etkileşim (Koordinat Bazlı)

```bash
# Dokunma (iPhone 16e: 393x852 nokta)
xcrun simctl io booted tap <X> <Y>

# Kaydırma (yukarı)
xcrun simctl io booted swipe 200 600 200 200

# Kaydırma (aşağı)
xcrun simctl io booted swipe 200 200 200 600

# Geri git (sol kenardan sağa swipe)
xcrun simctl io booted swipe 10 400 300 400

# Text gir (klavye açıkken)
xcrun simctl io booted type "test_user_text"

# Home butonu
xcrun simctl io booted button home
```

### 4. Erişilebilirlik Ağacını Oku (Flutter Semantics)

```bash
# Flutter widget tree (uygulama çalışıyorken)
# Bu yöntem daha doğru semantik bilgi verir:
idb --udid <UDID> accessibility-info-at-point <X> <Y>

# Veya tüm ağacı dump et:
flutter attach --device-id <DEVICE_ID>
# Sonra flutter inspector kullan
```

---

## Ekran Haritası ve Test Koordinatları

**Cihaz: iPhone 16e — 393×852 nokta**

### Kimlik Doğrulama Akışı

| Ekran | Route | Tetikleyici |
|-------|-------|-------------|
| Splash | (başlangıç) | Otomatik |
| Login | `/login` | Splash → login yönlendirme |
| Onboarding | `/onboarding` | İlk kurulum |
| Profil Kurulum | `/profile-setup` | Login → profil yok |

**Login Ekranı Koordinatları (yaklaşık):**
- Email field: `(196, 300)`
- Şifre field: `(196, 380)`
- Giriş Yap butonu: `(196, 460)`
- Şifremi Unuttum: `(196, 520)`

### Ana Tab Bar (Alt Navigasyon)

| Tab | İkon | Koordinat |
|-----|------|-----------|
| Ana Sayfa | 🏠 | `(50, 830)` |
| Antrenman | 💪 | `(130, 830)` |
| Takip | 📈 | `(260, 830)` |
| Beslenme | 🍽️ | `(340, 830)` |

### Sayfa Rotaları

```
/login              → LoginScreen
/onboarding         → OnboardingPage
/home               → MainShell (Tab Container)
  ├── Tab 0: Ana Sayfa   → DashboardScreen
  ├── Tab 1: Antrenman   → WorkoutScreen
  ├── Tab 2: Takip       → TrackingScreen
  └── Tab 3: Beslenme    → DietTabContainer
/ai-coach           → AiCoachScreen
/weekly-plan        → WeeklyPlanScreen
/daily-tasks        → DailyTasksScreen
/profile            → ProfileScreen
/profile-setup      → ProfileSetupPage
/settings-password  → SettingsPasswordScreen
/settings-notifications → SettingsNotificationsScreen
/settings-privacy   → SettingsPrivacyScreen
/settings-nutrition → SettingsNutritionScreen
/settings-theme     → SettingsThemeScreen
/settings-help      → SettingsHelpScreen
/achievements       → AchievementsScreen
/forgot-password    → ForgotPasswordScreen
```

---

## Otonom Test Akışları

### Test Akışı A: Tam Uygulama Turu

```
1. Ekran görüntüsü al → hangi ekrandasın anla
2. Login ekranı görüyorsan:
   - Demo/test hesabıyla giriş yap
   - veya kayıt ol
3. Ana ekrana ulaşınca:
   a. Dashboard'u tara (scroll et, içerikleri kaydet)
   b. Tab 1 → Antrenman: antrenman ekle/görüntüle
   c. Tab 2 → Takip: grafikleri incele
   d. Tab 3 → Beslenme: yiyecek ara, ekle
4. Üst sağ köşe FAB'a bas → AI Coach'u aç
5. AI Coach'ta bir soru sor
6. Geri dön, Haftalık Plan'ı kontrol et
7. Görevler ekranını aç
8. Profil → Ayarlar → her ayar ekranını ziyaret et
9. Başarımlar ekranını aç
```

### Test Akışı B: Kritik Path (Login → Workout → Nutrition)

```
1. Login (email + şifre gir → giriş yap butonu)
2. Dashboard yüklenince screenshot al
3. Antrenman tab'ına geç
4. "+" butonu ile antrenman ekle
5. Beslenme tab'ına geç
6. Yiyecek ara (search bar'a yaz)
7. Bir yiyecek seç ve ekle
8. AI Coach'u aç, günlük özet iste
```

### Test Akışı C: Hata Tespiti

Her ekranda şunları kontrol et:
- [ ] Boş state görünüyor mu? (veri yokken)
- [ ] Loading spinner çalışıyor mu?
- [ ] Hata mesajları okunaklı mı?
- [ ] Back navigasyonu çalışıyor mu?
- [ ] Keyboard popup ve dismiss doğru mu?

---

## Otonom Test Çalıştırma Talimatı

Claude'a şunu söyle:

```
iOS simülatörde FitMentor uygulamasını test et. 
Her adımdan önce screenshot al (/tmp/screen_NNN.png), 
ekranı analiz et, sonraki aksiyonu belirle.
Bulgularını yapılandırılmış bir rapor olarak sun:
- Ziyaret edilen ekranlar
- Tespit edilen bug'lar
- UI/UX sorunları
- Başarıyla çalışan akışlar
```

---

## Proje Yapısı

```
Frontend/
├── lib/
│   ├── core/
│   │   ├── api/          → API client ve servisler
│   │   ├── models/       → Veri modelleri
│   │   ├── routes/       → app_routes.dart (tüm rotalar burada)
│   │   ├── theme/        → Tema
│   │   └── widgets/      → Ortak widget'lar
│   └── features/
│       ├── ai_coach/     → AI Antrenör (Gemini)
│       ├── auth/         → Giriş/Kayıt/Profil/Ayarlar
│       ├── home/         → Dashboard
│       ├── nutrition/    → Beslenme takibi
│       ├── onboarding/   → İlk kurulum
│       ├── recipes/      → Tarifler
│       ├── shell/        → Ana tab container
│       ├── tasks/        → Günlük görevler
│       ├── tracking/     → İlerleme takibi
│       ├── weight/       → Kilo takibi
│       └── workout/      → Antrenman
├── test/                 → Unit ve widget testler
├── integration_test/     → Entegrasyon testleri
└── assets/               → Görseller, fontlar, veriler
```

## Önemli Dosyalar

- `lib/core/routes/app_routes.dart` — Tüm rotalar
- `lib/features/shell/main_shell.dart` — Tab bar ve navigasyon
- `lib/main.dart` — Uygulama başlangıcı ve auth flow
- `lib/core/api/api_client.dart` — Backend API bağlantısı
- `lib/features/auth/providers/auth_provider.dart` — Kimlik doğrulama state

## Geliştirme Notları

- State management: Provider paketi
- API: Dio HTTP client
- Local storage: SharedPreferences + Hive + flutter_secure_storage
- AI: Google Generative AI (Gemini)
- Monitoring: Sentry
- Backend endpoint: `ApiClient` içinde tanımlı
