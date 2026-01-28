# How to Create a Signed & Notarized App for Distribution

This guide explains how to create a properly signed and notarized Flexytime app that can be distributed to users.

## Prerequisites

- Apple Developer Account (paid membership)
- Xcode with valid Developer ID certificates
- App-specific password for notarization (create at appleid.apple.com)

## Step 1: Create Archive

1. Open the project in Xcode
2. Select **Product > Archive** (or `Cmd + Shift + B` after selecting "Any Mac")
3. Wait for the archive to complete
4. Xcode Organizer window will open automatically

## Step 2: Distribute & Notarize

1. In the Organizer, select the latest archive
2. Click **Distribute App**
3. Select **Developer ID** (for distribution outside App Store)
4. Select **Upload** (to notarize with Apple)
5. Wait for notarization to complete (usually 2-5 minutes)
6. You'll see "App successfully notarized" when done

## Step 3: Export Notarized App

1. After notarization succeeds, click **Export**
2. **IMPORTANT:** Select this path as the export location:
   ```
   /Users/denizzeybek/Documents/FLEXYTIME/flexy-mac-v2/build/Flexytime/
   ```
3. Click **Export**
4. The `Flexytime.app` will be saved to that folder

## Step 4: Create DMG

Run the DMG creation script:

```bash
cd /Users/denizzeybek/Documents/FLEXYTIME/flexy-mac-v2
./scripts/create-dmg.sh
```

The DMG will be created at:
```
build/Flexytime.dmg
```

## Verification

To verify the app is properly signed and notarized:

```bash
# Check code signing
codesign -dv --verbose=4 build/Flexytime/Flexytime.app

# Check notarization
spctl -a -vvv build/Flexytime/Flexytime.app
```

Expected output should include:
- `Authority=Developer ID Application: Your Name`
- `source=Notarized Developer ID`

## Summary

| Step | Action | Result |
|------|--------|--------|
| 1 | Product > Archive | Creates .xcarchive |
| 2 | Distribute > Developer ID > Upload | Notarizes with Apple |
| 3 | Export to `build/Flexytime/` | Signed .app file |
| 4 | Run `create-dmg.sh` | Distribution-ready .dmg |

## Notes

- Normal builds (`Cmd+B`) use Development certificates and only work on your Mac
- Only the Archive > Distribute > Export flow creates apps that work on other Macs
- You must repeat this process for each new release
