#!/bin/bash

# FlexyMacV2 - TCC Permissions Reset Script
# Use this script if permissions appear granted but aren't working

echo "=========================================="
echo "FlexyMacV2 - TCC Permissions Reset"
echo "=========================================="
echo ""
echo "This script will reset Accessibility and Screen Recording permissions."
echo "You will need to re-grant permissions after running this."
echo ""
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

echo ""
echo "Resetting Accessibility permissions..."
sudo tccutil reset Accessibility

echo ""
echo "Resetting Screen Recording permissions..."
sudo tccutil reset ScreenCapture

echo ""
echo "=========================================="
echo "Done! Now please:"
echo "1. Quit FlexyMacV2 completely"
echo "2. Open System Settings → Privacy & Security → Accessibility"
echo "   → Add FlexyMacV2 and enable it"
echo "3. Open System Settings → Privacy & Security → Screen Recording"
echo "   → Add FlexyMacV2 and enable it"
echo "4. Restart FlexyMacV2"
echo "=========================================="
