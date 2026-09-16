# Compatibility and manual acceptance

This initial implementation is **not yet certified against real source applications**. Installation or compilation is not a passing hover test. Record the macOS, source-app, and destination-browser versions for every run. Use a packaged `.app` with Accessibility access enabled.

## Destination nickname and widget-size behavior

- Give Chrome, Edge, Brave, and Safari destinations distinct nicknames, then confirm the picker uses those labels while launching the original browser/profile.
- While editing, use the visible Done checkmark or press Return: keyboard focus leaves the field and a clear saved confirmation appears below the list. Clicking elsewhere also confirms the field. Click into another application and confirm the insertion caret stops blinking; returning to Settings must not silently restore text focus. Starting a new edit clears the previous confirmation.
- Clear a nickname and confirm the detected browser/profile title returns. Refresh destinations and relaunch PickBrowser to confirm nicknames persist by stable destination ID.
- Exercise 80%, 100%, and 140% widget sizes near every display edge and on secondary displays. The picker must remain adjacent to the pointer, keep the pointer outside its frame, and scroll long destination lists.

## v0.3.1 screen-sharing behavior — 2026-09-16

- Picker, settings, installation guidance, and error alerts use AppKit's non-shareable window hint by default.
- Apple documents that hint as legacy; full-display ScreenCaptureKit, conferencing apps, screenshots, or remote-desktop capture may still include PickBrowser. No universal app-side exclusion is claimed.
- Pause dismisses an existing picker and prevents new hover detection. Use it before sharing for the reliable behavior; resume afterwards.
- PickBrowser does not request Screen Recording access or inspect capture sessions. Manual acceptance must test window-only and entire-display sharing with the actual conferencing tools in use.

## v0.3 distribution and detection verification — 2026-09-14

- The release produces a DMG for first-time installation while retaining the ZIP as Sparkle's signed update enclosure.
- The finished DMG must mount read-only with `PickBrowser.app`, an `/Applications` shortcut, and a saved Finder icon layout positioning PickBrowser before Applications.
- Packaged apps outside system or user Applications display installation guidance before permission or updater startup. Pure location tests cover DMG, Downloads, App Translocation, similarly named folders, both supported Applications roots, and command-line development builds.
- Manual acceptance still requires downloading the public DMG, dragging to Applications, ejecting, launching, granting Accessibility, and confirming a later Sparkle ZIP update preserves the installed location and permission.
- The user reports browser hover working but Slack and Teams failing in v0.2.3. The supplied Teams trace was `AXMenuBar → AXApplication`, not message content; it does not identify the message-link failure. Troubleshooting now retains eight recent status/role checks so returning via the menu bar does not immediately replace the relevant check.
- Regression fixtures cover verified links nested beyond twelve context elements, tabbed content containers, deeply nested navigation rejection, timeouts, and hard search bounds. These fix demonstrated resolver failures, not yet a verified cure for the reported Slack/Teams sessions.
- Live read-only inspection confirmed that current Teams can expose a message destination as `AXLink` with a scheme-less domain/path value. v0.3 normalizes that explicit destination to HTTPS while continuing to reject labels, relative paths, non-web schemes, buttons, and navigation controls. Pointer-level hover still needs user retesting after installation.
- Ad-hoc releases have build-specific code identities. An Applications install prevents temporary-path issues but cannot promise permission retention across updates; Developer ID signing and real upgrade acceptance remain required.

## v0.2.1 verification — 2026-09-13

- 49 Swift tests pass, including cursor-adjacent placement across display edges, conservative navigation filtering, webpage-only shortcut eligibility, appearance validation, and stale-request rejection when changing dwell.
- Synthetic light/dark picker previews were inspected, including custom tints and the absence of the tab shortcut for non-browser sources.
- The v0.2.1 universal app compiled for arm64 and x86_64; its nested ad-hoc signatures passed verification. Apple notarization and Intel execution remain unverified.
- These tests do not certify real-app navigation semantics, clipboard interaction, tab/profile routing, actual display behavior, or accessibility permission recovery. Those remain manual acceptance items.

## v0.2 verification — 2026-09-12

