#!/bin/bash
# Test scripti - değişiklikleri hızlıca test etmek için
# Kullanım: ./scripts/test-local.sh

set -e

echo "=== Flexytime Local Test ==="
echo ""

# 1. Mevcut uygulamayı kapat
echo "[1/4] Mevcut uygulama kapatılıyor..."
pkill -f Flexytime 2>/dev/null || true
sleep 1

# 2. Release build al
echo "[2/4] Release build alınıyor..."
cd /Users/denizzeybek/Documents/FLEXYTIME/flexy-mac-v2
xcodebuild -project FlexytimeMacOS.xcodeproj \
    -scheme FlexytimeMacOS \
    -configuration Release \
    -derivedDataPath ./build \
    build 2>&1 | grep -E "BUILD|error:|warning:" | head -10

# 3. Applications'a kopyala
echo "[3/4] /Applications'a kopyalanıyor..."
rm -rf /Applications/Flexytime.app
cp -R ./build/Build/Products/Release/Flexytime.app /Applications/

# 4. Uygulamayı başlat
echo "[4/4] Uygulama başlatılıyor..."
open /Applications/Flexytime.app

echo ""
echo "=== Build tamamlandı! ==="
echo "Logları izlemek için:"
echo "  log stream --predicate 'subsystem == \"com.flexytime.macos\"' --level debug"
echo ""
