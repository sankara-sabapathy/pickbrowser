# PickBrowser

Hover. Choose. Open.

[Download for Mac](https://sankara-sabapathy.github.io/pickbrowser/) · [Latest release](https://github.com/sankara-sabapathy/pickbrowser/releases/latest) · [Release automation](docs/RELEASING.md)

PickBrowser is an open-source macOS menu-bar utility that offers a browser and profile picker when you hover over a supported hyperlink for half a second. Choose **Chrome · Work**, **Brave · Personal**, **Safari**, or another detected destination in one click. Your default browser and ordinary link clicks stay unchanged.

**Status: early release, with automated packaging and signed in-app updates.** The first public builds are ad-hoc signed, not Apple-notarized; macOS may block downloaded copies. Do not disable security protections. Apple release credentials and full real-app acceptance are still required for production distribution. Accessibility permission does not make every application's links readable. PickBrowser stays silent when it cannot verify a hyperlink destination. See [compatibility and manual acceptance](docs/COMPATIBILITY.md).

## Build and run

Requires macOS 14 or later and Xcode Command Line Tools with Swift 6.0 or newer (including Swift Testing). Sparkle 2.9.6 is the only third-party dependency, pinned for repeatable builds; the first build downloads it.

```sh
bash scripts/test.sh
bash scripts/build-app.sh --universal
open dist/PickBrowser.app
```

The test script supplies framework paths when using standalone Command Line Tools; with full Xcode it runs standard Swift Testing. Use `--native` for a faster build for your current Mac. The universal bundle includes Apple silicon and Intel binaries. For regular use, copy `dist/PickBrowser.app` into `/Applications` or `~/Applications` before enabling permissions or launch at login. Quit the old copy before replacing it.

On first launch, click **Enable Accessibility** and enable PickBrowser under **System Settings → Privacy & Security → Accessibility**. Return to the app; detection starts automatically. If a locally rebuilt app loses permission, remove its old Accessibility entry and grant access to the new bundle. Development builds are ad-hoc signed; a stable Developer ID signature is needed for reliable public distribution.

Do not use `swift run` for day-to-day usage: permission and login registration should belong to the packaged `.app`, with a stable location and bundle identifier.

## Use

1. Hover over a hyperlink for 500 ms.
2. Move into the floating picker and click a destination.
3. Move away or press Escape to dismiss it. Scrolling the source application also dismisses it. Scrolling within a long destination list is supported.

The menu-bar menu contains Pause/Resume, Settings, and Quit. Settings lets you hide/reorder destinations, set a custom hover delay from 0.1 to 5 seconds (default 0.5), and opt into launch at login or update checks. Move outside both the link and picker for 250 ms to dismiss; the brief grace allows crossing into the picker. Troubleshooting is off by default and can be enabled for the current session. All destinations are initially visible, with a stable order. Profiles temporarily missing from disk retain their saved order and visibility preferences.

The picker appears beside the current pointer, choosing a side that fits the display. Genuine content hyperlinks qualify even when their text is not a URL. Navigation and button-like links are excluded when the application exposes those semantics; **Include navigation links** opts them in. Purely visual styling cannot be classified reliably.

The small Copy icon copies the verified destination and changes to a checkmark. On supported browser webpages only, the tab icon sends the link to that same browser; its external-link settings control the tab and profile. Use a destination row for explicit Chromium profile selection. **Appearance** adjusts the translucent background's opacity and optional color without fading the text; macOS Reduce Transparency is respected.

In Settings, **Check now…** checks GitHub's latest signed release; **Check for updates automatically** enables daily checks. Both the release feed and downloaded archive are verified before installation. You choose when to install; no silent updates. Builds without update signing configured offer a GitHub releases link instead. See [release setup and recovery](docs/RELEASING.md).

## Browsers

| Destination | Current behavior |
| --- | --- |
| Google Chrome | Existing profiles in the standard Chrome data directory |
| Microsoft Edge | Existing profiles in the standard Edge data directory |
| Brave | Existing profiles in the standard Brave data directory |
| Safari | Browser destination; Safari determines the profile |

Open a newly installed browser once and create a profile before refreshing destinations. Guest, ephemeral, and omitted profiles are excluded. Custom user-data roots, beta/dev browser channels, Firefox, private windows, and explicit Safari profile selection are not included in v0.1. Profile names and locations are read from local metadata; browsing history and cookies are never queried.

## Privacy and permissions

Only Accessibility access is requested. There is no screen capture, OCR, clipboard reading, browser extension, account, telemetry, link history, or default-browser registration. Copy writes the destination to the clipboard only when clicked. URLs otherwise exist transiently while detecting, presenting, or opening a link. Destination ordering/visibility, hover delay, navigation filtering, appearance, welcome state, and update preferences are stored locally. Login registration is opt-in through macOS. Optional update checks contact GitHub; hovered URLs and browser profile data are never included.

The app observes pointer position and dismissal events locally. It does not record keystrokes or consume input intended for other applications. Browser processes receive the chosen URL, as required to open it; their own privacy policies and history behavior still apply. See [privacy details](docs/PRIVACY.md).

## Development

- [Architecture and behavior](docs/ARCHITECTURE.md)
- [Compatibility and manual acceptance](docs/COMPATIBILITY.md)
- [Contributing and releases](CONTRIBUTING.md)

Windows and Linux are future ports. macOS-specific access, screen geometry, presentation, browser discovery, and launching are isolated behind small interfaces; the hover state machine and fixtures define the intended behavior across ports.

MIT licensed.
