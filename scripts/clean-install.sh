#!/bin/bash
#
# clean-install.sh
# Resets Flexytime to a fresh install state (data, logs, preferences, permissions)
#

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

BUNDLE_ID="com.flexytime.FlexytimeMacOS"
OLD_BUNDLE_IDS=("com.flexytime.FlexyMacV2" "com.eclone.flexytime")

echo -e "${YELLOW}Cleaning Flexytime data...${NC}"

# Kill running app
killall Flexytime 2>/dev/null && echo "  Stopped running Flexytime" || true

# App data (config, cache, .trc files)
rm -rf ~/Library/Application\ Support/flexytime/
echo "  Removed Application Support/flexytime"

# Logs
rm -rf ~/Library/Logs/flexytime/
echo "  Removed Logs/flexytime"

# Preferences
defaults delete "$BUNDLE_ID" 2>/dev/null && echo "  Removed $BUNDLE_ID preferences" || true
rm -f ~/Library/Preferences/"$BUNDLE_ID".plist

for old_id in "${OLD_BUNDLE_IDS[@]}"; do
    defaults delete "$old_id" 2>/dev/null && echo "  Removed $old_id preferences" || true
    rm -f ~/Library/Preferences/"$old_id".plist
done

# TCC permissions (Accessibility & Screen Recording)
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null && echo "  Reset Accessibility for $BUNDLE_ID" || true
tccutil reset ScreenCapture "$BUNDLE_ID" 2>/dev/null && echo "  Reset ScreenCapture for $BUNDLE_ID" || true

for old_id in "${OLD_BUNDLE_IDS[@]}"; do
    tccutil reset Accessibility "$old_id" 2>/dev/null || true
    tccutil reset ScreenCapture "$old_id" 2>/dev/null || true
done

echo ""
echo -e "${GREEN}Done! Flexytime is reset to a fresh install state.${NC}"
