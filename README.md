# Flexytime macOS

A macOS menu bar application that tracks user activity (active windows, idle time) and sends data to a remote server.

## Prerequisites

### System Requirements
- **macOS 13.0+** (Ventura or later)
- **Xcode 14.1+** (Download from App Store)
- **Apple Developer Account** (optional - only for code signing)

### Tools

```bash
# 1. Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install SwiftLint (for code quality)
brew install swiftlint

# 3. Install Xcode Command Line Tools
xcode-select --install
```

### macOS Permissions

The application requires **two permissions** to function:

| Permission | Why Required | Where to Grant |
|------------|--------------|----------------|
| **Accessibility** | To read window titles | System Settings → Privacy & Security → Accessibility |
| **Screen Recording** | To read window names on macOS 10.15+ | System Settings → Privacy & Security → Screen Recording |

> **Note:** The application must be restarted after granting permissions.

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/denizzeybek/flexytime-macos.git
cd flexytime-macos

# 2. Install SwiftLint (if not already installed)
brew install swiftlint

# 3. Open the project in Xcode
open FlexytimeMacOS.xcodeproj
```

## Project Structure

```
FlexytimeMacOS/
├── App/                    # Application entry point
│   ├── FlexytimeMacOSApp.swift  # @main - MenuBarExtra
│   ├── AppDelegate.swift   # Lifecycle management
│   ├── MenuBarView.swift   # Tray menu content
│   └── SetupView.swift     # Initial setup screen
│
├── Services/               # Business logic
│   ├── WindowTracker.swift # Active window tracking
│   ├── IdleDetector.swift  # AFK detection
│   ├── ActivityCollector.swift  # Event collection
│   └── APIClient.swift     # HTTP communication
│
├── Models/                 # Data models
│   ├── ActivityEvent.swift # Activity event
│   └── Configuration.swift # Application settings
│
├── Helpers/                # Utility classes
│   ├── SystemInfo.swift    # System information
│   ├── LoginItemsManager.swift  # Login item management
│   └── PermissionsManager.swift # Permission management
│
├── Encryption/             # Encryption
│   ├── ZipEncryption.swift # ZIP encryption
│   └── minizip/            # C library
│
├── Extensions/             # Swift extensions
│   ├── Logger+Extension.swift
│   └── Date+Extension.swift
│
└── Resources/              # Assets and config files
    ├── Assets.xcassets
    ├── Info.plist
    └── FlexytimeMacOS.entitlements
```

## Build & Run

### With Xcode (Development)

1. Open `FlexytimeMacOS.xcodeproj`
2. Select `FlexytimeMacOS` as the scheme
3. Press `Cmd + R` to run

### With Terminal (Development)

```bash
# Debug build
xcodebuild -project FlexytimeMacOS.xcodeproj -scheme FlexytimeMacOS -configuration Debug build

# Release build
xcodebuild -project FlexytimeMacOS.xcodeproj -scheme FlexytimeMacOS -configuration Release build

# Clean
xcodebuild clean -project FlexytimeMacOS.xcodeproj -scheme FlexytimeMacOS
```

## DMG Packaging (Distribution)

Package the application as a DMG for distribution:

### Quick Method (For Testing - Unsigned)

```bash
# 1. Build Universal Binary (Intel + Apple Silicon)
./scripts/build-universal.sh

# 2. Create DMG
./scripts/create-dmg.sh
```

Output: `build/Flexytime-2.0.0-universal.dmg`

### Single Command

```bash
# Run all steps (build + dmg)
./scripts/package-release.sh
```

### Production (Signed + Notarized)

Requires an Apple Developer account:

```bash
./scripts/package-release.sh --notarize \
  --apple-id "your@email.com" \
  --team-id "YOURTEAMID" \
  --app-password "xxxx-xxxx-xxxx-xxxx"
```

### Build Outputs

```
build/
├── Flexytime.xcarchive/     # Xcode archive
└── Flexytime-2.0.0-universal.dmg  # Distribution file (Universal Binary)
```

**Note:** The application in the DMG runs on both Intel (x86_64) and Apple Silicon (arm64) processors.

## Troubleshooting Permissions

If you're getting "No Window" errors:

### 1. Check Permissions
```bash
# Open System Settings
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
```

### 2. TCC Reset (Reset Permissions)
```bash
# Reset permission database
./scripts/reset-permissions.sh

# or manually:
tccutil reset Accessibility
tccutil reset ScreenCapture
```

Then restart the application and grant permissions again.

## Linter

SwiftLint should be run after every code change:

```bash
# Lint check
swiftlint

# Auto-fix
swiftlint --fix
```

## Configuration

Default values are defined in `Configuration.swift`:

| Setting | Default | Description |
|---------|---------|-------------|
| `pollingInterval` | 1 sec | Window check frequency |
| `syncInterval` | 60 sec | Server sync frequency |
| `idleThreshold` | 60 sec | AFK threshold |

## Architecture

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

## Code Guidelines

1. Maximum 250 lines per file
2. No code duplication - extract to functions
3. Run `swiftlint` after every change
4. Use `guard` for early exit
5. Prefer `let` over `var`

## Troubleshooting

### Build Errors

```bash
# Clear DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData

# Clear SPM cache
rm -rf ~/Library/Caches/org.swift.swiftpm
```

### Application Not Working

1. Open Console.app and filter by "Flexytime"
2. Check error messages
3. Verify permissions (Accessibility + Screen Recording)

### View Logs

```bash
# With Console.app
open -a Console

# Or with Terminal
log stream --predicate 'subsystem == "com.flexytime.macos"' --level debug
```

## Scripts

| Script | Description |
|--------|-------------|
| `scripts/build-universal.sh` | Creates universal binary |
| `scripts/create-dmg.sh` | Creates DMG package |
| `scripts/package-release.sh` | Build + DMG in one command |
| `scripts/reset-permissions.sh` | Resets TCC permissions |

## License

MIT
