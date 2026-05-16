#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# PusulaFit — iOS Production Build Script
# Kullanım: ./scripts/build_ios_production.sh
# ─────────────────────────────────────────────────────────────────

set -e  # Hata olursa dur

# ── Zorunlu değişkenler ───────────────────────────────────────────
API_BASE_URL="https://fitness-backend-jrcn.onrender.com"

SENTRY_DSN=""   # Sentry DSN (boş bırakırsan Sentry devre dışı kalır)

# Google Sign-In — iOS'ta Info.plist'ten okunur, buradaki değerler Android için gerekli.
# Google Cloud Console > OAuth 2.0 > iOS client id
GOOGLE_IOS_CLIENT_ID="976465421947-sgglhdo3j4v30957u6j00279qteb5f36.apps.googleusercontent.com"
# Google Cloud Console > OAuth 2.0 > Web application (server client id)
GOOGLE_SERVER_CLIENT_ID="976465421947-2q2ao1vogl1tfmlvkso0d7tv60b3m0e0.apps.googleusercontent.com"

# KVKK — Veri sorumlusu bilgileri (Legal ekranda görünür)
DATA_CONTROLLER_NAME="Enes Kotay"
DATA_CONTROLLER_ADDRESS="Türkiye"
DATA_CONTROLLER_TAX_ID="TC: 21125027796"

# İletişim e-postaları
SUPPORT_EMAIL="eneskotay23@gmail.com"
PRIVACY_EMAIL="eneskotay23@gmail.com"
LEGAL_EMAIL="eneskotay23@gmail.com"
SUPPORT_URL="mailto:eneskotay23@gmail.com?subject=PusulaFit%20Destek"

# Privacy policy web URL — App Store Connect'e de aynı URL girilmeli.
# GitHub Pages veya başka ücretsiz bir hizmette yayınladıktan sonra buraya yaz.
PRIVACY_URL="https://docs.google.com/document/d/e/2PACX-1vS-YRImNGlAUOlo3T7UwxAIYWHu-oV1oIpPlz0k2WPDb-BF3heYeh5brIhhGYr_KDZXTWKrEiJoG9Y8/pub"

# ── Build ─────────────────────────────────────────────────────────
echo "PusulaFit iOS production build başlıyor..."
echo "   API: $API_BASE_URL"
echo "   Veri sorumlusu: $DATA_CONTROLLER_NAME"
echo "   Support: $SUPPORT_EMAIL"
echo "   Privacy URL: $PRIVACY_URL"
echo ""

flutter build ipa \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
  --dart-define=GOOGLE_IOS_CLIENT_ID="$GOOGLE_IOS_CLIENT_ID" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="$GOOGLE_SERVER_CLIENT_ID" \
  --dart-define=APP_DATA_CONTROLLER_NAME="$DATA_CONTROLLER_NAME" \
  --dart-define=APP_DATA_CONTROLLER_ADDRESS="$DATA_CONTROLLER_ADDRESS" \
  --dart-define=APP_DATA_CONTROLLER_TAX_ID="$DATA_CONTROLLER_TAX_ID" \
  --dart-define=APP_SUPPORT_URL="$SUPPORT_URL" \
  --dart-define=APP_SUPPORT_EMAIL="$SUPPORT_EMAIL" \
  --dart-define=APP_PRIVACY_EMAIL="$PRIVACY_EMAIL" \
  --dart-define=APP_LEGAL_EMAIL="$LEGAL_EMAIL" \
  --dart-define=APP_PRIVACY_URL="$PRIVACY_URL"

echo ""
echo "Build tamamlandı: build/ios/ipa/"
echo ""
echo "Sonraki adımlar:"
echo "  1. Xcode Organizer'dan App Store Connect'e yükle"
echo "  2. App Store Connect > App Information > Privacy Policy URL: $PRIVACY_URL"
echo "  3. Review Notes'a test hesabı bilgilerini ekle"
