#!/bin/bash
#
# package-release.sh
# Complete release pipeline for Flexytime
# Includes: Build, Sign, DMG, Notarize
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Project settings
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="${PROJECT_DIR}/scripts"
APP_NAME="Flexytime"
BUILD_DIR="${PROJECT_DIR}/build"

# Code signing settings (set these for production)
DEVELOPER_ID=""  # e.g., "Developer ID Application: Your Name (TEAMID)"
APPLE_ID=""      # Your Apple ID email
TEAM_ID=""       # Your Team ID
APP_PASSWORD=""  # App-specific password for notarization

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Flexytime Release Packager${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Parse arguments
SIGN_APP=false
NOTARIZE=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --sign) SIGN_APP=true ;;
        --notarize) NOTARIZE=true; SIGN_APP=true ;;
        --developer-id) DEVELOPER_ID="$2"; shift ;;
        --apple-id) APPLE_ID="$2"; shift ;;
        --team-id) TEAM_ID="$2"; shift ;;
        --app-password) APP_PASSWORD="$2"; shift ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --sign              Sign the app with Developer ID"
            echo "  --notarize          Sign and notarize (requires Apple Developer account)"
            echo "  --developer-id ID   Developer ID Application certificate name"
            echo "  --apple-id EMAIL    Apple ID for notarization"
            echo "  --team-id ID        Team ID for notarization"
            echo "  --app-password PWD  App-specific password for notarization"
            echo ""
            echo "Examples:"
            echo "  $0                  # Build unsigned DMG (for testing)"
            echo "  $0 --sign           # Build signed DMG"
            echo "  $0 --notarize       # Build signed and notarized DMG"
            exit 0
            ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Step 1: Build Universal Binary
echo -e "${BLUE}Step 1/4: Building Universal Binary${NC}"
echo "----------------------------------------"
"${SCRIPTS_DIR}/build-universal.sh"

# Get paths
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}-universal.dmg"

# Step 2: Code Signing (optional)
echo ""
echo -e "${BLUE}Step 2/4: Code Signing${NC}"
echo "----------------------------------------"

if [ "$SIGN_APP" = true ]; then
    if [ -z "$DEVELOPER_ID" ]; then
        echo -e "${YELLOW}Looking for Developer ID certificates...${NC}"
        CERTS=$(security find-identity -v -p codesigning | grep "Developer ID Application" || true)
        if [ -n "$CERTS" ]; then
            echo "$CERTS"
            DEVELOPER_ID=$(echo "$CERTS" | head -1 | sed 's/.*"\(.*\)".*/\1/')
            echo -e "Using: ${GREEN}${DEVELOPER_ID}${NC}"
        else
            echo -e "${RED}No Developer ID Application certificate found!${NC}"
            echo "Install a certificate from Apple Developer portal or run without --sign"
            exit 1
        fi
    fi

    echo -e "${YELLOW}Signing app bundle...${NC}"

    # Sign all nested components first
    find "${APP_PATH}" -type f \( -name "*.dylib" -o -name "*.framework" \) -exec \
        codesign --force --options runtime --sign "${DEVELOPER_ID}" {} \; 2>/dev/null || true

    # Sign the main app
    codesign --force --options runtime --sign "${DEVELOPER_ID}" \
        --entitlements "${PROJECT_DIR}/FlexyMacV2/Resources/FlexyMacV2.entitlements" \
        "${APP_PATH}"

    # Verify signature
    echo -e "${YELLOW}Verifying signature...${NC}"
    codesign --verify --verbose "${APP_PATH}"
    echo -e "${GREEN}App signed successfully!${NC}"
else
    echo -e "${YELLOW}Skipping code signing (use --sign to enable)${NC}"
fi

# Step 3: Create DMG
echo ""
echo -e "${BLUE}Step 3/4: Creating DMG${NC}"
echo "----------------------------------------"
"${SCRIPTS_DIR}/create-dmg.sh"

# Sign DMG if signing is enabled
if [ "$SIGN_APP" = true ] && [ -f "${DMG_PATH}" ]; then
    echo -e "${YELLOW}Signing DMG...${NC}"
    codesign --force --sign "${DEVELOPER_ID}" "${DMG_PATH}"
    echo -e "${GREEN}DMG signed!${NC}"
fi

# Step 4: Notarization (optional)
echo ""
echo -e "${BLUE}Step 4/4: Notarization${NC}"
echo "----------------------------------------"

if [ "$NOTARIZE" = true ]; then
    if [ -z "$APPLE_ID" ] || [ -z "$TEAM_ID" ] || [ -z "$APP_PASSWORD" ]; then
        echo -e "${RED}Notarization requires:${NC}"
        echo "  --apple-id YOUR_APPLE_ID"
        echo "  --team-id YOUR_TEAM_ID"
        echo "  --app-password YOUR_APP_SPECIFIC_PASSWORD"
        exit 1
    fi

    echo -e "${YELLOW}Submitting to Apple for notarization...${NC}"
    echo "This may take several minutes..."

    # Submit for notarization
    xcrun notarytool submit "${DMG_PATH}" \
        --apple-id "${APPLE_ID}" \
        --team-id "${TEAM_ID}" \
        --password "${APP_PASSWORD}" \
        --wait

    # Staple the notarization ticket
    echo -e "${YELLOW}Stapling notarization ticket...${NC}"
    xcrun stapler staple "${DMG_PATH}"

    # Verify
    echo -e "${YELLOW}Verifying notarization...${NC}"
    spctl --assess --type open --context context:primary-signature --verbose "${DMG_PATH}"

    echo -e "${GREEN}Notarization complete!${NC}"
else
    echo -e "${YELLOW}Skipping notarization (use --notarize to enable)${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Release Package Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  App:     ${APP_NAME}"
echo -e "  Version: ${VERSION}"
echo -e "  DMG:     ${DMG_PATH}"
echo ""

if [ "$SIGN_APP" = true ]; then
    echo -e "  Signed:     ${GREEN}Yes${NC}"
else
    echo -e "  Signed:     ${YELLOW}No${NC} (test build)"
fi

if [ "$NOTARIZE" = true ]; then
    echo -e "  Notarized:  ${GREEN}Yes${NC}"
else
    echo -e "  Notarized:  ${YELLOW}No${NC}"
fi

echo ""
echo -e "DMG ready for distribution!"
