# iPhone 17 Simulator'da Çalıştırma (MLKit / Rosetta)

Bu projede **Google MLKit** (barkod, metin tanıma) kullanıldığı için simulator sadece **x86_64** (Rosetta) ile çalışır. Aşağıdaki adımları uygula.

## 1. Universal simulator runtime (tek seferlik)

Terminal'de:

```bash
# Xcode 26 ile çalıştığından emin ol
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# iOS simulator için Universal (arm64 + x86_64) runtime indir
xcodebuild -downloadPlatform iOS -architectureVariant universal
```

İndirme bitince Xcode’u kapatıp tekrar aç.

## 2. DerivedData temizle

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

## 3. Uygulamayı simulator’da çalıştır

```bash
cd /Users/eneskotay/Desktop/Fitness_App-main/Frontend
flutter run -d "iPhone 17"
```

Projede **EXCLUDED_ARCHS[sdk=iphonesimulator*]=arm64** ayarı var; simulator build’i x86_64 (Rosetta) olur ve MLKit ile uyumludur.

## Hâlâ hata alırsan

- **"Unsupported Swift architecture"**  
  Xcode 26 bazen x86_64 simulator’ı şikayet eder. O zaman:
  - **macOS’ta çalıştır:** `flutter run -d macos`
  - veya **gerçek iPhone:** `flutter run -d "Enes can iPhone'u"`

- **"Framework Pods_Runner not found"**  
  Scheme düzeltmesi yapıldı; tekrar denemeden önce:
  ```bash
  cd ios && pod install && cd ..
  flutter run -d "iPhone 17"
  ```
