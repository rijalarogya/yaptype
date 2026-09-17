#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED="${DERIVED:-$ROOT/build}"
APP_NAME="Cadence"
APP_PATH="$DERIVED/Build/Products/$CONFIGURATION/$APP_NAME.app"
DIST="$ROOT/dist"
STAGE="$DIST/$APP_NAME"
DMG="$DIST/Cadence-0.1.0.dmg"

echo "Building $APP_NAME ($CONFIGURATION)…"
xcodebuild \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app at $APP_PATH" >&2
  exit 1
fi

rm -rf "$DIST"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "Created $DMG"
