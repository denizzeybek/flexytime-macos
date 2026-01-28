#!/bin/bash
#
# create-dmg.sh
# Creates a DMG installer for Flexytime (Universal Binary)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project settings
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Flexytime"
BUILD_DIR="${PROJECT_DIR}/build"
APP_PATH="${BUILD_DIR}/${APP_NAME}/${APP_NAME}.app"
DMG_DIR="${BUILD_DIR}/dmg-contents"

# Get version from app bundle
if [ -f "${APP_PATH}/Contents/Info.plist" ]; then
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")
else
    VERSION="2.0.0"
fi

DMG_NAME="${APP_NAME}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
VOLUME_NAME="${APP_NAME}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Flexytime DMG Creator${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if archive exists
if [ ! -d "${APP_PATH}" ]; then
    echo -e "${RED}Error: App bundle not found at ${APP_PATH}${NC}"
    echo -e "Export notarized app from Xcode to: ${BUILD_DIR}/${APP_NAME}/"
    exit 1
fi

echo -e "App: ${GREEN}${APP_NAME}${NC}"
echo -e "Version: ${GREEN}${VERSION}${NC}"
echo ""

# Clean previous DMG
rm -f "${DMG_PATH}"
rm -rf "${DMG_DIR}"

# Create DMG contents directory
echo -e "${YELLOW}Preparing DMG contents...${NC}"
mkdir -p "${DMG_DIR}"

# Copy app to DMG directory
cp -R "${APP_PATH}" "${DMG_DIR}/"

# Create Applications symlink
ln -s /Applications "${DMG_DIR}/Applications"

# Create DMG directly (compressed)
echo ""
echo -e "${YELLOW}Creating DMG...${NC}"

hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

# Clean up
rm -rf "${DMG_DIR}"

# Show result
if [ -f "${DMG_PATH}" ]; then
    DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  DMG Created Successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "  File: ${DMG_NAME}"
    echo -e "  Size: ${DMG_SIZE}"
    echo -e "  Path: ${DMG_PATH}"
    echo ""

    # Verify architectures in DMG
    echo -e "${YELLOW}Verifying DMG contents...${NC}"
    TEMP_MOUNT=$(hdiutil attach -nobrowse -quiet "${DMG_PATH}" | grep -E "^/dev/" | tail -1 | awk '{print $NF}')
    if [ -n "${TEMP_MOUNT}" ]; then
        BINARY="${TEMP_MOUNT}/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
        if [ -f "${BINARY}" ]; then
            echo -e "Architectures: $(lipo -info "${BINARY}" | sed 's/.*: //')"
        fi
        hdiutil detach "${TEMP_MOUNT}" -quiet 2>/dev/null || true
    fi
    echo ""
else
    echo -e "${RED}DMG creation failed!${NC}"
    exit 1
fi
