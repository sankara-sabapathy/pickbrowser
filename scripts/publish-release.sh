#!/bin/bash
set -euo pipefail
: "${PICKBROWSER_VERSION:?}" "${GITHUB_SHA:?}" "${GITHUB_REPOSITORY:?}"
TAG="v$PICKBROWSER_VERSION"
MASTER_SHA="$(gh api "repos/$GITHUB_REPOSITORY/git/ref/heads/master" --jq .object.sha)"
if [ "$MASTER_SHA" != "$GITHUB_SHA" ]; then
  printf 'A newer commit is on master; its workflow will publish the next release.\n'; exit 0
fi
NOTES="Universal macOS 14+ app (Apple silicon and Intel). This release adds optional nicknames for browser destinations and an 80–140% widget-size control in Settings. Nicknames affect only the label shown in PickBrowser; profile launching continues to use the detected browser and stable profile identifier. For first-time installation, download PickBrowser.dmg, open it, and drag PickBrowser onto Applications before launching. PickBrowser-macOS.zip is reserved for signed Sparkle updates. Automatic update checking is optional and off by default."
if [ "${PICKBROWSER_SIGNING_IDENTITY:--}" = "-" ]; then
  NOTES="$NOTES

IMPORTANT: This build is ad-hoc signed and is NOT Apple-notarized. Gatekeeper may block it. It is a development distribution, not a Gatekeeper-approved public build. Do not disable macOS security protections. Developers can build from source. Replacing an ad-hoc build may require granting Accessibility access again."
else
  NOTES="$NOTES

This build is Developer ID signed and notarized by Apple."
fi
# Stage all assets in a draft before it can become /releases/latest. Published
# versions are never replaced. Retrying a failed draft is safe.
if ! gh release view "$TAG" >/dev/null 2>&1; then
  gh release create "$TAG" --target "$GITHUB_SHA" --title "PickBrowser $TAG" --draft --generate-notes --notes "$NOTES"
fi
IS_DRAFT="$(gh release view "$TAG" --json isDraft --jq .isDraft)"
if [ "$IS_DRAFT" != "true" ]; then printf 'Release is already published; leaving it unchanged.\n'; exit 0; fi
gh release upload "$TAG" dist/release/PickBrowser.dmg dist/release/PickBrowser-macOS.zip dist/release/appcast.xml dist/release/SHA256SUMS.txt --clobber
gh release edit "$TAG" --draft=false --latest
