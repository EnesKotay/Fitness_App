#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# FitMentor — iOS Production Build Script
# Kullanım: ./scripts/build_ios_production.sh
# ─────────────────────────────────────────────────────────────────

set -e  # Hata olursa dur

# ── Zorunlu değişkenler ───────────────────────────────────────────
API_BASE_URL="https://fitness-backend-jrcn.onrender.com"

SENTRY_DSN=""   # Sentry DSN (boş bırakırsan Sentry devre dışı kalır)

# KVKK — Veri sorumlusu bilgileri (Legal ekranda görünür)
DATA_CONTROLLER_NAME="Enes Kotay"
DATA_CONTROLLER_ADDRESS="Türkiye"
DATA_CONTROLLER_TAX_ID="TC: 21125027796"

# İletişim e-postaları
SUPPORT_EMAIL="eneskotay23@gmail.com"
PRIVACY_EMAIL="eneskotay23@gmail.com"
LEGAL_EMAIL="eneskotay23@gmail.com"
SUPPORT_URL="mailto:eneskotay23@gmail.com?subject=FitMentor%20Destek"

# Privacy policy web URL — App Store Connect'e de aynı URL girilmeli.
# GitHub Pages veya başka ücretsiz bir hizmette yayınladıktan sonra buraya yaz.
PRIVACY_URL="https://docs.google.com/document/d/e/2PACX-1vS-YRImNGlAUOlo3T7UwxAIYWHu-oV1oIpPlz0k2WPDb-BF3heYeh5brIhhGYr_KDZXTWKrEiJoG9Y8/pub"

# ── Build ─────────────────────────────────────────────────────────
echo "FitMentor iOS production build başlıyor..."
echo "   API: $API_BASE_URL"
echo "   Veri sorumlusu: $DATA_CONTROLLER_NAME"
echo "   Support: $SUPPORT_EMAIL"
echo "   Privacy URL: $PRIVACY_URL"
echo ""

flutter build ipa \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=SENTRY_DSN="$SENTRY_DSN" \
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
