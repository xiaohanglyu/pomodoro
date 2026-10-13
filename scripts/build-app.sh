#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app="build/Pomodoro.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Pomodoro" "$app/Contents/MacOS/Pomodoro"
cp Resources/Info.plist "$app/Contents/Info.plist"
iconutil -c icns Tomato.iconset -o "$app/Contents/Resources/Tomato.icns"
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
