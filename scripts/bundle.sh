#!/bin/bash
# Builds a release binary and wraps it in build/Lookhere.app with its icon (ad-hoc signed).
# Extra arguments go to `swift build`; Homebrew passes --disable-sandbox.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release "$@"
BIN="$(swift build -c release "$@" --show-bin-path)/Lookhere"
APP=build/Lookhere.app
rm -rf "$APP" build/AppIcon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Lookhere"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/Glove.png Resources/MiddleFinger.png "$APP/Contents/Resources/"
# Run from inside the app so it finds the glove pictures for the icon.
"$APP/Contents/MacOS/Lookhere" --iconset build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
echo "Built $APP"
