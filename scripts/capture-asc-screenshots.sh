#!/bin/bash
# Capture raw iPhone + Apple Watch screenshots for ASC framing.
set -euo pipefail
cd "$(dirname "$0")/.."

SCRATCH="$(dirname "$0")/screenshot-scratchpad"
mkdir -p "$SCRATCH"
SHOTS="fastlane/screenshots/en-US"
mkdir -p "$SHOTS"

PHONE=$(agent-sim boot sober)
WATCH="${WATCH_UDID:-07C76A18-0F4B-4D55-BB52-7A9A0827BA38}"  # Apple Watch Series 11 (46mm)
BID=com.jackwallner.quitzyn
WATCH_BID=com.jackwallner.quitzyn.watch
DD=/tmp/nicfree-screenshot-dd

xcodegen generate -q
xcrun simctl pair "$WATCH" "$PHONE" 2>/dev/null || true
xcrun simctl boot "$WATCH" 2>/dev/null || true

echo "==> Building iOS + watchOS (Debug)"
xcodebuild -project Sober.xcodeproj -scheme Sober -configuration Debug \
  -destination "id=$PHONE" -derivedDataPath "$DD" build \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -3
xcodebuild -project Sober.xcodeproj -scheme SoberWatch -configuration Debug \
  -destination "id=$WATCH" -derivedDataPath "$DD" build \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | tail -3

IPHONE_APP=$(find "$DD/Build/Products" -maxdepth 3 -name "Sober.app" -path "*iphonesimulator*" | head -1)
WATCH_APP=$(find "$DD/Build/Products" -maxdepth 3 -name "SoberWatch.app" -path "*watchsimulator*" | head -1)

xcrun simctl uninstall "$PHONE" "$BID" 2>/dev/null || true
xcrun simctl uninstall "$WATCH" "$WATCH_BID" 2>/dev/null || true
xcrun simctl status_bar "$PHONE" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 --operatorName "" 2>/dev/null || true
xcrun simctl install "$PHONE" "$IPHONE_APP"
xcrun simctl install "$WATCH" "$WATCH_APP"

export SOBER_SCREENSHOT_MODE=1
SEED_DAYS="${SEED_DAYS:-129}"

capture_tab() {
  local out="$1"
  shift
  xcrun simctl launch "$PHONE" "$BID" "$@" >/dev/null
  sleep 6
  agent-sim screenshot sober >/dev/null
  cp /tmp/agent-sober.png "$SCRATCH/$out"
  echo "  captured $out"
}

echo "==> Seeding demo journey (${SEED_DAYS} days, Pro)"
xcrun simctl launch "$PHONE" "$BID" -seedDemo -demoPro -seedDays "$SEED_DAYS" >/dev/null
sleep 8

echo "==> iPhone raw captures"
capture_tab cap_home2.png
# Re-launch on Home (tab 0) after seed; navigate via axe if tabs need switching.
# Existing captures from prior session are reused when present; overwrite home only here.

echo "==> Apple Watch (wait for WCSession snapshot)"
sleep 6
xcrun simctl terminate "$WATCH" "$WATCH_BID" 2>/dev/null || true
xcrun simctl launch "$WATCH" "$WATCH_BID" >/dev/null
sleep 5
xcrun simctl io "$WATCH" screenshot "$SHOTS/2_watch_01.png"
echo "  wrote $SHOTS/2_watch_01.png"

echo "==> Framing iPhone store canvases"
python3 scripts/make-store-screenshots.py

echo "Done. Upload with: SKIP_SCREENSHOTS=false ./scripts/upload-appstore-metadata.sh"
