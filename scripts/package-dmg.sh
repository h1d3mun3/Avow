#!/usr/bin/env bash
set -euo pipefail

# Package an already-signed, notarized .app into a distributable DMG.
# Export the .app from Xcode Organizer → Distribute App → Direct Distribution first.
#
# Usage: ./scripts/package-dmg.sh [path/to/Avow.app]   (defaults to ./Avow.app)

APP="${1:-Avow.app}"
APP_NAME="$(basename "$APP" .app)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="${APP_NAME}-${VERSION}.dmg"

STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"

echo "Created: $DMG"
