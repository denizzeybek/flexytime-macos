#!/bin/bash
#
# build-universal.sh
# Universal Binary (Intel + Apple Silicon) build script for Flexytime
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Project settings
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_NAME="FlexytimeMacOS"
SCHEME_NAME="FlexytimeMacOS"
APP_NAME="Flexytime"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Flexytime Universal Binary Builder${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Clean previous build
echo -e "${YELLOW}Cleaning previous build...${NC}"
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Get version from project
VERSION=$(grep -A1 "MARKETING_VERSION" "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj/project.pbxproj" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
echo -e "Version: ${GREEN}${VERSION}${NC}"

# Build Universal Binary Archive
echo ""
echo -e "${YELLOW}Building Universal Binary Archive...${NC}"
echo -e "  Architecture: arm64 + x86_64"
echo ""

cd "${PROJECT_DIR}"

xcodebuild \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    archive \
    | grep -E "(Building|Signing|error:|warning:|\*\*)" || true

# Check if archive was created
if [ -d "${ARCHIVE_PATH}" ]; then
    echo ""
    echo -e "${GREEN}Archive created successfully!${NC}"
    echo -e "  Path: ${ARCHIVE_PATH}"

    # Show architectures
    APP_BINARY="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"
    if [ -f "${APP_BINARY}" ]; then
        echo ""
        echo -e "${YELLOW}Verifying architectures:${NC}"
        lipo -info "${APP_BINARY}"
    fi
else
    echo -e "${RED}Archive creation failed!${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Build complete!${NC}"
echo -e "Next: Run ./scripts/create-dmg.sh to create DMG"
