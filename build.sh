#!/bin/zsh
# Builds a Universal (arm64 + x86_64) HoverFocus.app and a drag-to-Applications DMG into ./build
set -e
cd "$(dirname "$0")"
APP=build/HoverFocus.app
rm -rf build && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources build/obj
for arch in arm64 x86_64; do
  swiftc -O -swift-version 5 -target $arch-apple-macos13.0 -o build/obj/$arch Sources/HoverFocus/*.swift
done
lipo -create build/obj/arm64 build/obj/x86_64 -output $APP/Contents/MacOS/HoverFocus
rm -rf build/obj
cp Resources/AppIcon.icns $APP/Contents/Resources/
cat > $APP/Contents/Info.plist <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>HoverFocus</string>
<key>CFBundleDisplayName</key><string>HoverFocus</string>
<key>CFBundleIdentifier</key><string>com.hoverfocus.app</string>
<key>CFBundleExecutable</key><string>HoverFocus</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PL
codesign --force --sign - $APP
mkdir build/dmg && cp -R $APP build/dmg/ && ln -s /Applications build/dmg/Applications
hdiutil create -quiet -volname HoverFocus -srcfolder build/dmg -ov -format UDZO build/HoverFocus.dmg
rm -rf build/dmg
lipo -archs $APP/Contents/MacOS/HoverFocus
echo "Built $APP and build/HoverFocus.dmg"
