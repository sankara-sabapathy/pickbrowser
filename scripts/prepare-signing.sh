#!/bin/bash
set -euo pipefail
: "${SPARKLE_PRIVATE_KEY:?Configure SPARKLE_PRIVATE_KEY before releasing}"
test -s Resources/UpdatePublicKey.txt
if [ -z "${APPLE_CERTIFICATE_P12:-}" ]; then
  if [ "${REQUIRE_NOTARIZATION:-false}" = "true" ]; then
    printf 'Notarization is required but Apple credentials are missing\n' >&2; exit 1
  fi
  # Partial credential setups are errors, not a silent downgrade.
  for NAME in APPLE_ID APPLE_APP_PASSWORD APPLE_TEAM_ID APPLE_CERTIFICATE_PASSWORD; do
    if [ -n "${!NAME:-}" ]; then printf 'Incomplete Apple signing configuration\n' >&2; exit 1; fi
  done
  printf '::warning::Development distribution: ad-hoc signed, not notarized by Apple.\n'
  exit 0
fi
: "${APPLE_CERTIFICATE_PASSWORD:?}" "${APPLE_ID:?}" "${APPLE_APP_PASSWORD:?}" "${APPLE_TEAM_ID:?}"
KEYCHAIN="$RUNNER_TEMP/pickbrowser-signing.keychain-db"
CERTIFICATE="$RUNNER_TEMP/pickbrowser-signing.p12"
KEYCHAIN_PASSWORD="$(openssl rand -hex 32)"
# No secret values are printed or passed through workflow expressions in shell source.
printf '%s' "$APPLE_CERTIFICATE_P12" | base64 --decode > "$CERTIFICATE"
chmod 600 "$CERTIFICATE"
trap 'rm -f "$CERTIFICATE"' EXIT
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security set-keychain-settings -lut 21600 "$KEYCHAIN"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN"
security import "$CERTIFICATE" -k "$KEYCHAIN" -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN" >/dev/null
security list-keychains -d user -s "$KEYCHAIN"
IDENTITY="$(security find-identity -v -p codesigning "$KEYCHAIN" | awk '/Developer ID Application/ {print $2; exit}')"
test -n "$IDENTITY"
printf 'PICKBROWSER_SIGNING_IDENTITY=%s\n' "$IDENTITY" >> "$GITHUB_ENV"
