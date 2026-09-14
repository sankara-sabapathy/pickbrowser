# Releases and maintenance

Repository: https://github.com/sankara-sabapathy/pickbrowser

Download page: https://sankara-sabapathy.github.io/pickbrowser/

## Automatic releases

Every push/merge to `master` runs Release: tests, universal build, signature verification, optional Apple notarization, signed Sparkle feed, checksums, and a GitHub release with a `vMAJOR.MINOR.PATCH` tag. `VERSION` is the minimum next version; existing release tags determine automatic patch increments. Set `VERSION` to a larger minor/major version to advance that series. A retry on a tagged commit uses the same version and never replaces a published release. Releases are staged as drafts until all assets are uploaded. Superseded commits do not publish over newer master builds. Do not force-push master or move release tags.

Branch pushes and pull requests run the macOS CI build without signing secrets. Pages deploys `site/` automatically on master changes and can also be dispatched manually. Repository Settings → Pages must use **GitHub Actions** as its source. Use the Release and GitHub Pages workflow statuses to confirm publication; a green local build does not prove either deployment.

Assets are `PickBrowser.dmg` for first-time installation, `PickBrowser-macOS.zip` for Sparkle updates, `appcast.xml`, and `SHA256SUMS.txt`. Both packages contain the same universal `.app`. The DMG presents PickBrowser on the left and an Applications shortcut on the right. The landing page selects the DMG from GitHub's latest stable release; if the API is unavailable, its download link falls back to the release page. Windows and Linux binaries are not produced.

## Update signing — required

Sparkle 2.9.6 is pinned in `Package.swift` and `Package.resolved`. The framework's license is embedded in the application. Both the feed and the ZIP are Ed25519 signed. Downloads are verified before extraction. Feed-signature verification has no time-based fallback. The feed is generated before the DMG is added to the release directory, so the ZIP remains Sparkle's sole update enclosure. It is served by GitHub's `/releases/latest/download/appcast.xml`; its archive URL pins the exact release tag, avoiding latest-feed/latest-archive races.

The signing public key is tracked in `Resources/UpdatePublicKey.txt`. The private key belongs only in the maintainer's Keychain and GitHub Actions secret `SPARKLE_PRIVATE_KEY`. Never commit or print it. Initial setup, after `swift package resolve`:

```sh
bash scripts/configure-updates.sh
```

The script uses Keychain account `app.pickbrowser.PickBrowser`, reuses existing keys, securely transfers the private key into the repository's Actions secret, and removes its temporary export. Save the printed **public** key in `Resources/UpdatePublicKey.txt`. The public variable `SPARKLE_PUBLIC_KEY` is informational; the tracked key is the release build source of truth. Back up the private key securely outside this repository. Losing it can break updates for installed builds; read [Sparkle key rotation](https://sparkle-project.org/documentation/) before changing it. Do not rotate keys casually.

Automatic checks are off on first launch, with no unsolicited opt-in prompt. Settings can enable daily checks or perform a manual check. Sparkle handles progress, cryptographic verification, errors, user-confirmed installation, and relaunch. Silent installs and system profiling are disabled. Unconfigured development bundles do not start the updater. Do not test installation against someone's working copy without their knowledge.

For a local signed update archive using the Keychain key:

```sh
PICKBROWSER_VERSION=0.2.0 bash scripts/build-app.sh --universal
PICKBROWSER_VERSION=0.2.0 GITHUB_REPOSITORY=sankara-sabapathy/pickbrowser \
  PICKBROWSER_SPARKLE_ACCOUNT=app.pickbrowser.PickBrowser bash scripts/release-artifacts.sh
```

## Apple signing and notarization

**An Ed25519 update signature is not Apple notarization.** Without Apple credentials the workflow publishes a clearly labelled development distribution, ad-hoc signed and not Gatekeeper-approved. macOS may block downloaded copies, and upgrades may require renewed Accessibility permission. Do not tell users to disable Gatekeeper. A locally compiled app is suitable for development; production public distribution still needs the credentials and acceptance checks below.

Add these repository Actions secrets:

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE_P12` | Base64-encoded exported Developer ID Application certificate and private key |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting that export |
| `APPLE_ID` | Apple developer account email |
| `APPLE_APP_PASSWORD` | App-specific password used by notarytool |
| `APPLE_TEAM_ID` | Developer team ID |

Set repository variable `REQUIRE_NOTARIZATION=true` before a production launch. This makes missing Apple credentials a hard failure; partial credential configurations already fail. The workflow imports the certificate into a temporary keychain, signs all nested Sparkle code inside-out with hardened runtime and timestamping, notarizes, staples, checks Gatekeeper assessment, and only then packages/signs the download. Its temporary keychain is removed even on failure. No release is published if signing, notarization, verification, or tests fail.

An installed path and bundle identifier alone do not preserve Accessibility consent for ad-hoc builds: their designated requirement is tied to the particular binary. Use a consistent Developer ID identity for successive releases; never weaken the designated requirement or modify the user's TCC database to avoid consent. See [Apple TN3127](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements).

The Apple credential path cannot be validated without real release credentials. Before calling a release production-ready, complete [manual acceptance](COMPATIBILITY.md), including a clean downloaded install and an older-to-newer in-app update. Test Apple silicon and Intel, macOS 14 and a current macOS, with Accessibility/login preferences preserved.

## DMG packaging

`scripts/build-dmg.sh` copies the already-signed app into a version-named read/write image, adds an `/Applications` shortcut and installation artwork, writes a Finder icon-view layout, then converts it to a compressed read-only DMG. Versioned volume names prevent Finder from reusing an older installer's cached view. The shared verifier mounts the finished image read-only and checks the app, shortcut, actual saved icon coordinates, window bounds, background, expected version, disk integrity, and nested app signatures. Builds use hash-pinned `ds-store` and `mac-alias` libraries in a project-local Python environment; no Finder automation, Accessibility permission, or interactive desktop is required. With a Developer ID identity, the DMG is signed, submitted to Apple's notary service, stapled, and Gatekeeper-assessed after the already-notarized app is packaged. The standalone verifier is `scripts/verify-dmg.sh`.

Run the same packaging check locally after building the app:

```sh
bash scripts/build-dmg.sh dist/PickBrowser.app dist/release/PickBrowser.dmg
```

## Recovery

Do not replace published binaries, move tags, or point latest at an older version. Ship a higher-version fix. Failed uploads can leave a draft: rerun that same commit, inspect the staged assets, and publish only after validation. Never mark a draft as latest manually before its signed assets exist. If a release key is compromised, follow Sparkle's key-rotation procedure and coordinate the recovery with users.

Protect master with pull-request review and required CI checks before adding other contributors. Keep Actions and Sparkle updates reviewed; Dependabot proposes updates weekly. The public release job receives signing secrets only on master or an explicit master dispatch, never on a pull-request trigger.
