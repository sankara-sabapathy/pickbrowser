# Contributing

Use macOS 14+ and Swift 6.0+ from Xcode or the Command Line Tools, including Swift Testing. The package pins Sparkle for verified updates and uses Swift 5 language mode for compatibility with AppKit callbacks.

```sh
bash scripts/test.sh
bash scripts/build-app.sh --native
open dist/PickBrowser.app
```

Keep hover timing, stale-result handling, destination ordering, and launch argument behavior in `PickBrowserCore` with deterministic tests. Keep AppKit, Accessibility, ServiceManagement, and process launching in the macOS executable. Use monotonic time. Do not run AX queries or profile-file reads on the main thread.

Never infer a hyperlink from a containing document URL or arbitrary displayed text. Never add shell interpolation for browser commands or silently fall back to another browser/profile. Do not add URL logging, telemetry, automatic routing, or broader permissions as incidental changes.

For compatibility changes, include the app/browser/macOS versions and the relevant [manual acceptance](docs/COMPATIBILITY.md) results. Use synthetic links/profile data in fixtures, never personal URLs or browser metadata. Automated tests must not launch a real browser or manipulate user profiles.

## Packaging and releases

`bash scripts/build-app.sh --universal` compiles release binaries for arm64 and x86_64, combines them with `lipo`, embeds Sparkle, writes a conventional `.app`, and signs/verifies its nested code. Existing output bundles are preserved in `dist/.previous.*`. Pull-request/branch CI runs tests and uploads a zip. Master pushes run the versioned Release workflow and automatically deploy the download website. See [release setup, signing credentials, and recovery](docs/RELEASING.md).

For a production public build, configure the Apple signing/notarization secrets and set `REQUIRE_NOTARIZATION=true` as documented. The workflow then enables hardened runtime and timestamping, notarizes, staples, and assesses the packaged app before publishing. Those credentials must never be committed. Without them, releases explicitly disclose that they are development distributions. Do not describe ad-hoc builds as notarized or Gatekeeper-approved.

Keep the bundle identifier and installation location stable for Accessibility and login-item registration. Quit the running app before replacing it. Rebuilt ad-hoc signatures may require permission to be granted again.

## Diagnostics and UI previews

`dist/PickBrowser.app/Contents/MacOS/PickBrowser --diagnose` reports the diagnostic process's Accessibility status, macOS version, and destination counts per browser. A terminal-launched process's trust status may differ from the GUI app; use Settings in the running app to confirm GUI permission. It does not print profile names or URLs, request permission, or launch a browser.

For a GUI-context trace, quit other PickBrowser copies and launch `open --stdout /tmp/pickbrowser-hover.log --stderr /tmp/pickbrowser-hover-errors.log dist/PickBrowser.app --args --trace-hover`. This opt-in mode prints only detection status/role names, never URLs or page text. Quit and relaunch normally to stop tracing.

After `swift build`, `.build/debug/PickBrowser --render-preview .build/previews` renders light/dark settings and picker snapshots using synthetic profile names. This command exists only in debug builds; it does not inspect other applications or capture the screen.

The project uses the MIT license. Contributions are provided under the same license.
