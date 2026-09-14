# Architecture

PickBrowser is a Swift Package Manager executable, packaged as an unsandboxed macOS application. macOS Accessibility requires user consent; no entitlements for screen recording or Apple Events are used. The app is a menu-bar accessory (`LSUIElement`) with a stable identifier `app.pickbrowser.PickBrowser`.

Packaged builds start only from `/Applications` or the current user's `Applications` directory. A launch from a DMG, Downloads, or App Translocation displays installation guidance before the app delegate is created, so temporary copies never request Accessibility permission or initialize the updater. SwiftPM command-line development builds remain runnable.

## Responsibilities

| Component | Contract |
| --- | --- |
| `LinkDetector` | Asynchronously returns a verified HTTP/HTTPS URL, source identifier, and global screen rectangle, or nil |
| `HoverCoordinator` | Pure state machine receiving pointer, monotonic time, source, permission state, and picker bounds; emits detect/present/dismiss actions |
| `BrowserCatalog` | Discovers local browser/profile destinations with stable IDs |
| `BrowserLauncher` | Dispatches one URL to the selected destination and completes once with success or error |

`PickBrowserCore` depends on Foundation and CoreGraphics geometry, not AppKit. The executable supplies macOS adapters, SwiftUI views, persistence, and the AppKit event loop. Link detection needs no web renderer, daemon, IPC service, or database. The optional Sparkle updater embeds its standard installation helpers and framework; it is separate from the four link-handling interfaces.

## Hover and detection

The host samples the pointer at 20 Hz. After the configured delay (default 500 ms, range 100–5000 ms) within a four-point radius, it hit-tests Accessibility on a serial worker. A delay change resets the coordinator without resetting its request generation, invalidating pending work without reusing request IDs. At most one AX lookup runs at once. The link must be found within twelve elements; enclosing-context inspection can continue up to thirty-two total elements, within the same elapsed-time budget and short per-read timeouts. These limits keep a slow app from blocking the main thread or growing a worker backlog.

Before hit-testing, read the source application's role to activate native accessibility in Chromium. Never write `AXManualAccessibility` or `AXEnhancedUserInterface`: Electron maps these to full screen-reader mode, which triggers editor prompts and can change application behavior. Do not switch VoiceOver, change editor settings, or turn off another assistive client's support. Apps that require forced screen-reader mode to expose their links remain unsupported. Read-only accessibility queries can still cause some applications to infer assistive-technology use; PickBrowser cannot control those heuristics.

The hit test is scoped to the foreground application's AX object. Do not reject returned elements merely because their PID differs from the application PID: embedded web content may be served by a renderer process. The coordinator still rejects stale foreground-app results.

References: [Chromium application-role activation](https://github.com/chromium/chromium/blob/main/chrome/browser/chrome_browser_application_mac.mm), [Electron's manual accessibility API](https://www.electronjs.org/docs/latest/tutorial/accessibility).

Only an `AXLink` with an explicit URL attribute (or a destination-valued value attribute on that same link) qualifies. Absolute HTTP/HTTPS destinations are accepted; a scheme-less domain/path explicitly exposed by an `AXLink` is normalized to HTTPS. Scheme-less labels, relative paths, generic text, the containing document's URL, custom schemes, and missing/empty geometry are rejected. No entire accessibility tree is scraped. The AX Y axis is converted once against the primary display into AppKit global coordinates; negative and vertically stacked display coordinates remain valid.

Bounded ancestor inspection continues above the nearest link to exclude button, menu, toolbar, tab controls, and navigation-landmark contexts by default. `AXTabGroup` is a content container, not sufficient evidence of navigation. The navigation setting permits excluded contexts but never converts a plain button URL into hyperlink evidence. Visible link wording is not a filter. CSS-only appearance cannot reliably establish navigation intent. Encountering an `AXWebArea` records webpage provenance for the source-browser shortcut. Incomplete or timed-out inspection is rejected conservatively.

Request generation and source identity include the source PID. Moving the pointer, switching applications, revoking permission, pausing, clicking, or scrolling invalidates outstanding work. Callbacks recheck the current state before showing UI. Unsupported elements produce no UI and can be retried after another dwell interval.

The picker uses a nonactivating panel on the current display, including full-screen spaces. Only the actual link and panel rectangles keep it open, never their enclosing rectangle. Leaving both for 250 ms dismisses the panel; that grace period permits traversal across the gap. Selecting, Escape, or source scrolling suppresses that link until the pointer leaves it. Destination-list scrolling stays local. Input is observed passively; source-app clicks are not redirected or synthesized.

Placement uses the current cursor at presentation, not the start of the link rectangle. It tries nearby quadrants, clamps within the pointer display's visible frame, and reduces the panel if necessary on unusually small displays. It does not chase the cursor after opening. Background opacity is separate from foreground content; custom tint uses a material backing and contrast-aware text. Reduce Transparency uses an opaque background.

## Profiles and launching

For stable Chrome, Edge, and Brave installations, discovery reads `profile.info_cache` from their standard `Local State` files. It requires existing profile `Preferences` files, filters ephemeral/omitted/guest profiles, and rejects unsafe paths. It reads no cookies or history. Invalid or inaccessible metadata simply provides no destinations. Safari is discovered independently.

Before Chromium launch, revalidate the app, executable, metadata entry, and profile directory. Pass `--user-data-dir`, `--profile-directory`, and URL as separate `Process` arguments. Do not use shell evaluation, kill an existing browser, create a profile, retry automatically, or silently switch destinations.

Warm launches usually forward the URL and exit; cold launches can remain alive. Early nonzero exits produce an error. A process still alive after 1.5 seconds counts as successful dispatch. This is **not proof of page load or correct routing**; manual browser tests are required. Safari uses `NSWorkspace` with an explicit application URL. Errors offer Retry for the same destination, or Cancel. Browser stdout/stderr is discarded so URLs are not captured by PickBrowser.

The header Copy action only writes the verified URL after checking that the displayed candidate is still active. The tab shortcut appears only for supported browser sources with webpage evidence. It sends one URL through `NSWorkspace` to the exact source application, with no fallback, Apple Events, or simulated keystrokes. Browser policy controls tab/window and profile routing; this shortcut cannot promise the current profile. Destination rows retain explicit profile dispatch.

## Preferences and future ports

UserDefaults stores destination order, hidden destination IDs, hover delay, navigation inclusion, appearance, and welcome state. IDs for missing profiles are retained to preserve preferences across temporary unavailability. Login items use `SMAppService`, off by default. Troubleshooting is session-only and off by default. No hovered URL is persisted by PickBrowser; explicitly copied URLs remain on the system clipboard. Sparkle owns its own update preferences; see [release/update architecture](RELEASING.md).

Future native Windows and Linux adapters should preserve the state machine contracts and reuse fixture scenarios. Their accessibility, compositor, global pointer, and overlay capabilities need separate feasibility work before declaring app coverage. No cross-platform runtime is introduced for the macOS release.