- 33 Swift tests pass, including the previously sticky area between the link and the wider picker, gap traversal/dismissal, and configurable dwell limits.
- Five release-version tests pass. Universal arm64/x86_64 app builds with the pinned Sparkle framework; nested signatures are verified locally.
- Settings and picker render with synthetic data. The download website's local assets and JavaScript syntax are checked.
- The user reports that the picker now appears but stays open after moving away in the preceding build. v0.2 removes the broad enclosing hover region. Native end-to-end pointer behavior still requires user retesting; pure state-machine tests are not equivalent to an OS-level hover test.
- Update feed/archive signing is tested during packaging. Real in-app replacement, Apple notarization, Intel runtime, macOS 14 runtime, and full app/profile routing acceptance remain pending.

## Original build verification — 2026-09-12

- macOS 26.2, Apple silicon, Swift 6.3 Command Line Tools.
- All 23 automated tests passed using `bash scripts/test.sh`.
- Release bundle compiled for arm64 and x86_64; universal binary and ad-hoc signature verified.
- Light/dark settings and picker previews rendered with synthetic profiles and visually inspected.
- Read-only discovery found three Chrome profiles, one Brave profile, and Safari. Edge was not installed.
- Accessibility permission was not granted during verification. Real-app hover detection, actual profile routing, full-screen/Space behavior, and login registration remain unverified.
- Intel execution and the macOS 14 minimum deployment environment were not available for runtime testing; cross-compilation is not a substitute for those checks.

## Source applications

| Source | Intended coverage | Current validation |
| --- | --- | --- |
| Apple Mail | Rendered HTTP/HTTPS links exposed as AXLink | Pending manual validation |
| Slack desktop | Message links exposed as AXLink | User reports failure in v0.2.3; v0.3 retest pending |
| Microsoft Teams desktop | Message links exposed as AXLink | User reports failure in v0.2.3; v0.3 retest pending |
| Chrome webpages | Anchors exposed as AXLink, including nested text | Pending manual validation |
| Edge webpages | Anchors exposed as AXLink | Pending manual validation |
| Brave webpages | Anchors exposed as AXLink | Pending manual validation |
| Safari webpages | Anchors exposed as AXLink | Pending manual validation |
| Other apps | Best-effort explicit AXLink destinations | Unverified; no general guarantee |

Canvas-rendered content, custom controls, links only exposed in attributed text, inaccessible webviews, and some Electron configurations may expose no usable AXLink. PickBrowser deliberately stays silent. Version 0.1.2 queries the application's accessibility role but never writes accessibility-mode attributes. Apps that need forced screen-reader mode to expose links remain unsupported.

## Troubleshooting a missing picker

Use the running app's Settings permission status as the source of truth. A terminal-launched `--diagnose` process may be evaluated under the terminal/agent's privacy context and is not proof that the GUI app lacks permission.

Turn on Settings → Enable troubleshooting, try a message link, then return to Settings. Expand **Recent checks** to see up to eight checks (hit-test error, role chain, missing URL/bounds, or picker displayed), in chronological order. A final `AXMenuBar → AXApplication` means the pointer was checked over the menu bar; inspect the preceding message check instead. It contains no link text or URL and is never persisted. Disable troubleshooting or relaunch to clear it. Ensure only one PickBrowser copy is running; v0.1.1 enforces this at startup. Rebuilt ad-hoc bundles may need their Accessibility entry refreshed by the user.

The initial v0.1.0 build was reported not working in Slack, Teams, and browser pages despite GUI permission being enabled. Version 0.1.1 addressed missing accessibility activation and renderer-PID rejection. Its runtime trace recorded an AXLink detected and picker presented in Slack, but also triggered screen-reader prompts in editors. Version 0.1.2 removes forced accessibility-mode activation; Slack and other source apps need retesting in a fresh session. Teams remains best-effort, not a certified source.

If an editor shows “Screen reader usage detected,” dismiss the prompt; enabling `editor.accessibilitySupport` is not required for PickBrowser. Version 0.1.1 may leave the editor's mode active for the lifetime of that editor process. After updating PickBrowser, restart the affected editor when convenient (save work first). PickBrowser does not reset editor preferences or disable existing assistive tools. Some editors may also react to ordinary accessibility queries, so removal of the explicit mode request is not a guarantee against every such prompt.

## Destination routing

