#!/bin/sh
# Builds FlashPaste.app into ./build and ad-hoc signs it.
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/FlashPaste.app"
BUNDLE_ID="${BUNDLE_ID:-com.example.flashpaste}"
VERSION="${VERSION:-1.0.0}"

cd "$ROOT"
swift build -c release
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/FlashPaste" "$APP/Contents/MacOS/FlashPaste"
cp Resources/menubar.pdf Resources/AppIcon.icns "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>FlashPaste</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>FlashPaste</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>MIT License</string>
</dict>
</plist>
PLIST
codesign --force --deep -s - "$APP"
# An ad-hoc signature changes on every build, which invalidates the Accessibility grant.
# Reset it so the next launch prompts cleanly instead of silently staying untrusted.
tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
echo "built $APP"
