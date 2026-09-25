#!/bin/bash
#
# Builds a universal Release of Conteng, signs it with the project's self-signed
# certificate, and packages it as dist/Conteng-<version>-macOS-universal.zip.
#
# Signing every release with the same certificate gives Conteng a stable code
# signing identity, so macOS treats an update as the same app and keeps the
# permissions the user already granted. Ad-hoc signatures change with every build.
#
# Usage: scripts/release.sh
# Set CONTENG_SIGNING_IDENTITY to sign with a certificate of another name.

set -euo pipefail

IDENTITY="${CONTENG_SIGNING_IDENTITY:-Conteng Self-Signed}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
APP="$BUILD_DIR/Build/Products/Release/Conteng.app"
ENTITLEMENTS="$ROOT/Conteng/Conteng.entitlements"

if ! security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    echo "error: no \"$IDENTITY\" signing identity in the keychain." >&2
    echo "Import the certificate backup (.p12) first. See \"Creating a Release\" in README.md." >&2
    exit 1
fi

echo "==> Building universal Release"
xcodebuild \
    -project "$ROOT/Conteng.xcodeproj" \
    -scheme Conteng \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    clean build \
    | grep -E "error:|warning: .*Conteng/|\*\* BUILD" || true

if [[ ! -d "$APP" ]]; then
    echo "error: build failed, $APP was not produced." >&2
    exit 1
fi

echo "==> Signing with \"$IDENTITY\""
# Nested code has to be signed before the bundle that seals it.
if [[ -d "$APP/Contents/Frameworks" ]]; then
    find "$APP/Contents/Frameworks" -mindepth 1 -maxdepth 1 \( -name "*.dylib" -o -name "*.framework" \) -print0 \
        | while IFS= read -r -d '' nested; do
            codesign --force --timestamp=none --sign "$IDENTITY" "$nested"
        done
fi

codesign --force --timestamp=none --sign "$IDENTITY" --entitlements "$ENTITLEMENTS" "$APP"

codesign --verify --deep --strict "$APP"
REQUIREMENT="$(codesign -d -r- "$APP" 2>&1 | grep "designated =>")"
if [[ "$REQUIREMENT" != *"certificate leaf"* ]]; then
    echo "error: the app is not tied to a certificate: $REQUIREMENT" >&2
    exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")"
ZIP="$DIST_DIR/Conteng-$VERSION-macOS-universal.zip"

echo "==> Packaging $(basename "$ZIP")"
mkdir -p "$DIST_DIR"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/Conteng")"
echo "Requirement:   ${REQUIREMENT#*=> }"
echo "SHA-256:       $(shasum -a 256 "$ZIP" | cut -d ' ' -f 1)"
echo "Output:        $ZIP"
