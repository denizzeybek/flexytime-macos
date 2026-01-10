# FlexyMac V2

macOS menu bar uygulamasi - kullanici aktivitelerini (aktif pencere, idle suresi) takip eder ve sunucuya gonderir.

## Gereksinimler

- macOS 13.0+ (Ventura)
- Xcode 14.1+
- SwiftLint (`brew install swiftlint`)

## Kurulum

```bash
# SwiftLint kur (henuz kurulu degilse)
brew install swiftlint

# Projeyi Xcode'da ac
open FlexyMacV2.xcodeproj
```

## Proje Yapisi

```
FlexyMacV2/
├── App/                    # Uygulama giris noktasi
│   ├── FlexyMacV2App.swift # @main - MenuBarExtra
│   ├── AppDelegate.swift   # Lifecycle yonetimi
│   └── MenuBarView.swift   # Tray menu icerigi
│
├── Services/               # Is mantigi
│   ├── WindowTracker.swift # Aktif pencere takibi
│   ├── IdleDetector.swift  # AFK tespiti
│   ├── ActivityCollector.swift  # Event toplama
│   └── APIClient.swift     # HTTP iletisimi
│
├── Models/                 # Veri modelleri
│   ├── ActivityEvent.swift # Aktivite eventi
│   └── Configuration.swift # Uygulama ayarlari
│
├── Extensions/             # Swift extension'lari
│   ├── Logger+Extension.swift
│   └── Date+Extension.swift
│
└── Resources/              # Asset ve config dosyalari
    ├── Assets.xcassets
    ├── Info.plist
    └── FlexyMacV2.entitlements
```

## Build & Run

### Xcode ile

1. `FlexyMacV2.xcodeproj` dosyasini ac
2. Scheme olarak `FlexyMacV2` sec
3. `Cmd + R` ile calistir

### Terminal ile

```bash
# Debug build
xcodebuild -project FlexyMacV2.xcodeproj -scheme FlexyMacV2 -configuration Debug build

# Release build
xcodebuild -project FlexyMacV2.xcodeproj -scheme FlexyMacV2 -configuration Release build

# Clean
xcodebuild clean -project FlexyMacV2.xcodeproj -scheme FlexyMacV2
```

## Linter

Her kod degisikliginden sonra SwiftLint calistirilmali:

```bash
# Lint kontrolu
swiftlint

# Otomatik duzeltme
swiftlint --fix
```

## macOS Izinleri

Uygulama asagidaki izinlere ihtiyac duyar:

1. **Accessibility**: Pencere basliklarini okumak icin
   - System Preferences > Security & Privacy > Privacy > Accessibility

## Konfigurasyon

Varsayilan degerler `Configuration.swift` icinde tanimli:

| Ayar | Varsayilan | Aciklama |
|------|------------|----------|
| `pollingInterval` | 1 sn | Pencere kontrol sikligi |
| `syncInterval` | 60 sn | Sunucuya gonderim sikligi |
| `idleThreshold` | 60 sn | AFK esigi |

## Mimari

```
┌─────────────────────────────────────────────┐
│           FlexyMacV2App (MenuBarExtra)      │
│              ↓                              │
│           AppDelegate                        │
│              ↓                              │
│        ActivityCollector                     │
│         ↙         ↘                         │
│  WindowTracker   IdleDetector               │
│              ↘   ↙                          │
│           APIClient                          │
│              ↓                              │
│         HTTP POST                            │
└─────────────────────────────────────────────┘
```

## Kod Kurallari

1. Dosya basina max 250 satir
2. Kod tekrari yasak - extract et
3. Her degisiklikten sonra `swiftlint` calistir
4. `guard` ile early exit kullan
5. `let` > `var` tercih et
