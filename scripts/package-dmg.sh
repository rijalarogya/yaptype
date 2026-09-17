#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export PATH="${DEVELOPER_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/bin:${DEVELOPER_DIR}/usr/bin:${PATH}"
SDKROOT="${SDKROOT:-$(ls -d ${DEVELOPER_DIR}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk | tail -1)}"
export SDKROOT

CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED="${DERIVED:-$ROOT/build}"
APP_NAME="Yaptype"
DIST="$ROOT/dist"
STAGE="$DIST/stage"
DMG="$DIST/Yaptype-0.1.0.dmg"
XCODE_APP="$DERIVED/Build/Products/$CONFIGURATION/$APP_NAME.app"
SPM_APP="$ROOT/.build/Yaptype.app"

echo "Building $APP_NAME…"

XCODEBUILD="${DEVELOPER_DIR}/usr/bin/xcodebuild"
APP_PATH=""

    if "$XCODEBUILD" -scheme "$APP_NAME" -project Yaptype.xcodeproj -showBuildSettings >/dev/null 2>&1; then
  SIGN_IDENTITY="-"
  if SIGN_NAME="$("$ROOT/scripts/ensure-codesign-identity.sh")"; then
    SIGN_IDENTITY="$SIGN_NAME"
  fi
  "$XCODEBUILD" \
    -scheme "$APP_NAME" \
    -project Yaptype.xcodeproj \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    build
  APP_PATH="$XCODE_APP"
else
  echo "xcodebuild needs the Xcode license. Building with SwiftPM instead."
  spm_config="release"
  if [[ "$CONFIGURATION" != "Release" ]]; then
    spm_config="debug"
  fi
  swift build -c "$spm_config" --product Yaptype
  BIN="$(swift build -c "$spm_config" --product Yaptype --show-bin-path)/$APP_NAME"
  if [[ ! -x "$BIN" ]]; then
    echo "SwiftPM binary not found at $BIN" >&2
    exit 1
  fi

  rm -rf "$SPM_APP"
  mkdir -p "$SPM_APP/Contents/MacOS" "$SPM_APP/Contents/Resources"
  cp "$BIN" "$SPM_APP/Contents/MacOS/$APP_NAME"
  cp "$ROOT/packaging/Info.plist" "$SPM_APP/Contents/Info.plist"
  if [[ -f "$ROOT/packaging/AppIcon.icns" ]]; then
    cp "$ROOT/packaging/AppIcon.icns" "$SPM_APP/Contents/Resources/AppIcon.icns"
  fi
  BIN_DIR="$(dirname "$BIN")"
  if [[ -d "$BIN_DIR/Yaptype_Yaptype.bundle" ]]; then
    cp -R "$BIN_DIR/Yaptype_Yaptype.bundle" "$SPM_APP/Contents/Resources/"
  fi
  if [[ -d "$ROOT/Yaptype/Resources/Assets.xcassets" ]]; then
    cp -R "$ROOT/Yaptype/Resources/Assets.xcassets" "$SPM_APP/Contents/Resources/"
  fi
  SIGN_IDENTITY="-"
  if SIGN_NAME="$("$ROOT/scripts/ensure-codesign-identity.sh")"; then
    SIGN_IDENTITY="$SIGN_NAME"
  fi
  echo "Signing with $SIGN_IDENTITY"
  if ! codesign --force --sign "$SIGN_IDENTITY" --identifier app.yaptype.macos --entitlements "$ROOT/Yaptype/Resources/Yaptype.entitlements" "$SPM_APP"; then
    echo "Stable identity failed; signing ad-hoc."
    codesign --force --sign - --identifier app.yaptype.macos --entitlements "$ROOT/Yaptype/Resources/Yaptype.entitlements" "$SPM_APP"
  fi
  codesign -d -r- "$SPM_APP" || true
  APP_PATH="$SPM_APP"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app at $APP_PATH" >&2
  exit 1
fi

rm -rf "$DIST"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/${APP_NAME}.app"
ln -sf /Applications "$STAGE/Applications"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "Created $DMG"