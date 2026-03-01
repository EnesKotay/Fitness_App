#!/bin/bash
# "Framework Pods_Runner not found" hatası için: tam temizlik + pod install
# Kullanım: ./fix_ios_build.sh   (Frontend klasöründen veya proje kökünden)

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "1. Pods ve Podfile.lock siliniyor..."
rm -rf ios/Podfile.lock ios/Pods

echo "2. CocoaPods cache temizleniyor..."
(cd ios && pod cache clean --all 2>/dev/null || true)

echo "3. Xcode DerivedData temizleniyor..."
rm -rf ~/Library/Developer/Xcode/DerivedData

echo "4. Flutter clean..."
flutter clean

echo "5. Flutter pub get..."
flutter pub get

echo "6. ios klasöründe pod install --repo-update..."
cd ios && pod install --repo-update && cd ..

echo "Bitti. Simdi: flutter run"