For Chrome, Edge, and Brave, create two clearly named test profiles with distinct visible themes. Test each selected profile with the browser completely closed, running in the other profile, running in both profiles, and running with only the selected profile. Use a harmless known URL. Confirm exactly one tab opens in the selected profile, with the source application receiving no duplicate click. Never close someone else's browser session just to perform the cold-launch test.

Test Safari with its normal settings and confirm it receives the URL; its external-link profile routing remains Safari's responsibility. A successful process start alone is not routing verification.

## Interaction checklist

- Open the public DMG and confirm Finder shows PickBrowser on the left and Applications on the right. Drag to Applications, eject, and launch the copied app from Spotlight.
- Before copying, double-click the app inside the DMG: it shows “Drag PickBrowser to Applications before opening” and does not request Accessibility permission. Verify the same behavior from Downloads and an App Translocation launch.
- Hover near the beginning, middle, and end of a long link: the picker stays beside the pointer, not the start of the link. Repeat near all display edges and with negative-origin displays.
- Named content links still qualify. Semantically marked navigation, menus, toolbars, and button-like links are excluded by default; opt in and confirm only genuine hyperlinks qualify. Plain buttons with URL metadata must remain excluded.
- Copy a link: one explicit clipboard write, visible checkmark, no browser launch. Move away: normal dismissal. Confirm no clipboard reads during detection.
- The tab shortcut is absent in Mail/Slack/Teams and browser non-web controls, present on supported browser webpages. It dispatches once to the same browser; test browser-specific tab/profile policy separately.
- Change background opacity/color, relaunch, and verify persistence and opaque readable text in light/dark mode. Enable macOS Reduce Transparency and verify a solid background. Reset restores defaults.
- Hover for less than 500 ms: no picker. Keep still for at least 500 ms: one picker on a supported link.
- Set a custom delay (0.1, 1.7, and 5 seconds), relaunch, and verify persistence and actual dwell. Change the delay while detection is pending: no stale picker.
- Move during a slow AX lookup or switch applications: no stale picker appears.
- Move through the gap into the picker: no flicker; all visible destinations are clickable.
- Move outside for less than 250 ms and return: picker remains. Leave longer: picker closes.
- Move to empty space to the right of a short link above the wider panel: picker closes. Linger in the gap: picker closes. Re-enter either real surface during the grace period: dismissal cancels.
- Press Escape or scroll the source: picker closes; staying over the same link does not reopen it.
- Click the original link normally: original behavior still works, without PickBrowser opening another tab.
- Scroll a long destination list: it scrolls without dismissing the picker.
- Select once or double-click: one dispatch. Fail the launch: Retry targets the same destination, Cancel stops.
- Rename/remove a profile and refresh: names/destinations update; old hidden/order choices stay stable.
- Remove a profile after discovery: selecting the stale row reports an error without creating a replacement.
- Hide every destination: no empty hover picker; settings explains how to restore it.
- Deny/revoke Accessibility access: detector stops; settings/menu show access is needed. Re-enable: it resumes.
- After a previously granted ad-hoc build loses approval, confirm Settings shows the orange renewal warning, explains why, and lists remove/add/reopen recovery steps. Fresh installs must show only the normal enable-access flow.
- Pause/resume, sleep/wake, lock/unlock: no lingering picker or stale results.
- Check a display left of, above, and below the primary display; test links at every screen edge.
- Check a full-screen browser and Space switching. Picker must not activate PickBrowser merely by appearing.
- Check dark/light appearance, long profile names, VoiceOver labels, and keyboard dismissal.
- Enable/disable launch at login from an installed bundle, including macOS's approval-required state.
- Start fresh with update checks off; confirm no updater network requests. Enable/disable automatic checks, run Check now, skip a version, cancel a download, test offline and invalid signatures, and update an older installed build. Verify installation/relaunch and preservation of settings. Never bypass signature or Gatekeeper failures.

## Automated coverage

`bash scripts/test.sh` runs Swift Testing coverage for hover dwell and cancellation, stale/duplicate results, permission state, app switching, picker traversal and dismissal, click suppression, screen placement, profile metadata parsing, stable ordering, safe launch arguments, and stale/deleted profile rejection. It does not request permissions, open browsers, or certify source app support.
