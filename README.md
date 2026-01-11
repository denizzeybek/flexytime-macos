# Flexytime macOS

macOS menu bar uygulaması - kullanıcı aktivitelerini (aktif pencere, idle süresi) takip eder ve sunucuya gönderir.

## Prerequisites (Ön Gereksinimler)

### Sistem Gereksinimleri
- **macOS 13.0+** (Ventura veya üstü)
- **Xcode 14.1+** (App Store'dan indir)
- **Apple Developer Account** (opsiyonel - sadece code signing için)

### Araçlar

```bash
# 1. Homebrew kur (yoksa)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. SwiftLint kur (kod kalitesi için)
brew install swiftlint

# 3. Xcode Command Line Tools kur
xcode-select --install
```

### macOS İzinleri

Uygulama çalışmak için **iki izin** gerektirir:

| İzin | Neden Gerekli | Nereden Verilir |
|------|---------------|-----------------|
| **Accessibility** | Pencere başlıklarını okumak için | System Settings → Privacy & Security → Accessibility |
| **Screen Recording** | macOS 10.15+ için pencere isimlerini okumak | System Settings → Privacy & Security → Screen Recording |

> **Not:** İzinleri verdikten sonra uygulama yeniden başlatılmalıdır.

## Kurulum

```bash
# 1. Repo'yu klonla
git clone https://github.com/denizzeybek/flexytime-macos.git
cd flexytime-macos

# 2. SwiftLint kur (henüz kurulu değilse)
brew install swiftlint

# 3. Projeyi Xcode'da aç
open FlexytimeMacOS.xcodeproj
```

## Proje Yapısı

```
FlexytimeMacOS/
├── App/                    # Uygulama giriş noktası
│   ├── FlexytimeMacOSApp.swift  # @main - MenuBarExtra
│   ├── AppDelegate.swift   # Lifecycle yönetimi
│   ├── MenuBarView.swift   # Tray menü içeriği
│   └── SetupView.swift     # İlk kurulum ekranı
│
├── Services/               # İş mantığı
│   ├── WindowTracker.swift # Aktif pencere takibi
│   ├── IdleDetector.swift  # AFK tespiti
│   ├── ActivityCollector.swift  # Event toplama
│   └── APIClient.swift     # HTTP iletişimi
│
├── Models/                 # Veri modelleri
│   ├── ActivityEvent.swift # Aktivite eventi
│   └── Configuration.swift # Uygulama ayarları
│
├── Helpers/                # Yardımcı sınıflar
│   ├── SystemInfo.swift    # Sistem bilgileri
│   ├── LoginItemsManager.swift  # Login item yönetimi
│   └── PermissionsManager.swift # İzin yönetimi
│
├── Encryption/             # Şifreleme
│   ├── ZipEncryption.swift # ZIP şifreleme
│   └── minizip/            # C kütüphanesi
│
├── Extensions/             # Swift extension'ları
│   ├── Logger+Extension.swift
│   └── Date+Extension.swift
│
└── Resources/              # Asset ve config dosyaları
    ├── Assets.xcassets
    ├── Info.plist
    └── FlexytimeMacOS.entitlements
```

## Build & Run

### Xcode ile (Development)

1. `FlexytimeMacOS.xcodeproj` dosyasını aç
2. Scheme olarak `FlexytimeMacOS` seç
3. `Cmd + R` ile çalıştır

### Terminal ile (Development)

```bash
# Debug build
xcodebuild -project FlexytimeMacOS.xcodeproj -scheme FlexytimeMacOS -configuration Debug build

# Release build
xcodebuild -project FlexytimeMacOS.xcodeproj -scheme FlexytimeMacOS -configuration Release build

# Clean
xcodebuild clean -project FlexytimeMacOS.xcodeproj -scheme FlexytimeMacOS
```

## DMG Paketleme (Distribution)

Uygulamayı dağıtım için DMG olarak paketlemek:

### Hızlı Yöntem (Test için - Unsigned)

```bash
# 1. Universal Binary build al (Intel + Apple Silicon)
./scripts/build-universal.sh

# 2. DMG oluştur
./scripts/create-dmg.sh
```

Çıktı: `build/Flexytime-2.0.0-universal.dmg`

### Tek Komutla

```bash
# Tüm adımları çalıştır (build + dmg)
./scripts/package-release.sh
```

### Production (Signed + Notarized)

Apple Developer hesabı gerektirir:

```bash
./scripts/package-release.sh --notarize \
  --apple-id "your@email.com" \
  --team-id "YOURTEAMID" \
  --app-password "xxxx-xxxx-xxxx-xxxx"
```

### Build Çıktıları

```
build/
├── Flexytime.xcarchive/     # Xcode archive
└── Flexytime-2.0.0-universal.dmg  # Dağıtım dosyası (Universal Binary)
```

**Not:** DMG içindeki uygulama hem Intel (x86_64) hem Apple Silicon (arm64) işlemcilerde çalışır.

## İzin Sorunları Giderme

Eğer "No Window" hatası alıyorsanız:

### 1. İzinleri Kontrol Et
```bash
# System Settings'i aç
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
```

### 2. TCC Reset (İzinleri Sıfırla)
```bash
# İzin veritabanını sıfırla
./scripts/reset-permissions.sh

# veya manuel:
tccutil reset Accessibility
tccutil reset ScreenCapture
```

Ardından uygulamayı yeniden başlat ve izinleri tekrar ver.

## Linter

Her kod değişikliğinden sonra SwiftLint çalıştırılmalı:

```bash
# Lint kontrolü
swiftlint

# Otomatik düzeltme
swiftlint --fix
```

## Konfigürasyon

Varsayılan değerler `Configuration.swift` içinde tanımlı:

| Ayar | Varsayılan | Açıklama |
|------|------------|----------|
| `pollingInterval` | 1 sn | Pencere kontrol sıklığı |
| `syncInterval` | 60 sn | Sunucuya gönderim sıklığı |
| `idleThreshold` | 60 sn | AFK eşiği |

## Mimari

```
┌─────────────────────────────────────────────┐
│       FlexytimeMacOSApp (MenuBarExtra)      │
│              ↓                              │
│           AppDelegate                       │
│              ↓                              │
│        ActivityCollector                    │
│         ↙         ↘                         │
│  WindowTracker   IdleDetector               │
│              ↘   ↙                          │
│           APIClient                         │
│              ↓                              │
│         HTTP POST                           │
└─────────────────────────────────────────────┘
```

## Kod Kuralları

1. Dosya başına max 250 satır
2. Kod tekrarı yasak - extract et
3. Her değişiklikten sonra `swiftlint` çalıştır
4. `guard` ile early exit kullan
5. `let` > `var` tercih et

## Troubleshooting

### Build Hataları

```bash
# DerivedData temizle
rm -rf ~/Library/Developer/Xcode/DerivedData

# SPM cache temizle
rm -rf ~/Library/Caches/org.swift.swiftpm
```

### Uygulama Çalışmıyor

1. Console.app'ı aç ve "Flexytime" filtrele
2. Hata mesajlarını kontrol et
3. İzinleri kontrol et (Accessibility + Screen Recording)

### Logları Görüntüle

```bash
# Console.app ile
open -a Console

# veya Terminal ile
log stream --predicate 'subsystem == "com.flexytime.macos"' --level debug
```

## Scripts

| Script | Açıklama |
|--------|----------|
| `scripts/build-universal.sh` | Universal binary oluşturur |
| `scripts/create-dmg.sh` | DMG paketi oluşturur |
| `scripts/package-release.sh` | Build + DMG tek komutta |
| `scripts/reset-permissions.sh` | TCC izinlerini sıfırlar |

## License

MIT
