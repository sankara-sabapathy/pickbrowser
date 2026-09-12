#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

MODE="${1:---universal}"
case "$MODE" in
  --universal) ARCHITECTURES=(arm64 x86_64) ;;
  --native) ARCHITECTURES=("$(uname -m)") ;;
  *) printf 'Usage: bash scripts/build-app.sh [--universal|--native]\n' >&2; exit 2 ;;
esac

BINARIES=()
for ARCHITECTURE in "${ARCHITECTURES[@]}"; do
  SCRATCH="$PROJECT_ROOT/.build/release-$ARCHITECTURE"
  TRIPLE="$ARCHITECTURE-apple-macosx14.0"
  swift build --force-resolved-versions --configuration release --product PickBrowser --triple "$TRIPLE" --scratch-path "$SCRATCH"
  BINARY_DIRECTORY="$(swift build --configuration release --triple "$TRIPLE" --scratch-path "$SCRATCH" --show-bin-path)"
  BINARIES+=("$BINARY_DIRECTORY/PickBrowser")
done

VERSION="${PICKBROWSER_VERSION:-$(tr -d '\n' < VERSION)}"
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid version: expected major.minor.patch\n' >&2; exit 1
fi

# Build in a fresh staging directory; leave any previous bundle recoverable.
mkdir -p "$PROJECT_ROOT/dist"
STAGING="$(mktemp -d "$PROJECT_ROOT/dist/.staging.XXXXXX")"
APP="$STAGING/PickBrowser.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
if [ "${#BINARIES[@]}" -eq 2 ]; then
  lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/PickBrowser"
else
  cp "${BINARIES[0]}" "$APP/Contents/MacOS/PickBrowser"
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE "$APP/Contents/Resources/LICENSE"
FRAMEWORK_SOURCE="$SCRATCH/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
test -d "$FRAMEWORK_SOURCE"
ditto "$FRAMEWORK_SOURCE" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$SCRATCH/artifacts/sparkle/Sparkle/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $VERSION" "$APP/Contents/Info.plist"
PUBLIC_KEY="${SPARKLE_PUBLIC_KEY:-}"
if [ -z "$PUBLIC_KEY" ] && [ -f Resources/UpdatePublicKey.txt ]; then
  PUBLIC_KEY="$(tr -d '\n' < Resources/UpdatePublicKey.txt)"
fi
if [ -n "$PUBLIC_KEY" ]; then
  if ! [[ "$PUBLIC_KEY" =~ ^[A-Za-z0-9+/]{43}=$ ]]; then
    printf 'Invalid Sparkle public key\n' >&2; exit 1
  fi
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_KEY" "$APP/Contents/Info.plist"
fi
chmod 755 "$APP/Contents/MacOS/PickBrowser"
plutil -lint "$APP/Contents/Info.plist"

IDENTITY="${PICKBROWSER_SIGNING_IDENTITY:--}"
SIGN_ARGS=(--force --sign "$IDENTITY")
if [ "$IDENTITY" != "-" ]; then SIGN_ARGS+=(--options runtime --timestamp); fi
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
# Sign nested code inside-out; do not use --deep as a signing shortcut.
for COMPONENT in \
  "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" \
  "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" \
  "$FRAMEWORK/Versions/B/Autoupdate" \
  "$FRAMEWORK/Versions/B/Updater.app" \
  "$FRAMEWORK" "$APP"; do
  codesign "${SIGN_ARGS[@]}" "$COMPONENT"
done
codesign --verify --deep --strict --verbose=2 "$APP"

if [ -e "$PROJECT_ROOT/dist/PickBrowser.app" ]; then
  BACKUP="$(mktemp -d "$PROJECT_ROOT/dist/.previous.XXXXXX")"
  mv "$PROJECT_ROOT/dist/PickBrowser.app" "$BACKUP/PickBrowser.app"
  printf 'Previous bundle preserved at %s\n' "$BACKUP/PickBrowser.app"
fi
mv "$APP" "$PROJECT_ROOT/dist/PickBrowser.app"
rmdir "$STAGING"
printf '\nBuilt %s\n' "$PROJECT_ROOT/dist/PickBrowser.app"
lipo -info "$PROJECT_ROOT/dist/PickBrowser.app/Contents/MacOS/PickBrowser"
