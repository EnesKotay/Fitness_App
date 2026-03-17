#!/bin/bash
# Backend başlatma: 8080 portunu kullanan işlemi kapatır, sonra Quarkus dev modunu başlatır.
# macOS / Linux: chmod +x run-backend.sh && ./run-backend.sh

PORT=8080
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 8080 portunu kullanan işlemi kapat
if command -v lsof &> /dev/null; then
  PID=$(lsof -ti:$PORT 2>/dev/null)
  if [ -n "$PID" ]; then
    echo "Port $PORT kullanan işlem kapatılıyor: PID $PID"
    kill -9 $PID 2>/dev/null || true
    sleep 1
  fi
fi

# GEMINI_API_KEY isteğe bağlı; tanımlı değilse AI (coach/beslenme) istekleri 503 döner.
# macOS stty hatası (ıntr/mın/tıme): Quarkus/Aesh TTY'ye stty gönderir; Türkçe locale'de
# "i" → "ı" dönüşünce stty hata veriyor. Çözüm: ASCII locale + macOS stty + konsol kapalı + stdin pipe.
export LC_ALL=C
export LANG=C
# Homebrew OpenJDK - Java'yi once ara (Apple Silicon: /opt/homebrew, Intel: /usr/local)
if [ -z "$JAVA_HOME" ]; then
  if [ -x "/opt/homebrew/opt/openjdk@21/bin/java" ]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@21"
  elif [ -x "/usr/local/opt/openjdk@21/bin/java" ]; then
    export JAVA_HOME="/usr/local/opt/openjdk@21"
  fi
fi
[ -n "$JAVA_HOME" ] && export PATH="$JAVA_HOME/bin:${PATH:-/usr/bin:/bin}"
export QUARKUS_CONSOLE_DISABLED=true
export MAVEN_OPTS="${MAVEN_OPTS:-} -Duser.language=en -Duser.country=US -Dfile.encoding=UTF-8 -Dquarkus.console.disabled=true -Djdk.console=java.base"
./mvnw quarkus:dev -DskipTests -Dquarkus.console.disabled=true < /dev/null
