# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FlexyMac V2 is a macOS menu bar application that tracks user activity (active windows, idle time) and sends data to a remote server. Built with Swift and SwiftUI.

**CRITICAL: This app must be 100% compatible with the existing backend (flexytime-backend). The data format, encryption, and API calls must match V1 exactly.**

## Tech Stack

- **Language:** Swift 5.7+
- **UI Framework:** SwiftUI (MenuBarExtra)
- **Target:** macOS 13.0+ (Ventura)
- **IDE:** Xcode 14+

## V1 Compatibility Requirements

### Data Collection Timing (MUST MATCH V1)
```
Every 1 second:  activity_event() - Check active window
Every 15 seconds: on_input_timed_event() - Check if user is AFK (idle > 60s)
Every 60 seconds: on_window_timed_event() - Save & send collected views
Every 15 minutes: on_calendar_timed_event() - Send calendar ping event
```

### View Event Logic (MUST MATCH V1)
- New event created ONLY when **ProcessName changes** (NOT when Title changes)
- When app changes: close previous view (ExpireTime = now), create new view
- When AFK detected: close current view (ExpireTime = last input time), set activeView = nil
- Minimum duration: Events < 1 second are discarded

### Data Format (MUST MATCH V1)

**Usage Object (before encryption):**
```json
{
  "DeviceType": 1,
  "Version": "1.0.4",
  "Username": "MachineName\\loginuser",
  "MachineName": "MachineName",
  "IpAddress": "192.168.1.5",
  "DataType": 0,
  "RecordDate": "2021-05-07T10:30:00.000000",
  "Views": [
    {
      "ProcessName": "Google Chrome",
      "Title": "GitHub - Google Chrome",
      "Time": "2021-05-07T10:29:00.000000",
      "ExpireTime": "2021-05-07T10:29:45.000000"
    }
  ]
}
```

**DataType enum:**
- 0 = Input (normal activity)
- 1 = Calendar (15-minute ping)

**DeviceType enum:**
- 0 = Windows
- 1 = Mac

### Encryption (MUST MATCH V1)

Two-layer ZIP encryption using passwords:
1. **Internal layer password:** `99C5CB2EAA4EF8C3AB722F6B320FF006022783D063DC60DE217300B6A631A91B`
2. **External layer password:** `23D405A00C105E32447B3700535CE159C820825658A6989208E16A1F1797F5BB`

Process:
1. Save usage as `usage.json`
2. Compress with internal password → filename = SHA256 hash of JSON
3. Compress result with external password → filename = ticks since epoch + `.trc`
4. Delete temp files

### API Payload (MUST MATCH V1)

**Endpoint:** `POST /api/service/savetrace`

```json
{
  "ControlKey": "53201045-1b89-47d4-909e-f0d326f393c0",
  "Token": "<ServiceKey from config>",
  "RecordDate": "2021-05-07T10:30:00.000000",
  "Content": "<base64 encoded .trc file>",
  "UserPath": "<SHA256 hash of Username>",
  "DeviceType": 1
}
```

### Window Detection (V1 Method)

V1 uses AppleScript (`printAppTitle.scpt`) which returns:
```
"AppName","WindowTitle"
```

The script uses System Events to get:
- Frontmost application name
- Focused window's AXTitle attribute

### Local Storage Paths

```
~/Library/Application Support/flexytime/cache/<UserPath>/*.trc
~/Library/Application Support/flexytime/config/flexytime/flexytime.ini
~/Library/Logs/flexytime/flexytime.log
```

### Offline Support

- .trc files accumulate in cache when offline
- On each sync (60s), all .trc files are sent
- Successfully sent files are deleted
- Failed files remain for retry

## Code Rules (MUST FOLLOW)

### 1. No Code Duplication
- Extract repeated code into reusable functions/extensions
- Use protocols for shared behavior

### 2. File Length Limit: 250 Lines Maximum
- Each Swift file MUST NOT exceed 250 lines of code
- Split large files into smaller components

### 3. Run Linter After Every Code Change
- After writing/modifying any Swift file, run: `swiftlint`
- Fix all warnings before proceeding

### 4. Code Organization
```
FlexyMacV2/
├── App/                    # App entry point, lifecycle
├── Services/               # Business logic (tracking, API)
├── Models/                 # Data models (V1 compatible)
├── Encryption/             # ZIP encryption (V1 compatible)
├── Extensions/             # Swift extensions
├── Utilities/              # Helper functions
└── Resources/              # Assets, configs, AppleScript
```

## Build Commands

```bash
# Build project
xcodebuild -project FlexyMacV2.xcodeproj -scheme FlexyMacV2 -configuration Debug build

# Run linter
swiftlint

# Clean build
xcodebuild clean -project FlexyMacV2.xcodeproj -scheme FlexyMacV2
```

## Configuration

Config stored in: `~/Library/Application Support/flexytime/config/flexytime/flexytime.ini`

```ini
[flexytime]
ServiceVersion = 2.0.0
ServiceKey = <from deployment>
ServiceHost = <from deployment>
```
