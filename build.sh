#!/bin/bash
# Builds /Applications/Timer.app: release binary + icon + Info.plist, signed.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --product WorkTimer
BIN="$(swift build -c release --show-bin-path)/WorkTimer"
APP="/Applications/Timer.app"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp AppIcon.icns "$APP/Contents/Resources/" # from make-icon.swift
# Copied next to the old binary and renamed over it: writing into the binary of a running Timer kills it.
# This way the running one keeps its copy and the new build starts on the next launch.
cp "$BIN" "$APP/Contents/MacOS/WorkTimer.new"
mv -f "$APP/Contents/MacOS/WorkTimer.new" "$APP/Contents/MacOS/WorkTimer"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.pawel.timer</string>
    <key>CFBundleName</key><string>Timer</string>
    <key>CFBundleDisplayName</key><string>Timer</string>
    <key>CFBundleExecutable</key><string>WorkTimer</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

xattr -cr "$APP"
# Signed with the Apple Development certificate when there is one: macOS ties the notification and login item grants
# to the signature, and an ad-hoc one changes with every build.
IDENTITY="$(security find-identity -v -p codesigning | awk '/Apple Development/ { print $2; exit }')"
codesign --force --sign "${IDENTITY:--}" "$APP"
echo "Built $APP"
