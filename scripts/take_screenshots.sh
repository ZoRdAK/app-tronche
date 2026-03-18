#!/bin/bash
set -e

SCREENSHOTS_DIR="ios/fastlane/screenshots/fr-FR"
SIM_UDID="02646223-345C-49EA-92A4-86556630167F"

echo "Taking Tronche! App Store screenshots..."

# Ensure simulator is booted
xcrun simctl boot $SIM_UDID 2>/dev/null || true
sleep 5

# Clean previous screenshots
rm -f "$SCREENSHOTS_DIR"/*.png

# Run integration test with screenshot mode enabled
fvm flutter test integration_test/screenshot_test.dart \
  -d $SIM_UDID \
  --dart-define=SCREENSHOT_MODE=true 2>&1 | tee /tmp/screenshot_test.log

# Copy screenshots from test results to fastlane directory
# Integration test screenshots are saved in the app's documents directory
# or in the test results depending on the platform

echo "Screenshots complete! Check $SCREENSHOTS_DIR/"
ls -la "$SCREENSHOTS_DIR/"
