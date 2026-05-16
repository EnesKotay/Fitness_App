#!/usr/bin/env bash
# sim_test.sh — PusulaFit iOS Simülatör Test Yardımcısı
# Kullanım: ./scripts/sim_test.sh <komut> [argümanlar]
#
# Komutlar:
#   screenshot [dosya]     → Ekran görüntüsü al (/tmp/sim_screen.png varsayılan)
#   tap <x> <y>            → Koordinata dokun
#   swipe <x1> <y1> <x2> <y2>  → Kaydır
#   type <metin>           → Metin gir (klavye açıkken)
#   scroll-up              → Sayfayı yukarı kaydır
#   scroll-down            → Sayfayı aşağı kaydır
#   back                   → Geri git (sol kenar swipe)
#   home                   → Home butonu
#   launch                 → Uygulamayı başlat
#   status                 → Simülatör durumunu göster
#   tree                   → Accessibility bilgisini al (idb gerekir)
#   record [dosya]         → Video kayıt başlat

set -euo pipefail

BUNDLE_ID="com.example.fitness"
SCREENSHOT_DIR="/tmp"
DEVICE_WIDTH=393
DEVICE_HEIGHT=852

# Booted simülatör UDID'sini bul
get_udid() {
    xcrun simctl list devices | grep "Booted" | grep -oE '[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}' | head -1
}

UDID=$(get_udid 2>/dev/null || echo "")

cmd="${1:-help}"

case "$cmd" in
  screenshot|ss)
    OUTFILE="${2:-$SCREENSHOT_DIR/sim_screen_$(date +%H%M%S).png}"
    xcrun simctl io booted screenshot "$OUTFILE"
    echo "✓ Screenshot: $OUTFILE"
    echo "  → Read tool ile oku: $OUTFILE"
    ;;

  tap)
    X="${2:?'X koordinatı gerekli'}"
    Y="${3:?'Y koordinatı gerekli'}"
    xcrun simctl io booted tap "$X" "$Y"
    echo "✓ Tap: ($X, $Y)"
    ;;

  swipe)
    X1="${2:?'x1 gerekli'}" Y1="${3:?'y1 gerekli'}"
    X2="${4:?'x2 gerekli'}" Y2="${5:?'y2 gerekli'}"
    xcrun simctl io booted swipe "$X1" "$Y1" "$X2" "$Y2"
    echo "✓ Swipe: ($X1,$Y1) → ($X2,$Y2)"
    ;;

  type)
    TEXT="${2:?'Metin gerekli'}"
    xcrun simctl io booted type "$TEXT"
    echo "✓ Typed: $TEXT"
    ;;

  scroll-up)
    xcrun simctl io booted swipe 196 600 196 200
    echo "✓ Scroll up"
    ;;

  scroll-down)
    xcrun simctl io booted swipe 196 200 196 600
    echo "✓ Scroll down"
    ;;

  back)
    # Sol kenardan sağa swipe (iOS back gesture)
    xcrun simctl io booted swipe 10 426 250 426
    echo "✓ Back gesture"
    ;;

  home)
    xcrun simctl io booted button home
    echo "✓ Home"
    ;;

  launch)
    xcrun simctl launch booted "$BUNDLE_ID" 2>/dev/null || \
      echo "! Bundle ID bulunamadı. Flutter ile başlatmayı dene: flutter run -d booted"
    echo "✓ Launch: $BUNDLE_ID"
    ;;

  kill)
    xcrun simctl terminate booted "$BUNDLE_ID"
    echo "✓ Uygulama sonlandırıldı"
    ;;

  status)
    echo "=== Simülatör Durumu ==="
    xcrun simctl list devices | grep -E "Booted|Shutdown" | grep -v "^$"
    echo ""
    echo "=== Çalışan Uygulama ==="
    xcrun simctl listapps booted 2>/dev/null | grep "$BUNDLE_ID" | head -5 || echo "Uygulama listesi alınamadı (simülatör kapalı olabilir)"
    ;;

  tree)
    # idb ile accessibility tree (yüklü değilse hata verir)
    if command -v idb &>/dev/null; then
      X="${2:-196}" Y="${3:-426}"
      idb --udid "${UDID:-booted}" accessibility-info-at-point "$X" "$Y"
    else
      echo "! idb yüklü değil. Kur: brew install facebook/fb/idb-companion"
      echo "  Alternatif: xcrun simctl diagnostics ile bilgi al"
    fi
    ;;

  record)
    OUTFILE="${2:-$SCREENSHOT_DIR/sim_record_$(date +%H%M%S).mp4}"
    echo "Video kaydı başladı: $OUTFILE"
    echo "Durdurmak için Ctrl+C"
    xcrun simctl io booted recordVideo "$OUTFILE"
    ;;

  # Kısayol: Tab navigasyonu
  tab-home)
    xcrun simctl io booted tap 50 830
    echo "✓ Tab: Ana Sayfa"
    ;;
  tab-workout)
    xcrun simctl io booted tap 130 830
    echo "✓ Tab: Antrenman"
    ;;
  tab-tracking)
    xcrun simctl io booted tap 260 830
    echo "✓ Tab: Takip"
    ;;
  tab-nutrition)
    xcrun simctl io booted tap 340 830
    echo "✓ Tab: Beslenme"
    ;;

  # Toplu screenshot (test döngüsü için)
  snapshot)
    PREFIX="${2:-test}"
    COUNT=1
    echo "Her tab'ın snapshot'ı alınıyor..."

    for tab_x in 50 130 260 340; do
      xcrun simctl io booted tap "$tab_x" 830
      sleep 0.8
      FILE="$SCREENSHOT_DIR/${PREFIX}_tab${COUNT}.png"
      xcrun simctl io booted screenshot "$FILE"
      echo "✓ $FILE"
      COUNT=$((COUNT + 1))
    done
    echo "Tüm tab snapshot'ları: $SCREENSHOT_DIR/${PREFIX}_tab*.png"
    ;;

  help|*)
    cat << 'EOF'
PusulaFit Simülatör Test Araçları
==================================
Kullanım: ./scripts/sim_test.sh <komut> [argümanlar]

Temel Komutlar:
  screenshot [dosya]            Ekran görüntüsü al
  tap <x> <y>                   Koordinata dokun
  swipe <x1> <y1> <x2> <y2>    Kaydır
  type <metin>                  Metin gir
  scroll-up / scroll-down       Sayfa kaydır
  back                          Geri git
  home                          Home'a dön

Uygulama:
  launch                        Uygulamayı başlat
  kill                          Uygulamayı kapat
  status                        Simülatör/uygulama durumu

Tab Navigasyonu (iPhone 16e):
  tab-home                      Ana Sayfa tabı
  tab-workout                   Antrenman tabı
  tab-tracking                  Takip tabı
  tab-nutrition                 Beslenme tabı

Test:
  snapshot [prefix]             Tüm tabların screenshot'ı
  tree [x] [y]                  Accessibility tree (idb gerekir)
  record [dosya]                Video kayıt

Cihaz Boyutu: 393×852 nokta (iPhone 16e)
EOF
    ;;
esac
