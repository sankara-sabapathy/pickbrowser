#!/bin/bash
# Run once by a maintainer. The private key stays in Keychain and an Actions secret.
set -euo pipefail
cd "$(dirname "$0")/.."
REPOSITORY="sankara-sabapathy/pickbrowser"
TOOLS=".build/artifacts/sparkle/Sparkle/bin"
test -x "$TOOLS/generate_keys"
"$TOOLS/generate_keys" --account app.pickbrowser.PickBrowser
SECRET_DIRECTORY="$(mktemp -d -t pickbrowser-signing-key)"
SECRET_FILE="$SECRET_DIRECTORY/private-key"
trap 'rm -f "$SECRET_FILE"; rmdir "$SECRET_DIRECTORY"' EXIT
"$TOOLS/generate_keys" --account app.pickbrowser.PickBrowser -x "$SECRET_FILE"
gh secret set SPARKLE_PRIVATE_KEY --repo "$REPOSITORY" < "$SECRET_FILE"
PUBLIC_KEY="$("$TOOLS/generate_keys" --account app.pickbrowser.PickBrowser -p)"
gh variable set SPARKLE_PUBLIC_KEY --repo "$REPOSITORY" --body "$PUBLIC_KEY"
printf 'Public key (commit in Resources/UpdatePublicKey.txt): %s\n' "$PUBLIC_KEY"
