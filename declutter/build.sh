#!/bin/bash
# Builds Declutter.app and zips it into declutter/Declutter.zip.
set -euo pipefail
cd "$(dirname "$0")"
BUILD=$(mktemp -d)
APP="$BUILD/Declutter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp src/declutter.sh "$APP/Contents/MacOS/Declutter"
chmod 755 "$APP/Contents/MacOS/Declutter"
python3 src/make_icon.py "$BUILD/AppIcon"
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$BUILD/AppIcon.png" icon.png
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Declutter</string>
  <key>CFBundleDisplayName</key><string>Declutter</string>
  <key>CFBundleIdentifier</key><string>studio.ninebolt.declutter</string>
  <key>CFBundleExecutable</key><string>Declutter</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>10.15</string>
  <key>NSAppleEventsUsageDescription</key><string>Declutter asks Finder to move the apps you choose to the Trash.</string>
</dict>
</plist>
PLIST
rm -f Declutter.zip
(cd "$BUILD" && zip -qry "$OLDPWD/Declutter.zip" Declutter.app)
rm -rf "$BUILD"
echo "Built $(pwd)/Declutter.zip"
