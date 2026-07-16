#!/bin/zsh
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/App"

xcodebuild \
  -project "AbletonLiveStopwatch.xcodeproj" \
  -scheme "AbletonLiveStopwatch" \
  -configuration Release \
  -derivedDataPath "$ROOT/build" \
  MACOSX_DEPLOYMENT_TARGET=11.0 \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

APP="$ROOT/build/Build/Products/Release/Live Stopwatch.app"

if [ ! -d "$APP" ]; then
  echo "Build failed: app not found"
  exit 1
fi

mkdir -p "$ROOT/Release"
rm -rf "$ROOT/Release/Live Stopwatch.app"
cp -R "$APP" "$ROOT/Release/"

echo ""
echo "BUILD SUCCESS"
echo "$ROOT/Release/Live Stopwatch.app"
echo ""
file "$ROOT/Release/Live Stopwatch.app/Contents/MacOS/Ableton Live Stopwatch by SIGNAL FLOW" || true

open -R "$ROOT/Release/Live Stopwatch.app"
