# How to Create a Signed & Notarized App for Distribution

## Why Notarization is Required

macOS adds a "quarantine" flag to files downloaded from the internet. If the app is not notarized by Apple, users will see:

- **"The application Flexytime.app can't be opened"**
- **"Flexytime.app is damaged and can't be opened"**
- **Gatekeeper blocks the app completely**

Notarization tells macOS "Apple has checked this app, it's safe" and the quarantine flag is automatically cleared.

## Prerequisites

1. **Apple Developer Account** (paid, $99/year)
2. **Developer ID Application certificate** installed in Keychain
   - Go to: Apple Developer Portal > Certificates > Create New > Developer ID Application
   - Download and double-click to install
3. **App-specific password** for notarization
   - Go to: [appleid.apple.com](https://appleid.apple.com) > Sign-In and Security > App-Specific Passwords
   - Generate one and save it

## Release Flow Overview

```
Build (Universal Binary) → Sign (Developer ID) → Notarize (Apple) → Staple → DMG → Distribute
```

| Step | What it does | Required for |
|------|-------------|--------------|
| Build | Compiles arm64 + x86_64 binary | All Macs (Intel + Apple Silicon) |
| Sign | Signs with Developer ID certificate | Gatekeeper won't block |
| Notarize | Apple scans for malware | "Quarantine" flag auto-cleared |
| Staple | Embeds notarization ticket in DMG | Works offline (no Apple check needed) |

---

## Method 1: Xcode GUI (Recommended)

### Step 1: Create Archive

1. Open project in Xcode
2. Select **Product > Archive**
3. Wait for archive to complete
4. Xcode Organizer window opens automatically

### Step 2: Distribute & Notarize

1. In Organizer, select the latest archive
2. Click **Distribute App**
3. Select **Developer ID** (for distribution outside App Store)
4. Select **Upload** (this sends to Apple for notarization)
5. Wait for notarization (usually 2-5 minutes)
6. You'll see "App successfully notarized"

### Step 3: Export Notarized App

1. After notarization succeeds, click **Export**
2. Select export location:
   ```
   <project-root>/build/
   ```
   Xcode creates a `Flexytime/` subfolder automatically.
3. App will be at: `build/Flexytime/Flexytime.app`

### Step 4: Create DMG

```bash
./scripts/create-dmg.sh
```

Output: `build/Flexytime.dmg` — ready to upload to website.

---

## Method 2: Terminal (Script)

The `package-release.sh` script handles the full pipeline.

### Unsigned build (for testing only)

```bash
./scripts/package-release.sh
```

### Signed + Notarized build (for distribution)

```bash
./scripts/package-release.sh --notarize \
  --apple-id "your@email.com" \
  --team-id "3C44584K6T" \
  --app-password "xxxx-xxxx-xxxx-xxxx"
```

This runs all 4 steps automatically:
1. `build-universal.sh` — builds arm64 + x86_64
2. Signs with Developer ID Application certificate
3. Creates DMG via `create-dmg.sh`
4. Submits to Apple for notarization + staples the ticket

### Script options

```
--sign              Sign only (no notarization)
--notarize          Sign + notarize (full pipeline)
--developer-id ID   Specify certificate name manually
--apple-id EMAIL    Apple ID for notarization
--team-id ID        Team ID
--app-password PWD  App-specific password
```

---

## Verification

After creating the DMG, verify it's properly signed and notarized:

```bash
# Check code signing
codesign -dv --verbose=4 build/Flexytime/Flexytime.app

# Check notarization (should say "source=Notarized Developer ID")
spctl -a -vvv build/Flexytime/Flexytime.app

# Verify DMG signature
codesign -dv build/Flexytime.dmg
```

---

## Troubleshooting

### "No Developer ID Application certificate found"
- Go to Apple Developer Portal > Certificates
- Create "Developer ID Application" certificate
- Download and install (double-click)
- Run: `security find-identity -v -p codesigning` to verify

### Notarization fails
- Ensure **Hardened Runtime** is enabled (it is in this project)
- Check entitlements are correct
- Run `xcrun notarytool log <submission-id>` for detailed error

### Users still get "can't be opened"
- Verify DMG is stapled: `stapler validate build/Flexytime.dmg`
- User can try: `xattr -cr /Applications/Flexytime.app` as a workaround
- Make sure you exported from Xcode **after** notarization completed

---

## Quick Reference

| Build Type | Command | Users Can Install? |
|-----------|---------|-------------------|
| Debug (Cmd+R) | Xcode Run | Only your Mac |
| Unsigned DMG | `./scripts/package-release.sh` | Manual xattr needed |
| Signed DMG | `./scripts/package-release.sh --sign` | Right-click > Open |
| **Notarized DMG** | `./scripts/package-release.sh --notarize` | **Double-click works** |

## Clean Build (Optional)

```bash
# Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/FlexytimeMacOS-*

# Clean build folder
rm -rf build/*
```
