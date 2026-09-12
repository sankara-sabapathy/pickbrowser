#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
: "${PICKBROWSER_VERSION:?Release version is required}"
: "${GITHUB_REPOSITORY:?Repository is required}"
APP="dist/PickBrowser.app"
OUTPUT="dist/release"
mkdir -p "$OUTPUT"
if [ "${PICKBROWSER_SIGNING_IDENTITY:--}" != "-" ]; then
  : "${APPLE_ID:?}" "${APPLE_APP_PASSWORD:?}" "${APPLE_TEAM_ID:?}"
  ditto -c -k --sequesterRsrc --keepParent "$APP" dist/notarization.zip
  xcrun notarytool submit dist/notarization.zip --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID" --wait --timeout 20m
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
fi
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/PickBrowser-macOS.zip"
# Feed points to immutable version-specific assets, not a mutable latest binary.
TOOLS=".build/release-arm64/artifacts/sparkle/Sparkle/bin"
SIGNING_ARGS=()
if [ -n "${SPARKLE_PRIVATE_KEY:-}" ]; then
  SIGNING_ARGS=(--ed-key-file -)
else
  : "${PICKBROWSER_SPARKLE_ACCOUNT:?Provide a signing secret or an explicit local Keychain account}"
  SIGNING_ARGS=(--account "$PICKBROWSER_SPARKLE_ACCOUNT")
fi
printf '%s' "${SPARKLE_PRIVATE_KEY:-}" | "$TOOLS/generate_appcast" "${SIGNING_ARGS[@]}" \
  --maximum-deltas 0 --download-url-prefix "https://github.com/$GITHUB_REPOSITORY/releases/download/v$PICKBROWSER_VERSION/" \
  "$OUTPUT"
test -s "$OUTPUT/appcast.xml"
printf '%s' "${SPARKLE_PRIVATE_KEY:-}" | "$TOOLS/sign_update" "${SIGNING_ARGS[@]}" --verify "$OUTPUT/appcast.xml"
python3 scripts/verify-appcast.py "$OUTPUT/appcast.xml" "$OUTPUT/PickBrowser-macOS.zip" "$PICKBROWSER_VERSION" "$GITHUB_REPOSITORY"
(cd "$OUTPUT" && shasum -a 256 PickBrowser-macOS.zip appcast.xml > SHA256SUMS.txt)
