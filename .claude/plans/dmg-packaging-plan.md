# Flexytime macOS Universal Binary DMG Paketleme Planı

## Gereksinimler
- **Universal Binary**: Intel (x86_64) + Apple Silicon (arm64) desteği
- **DMG**: Profesyonel görünümlü disk image
- **Code Signing**: Apple Developer sertifikası ile imzalama
- **Notarization**: Apple'ın güvenlik onayı (macOS Catalina+ için zorunlu)

## Mevcut Durum
- Xcode 14.1 projesi
- macOS 13.0 minimum deployment target
- Hardened Runtime aktif
- DEVELOPMENT_TEAM boş (henüz sertifika yok)

---

## Uygulama Adımları

### 1. Universal Binary Yapılandırması
**Dosya:** `FlexyMacV2.xcodeproj/project.pbxproj`

Debug ve Release build settings'e eklenecek:
```
ARCHS = "$(ARCHS_STANDARD)";
```
Bu ayar varsayılan olarak Universal Binary üretir (arm64 + x86_64).

### 2. Build Script Oluşturma
**Dosya:** `scripts/build-universal.sh`

```bash
#!/bin/bash
# Universal Binary Archive oluşturma
xcodebuild -project FlexyMacV2.xcodeproj \
    -scheme FlexyMacV2 \
    -configuration Release \
    -archivePath build/Flexytime.xcarchive \
    archive
```

### 3. Export Script (Unsigned - Test için)
**Dosya:** `scripts/export-app.sh`

```bash
#!/bin/bash
# Archive'dan .app export (unsigned)
xcodebuild -exportArchive \
    -archivePath build/Flexytime.xcarchive \
    -exportPath build/export \
    -exportOptionsPlist scripts/ExportOptions.plist
```

### 4. DMG Oluşturma Script
**Dosya:** `scripts/create-dmg.sh`

```bash
#!/bin/bash
# Profesyonel DMG oluşturma
# - Özel arka plan resmi
# - Applications klasörüne kısayol
# - Pencere boyutu ve ikon pozisyonları
```

### 5. Tam Paketleme Script (Signed + Notarized)
**Dosya:** `scripts/package-release.sh`

Bu script tüm adımları birleştirir:
1. Clean build
2. Universal Binary archive
3. Code signing (Developer ID Application sertifikası)
4. DMG oluşturma
5. DMG imzalama
6. Notarization (Apple'a gönderme)
7. Stapling (notarization ticket'ı DMG'ye ekleme)

---

## Gerekli Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `scripts/build-universal.sh` | Archive oluşturma |
| `scripts/create-dmg.sh` | DMG oluşturma |
| `scripts/package-release.sh` | Tam release pipeline |
| `scripts/ExportOptions.plist` | Export ayarları |
| `resources/dmg-background.png` | DMG arka plan (opsiyonel) |

---

## Code Signing Gereksinimleri

### Developer Hesabı Olmadan (Test)
- Unsigned .app oluşturulabilir
- DMG oluşturulabilir
- **Ancak:** Kullanıcılar "Apple tarafından doğrulanamadı" uyarısı alır

### Developer Hesabı ile (Production)
Gerekli:
1. Apple Developer Program üyeliği ($99/yıl)
2. Developer ID Application sertifikası
3. Developer ID Installer sertifikası (opsiyonel, PKG için)
4. App-specific password (notarization için)

---

## Öneri: İki Aşamalı Yaklaşım

### Aşama 1: Test DMG (Hemen)
- Code signing olmadan
- Universal Binary build
- Basit DMG oluşturma
- İç test için yeterli

### Aşama 2: Production DMG (Daha sonra)
- Developer ID ile imzalama
- Notarization
- Profesyonel DMG tasarımı

---

## Çıktı
Başarılı paketleme sonrası:
```
build/
├── Flexytime.xcarchive/
├── export/
│   └── Flexytime.app
└── Flexytime-2.0.0-universal.dmg
```
