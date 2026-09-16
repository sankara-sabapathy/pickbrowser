# Privacy

PickBrowser detects and opens links locally. There are no accounts, analytics, crash-upload service, or link history. Hover detection does not make application network requests. Optional update checking is the only app-managed network feature.

With Accessibility permission, it inspects the element beneath the pointer after dwell and up to eleven parents to identify a hyperlink. Once a link is found, bounded control-context inspection may continue up to thirty-two total elements within a short time budget. It reads the source application's accessibility role but never writes its accessibility-mode attributes, enables VoiceOver, changes editor settings, or disables another assistive client's access. Candidate URLs are held temporarily in memory for presentation and launching. It does not read entire accessibility trees, take screenshots, perform OCR, read the clipboard, or query browser history/cookies.

Optional troubleshooting keeps up to eight recent status/role checks in memory, not link URLs or message text. Turning it off or quitting clears them. No diagnostic history is written to disk during normal use.

Clicking Copy explicitly replaces the system clipboard with the verified URL. PickBrowser does not read previous clipboard contents or maintain clipboard history. Copied URLs can remain on the clipboard after the picker closes and may be accessible to other software or system clipboard-sync features.

Troubleshooting is disabled by default and resets to off on app launch. When enabled in Settings, it keeps the latest detection outcome and accessibility role names in memory, without link text or URLs. Turning it off clears the status. The optional developer `--trace-hover` command prints those same status messages to stdout only when explicitly enabled.

Browser discovery reads local `Local State` metadata for profile directory names and display names and checks whether profile `Preferences` files exist. `Local State` can contain other browser metadata; PickBrowser parses only the profile information it needs and does not persist or transmit that file.

Pointer position and Escape/click/scroll events are observed only for interaction. Keyboard events are not stored. Source input is not swallowed. The only requested privacy permission is Accessibility; launch-at-login registration is a separate opt-in setting.

PickBrowser marks its picker, settings window, and alerts with AppKit's non-shareable window level. This is a best-effort hint for capture implementations that honor it, not a privacy boundary: [Apple documents the value as legacy](https://developer.apple.com/documentation/appkit/nswindow/sharingtype-swift.enum/none), and modern full-display capture or conferencing software may still include the final composited window. PickBrowser does not request Screen Recording permission to inspect capture sessions. Pause hover detection before sharing when link destinations or profile names must not be visible.

Stored application preferences are destination IDs/order, hidden destination IDs, optional nicknames you enter, hover delay, navigation inclusion, picker size, background color/opacity, and whether the welcome window has been shown. Sparkle stores update-check preferences, last-check state, and skipped versions, and may cache downloaded updates. Hovered URLs and browser-provided profile display names are not stored in these preferences. Destination IDs can include profile directory names such as `Profile 1`.

## Optional updates

Automatic checks are off initially. Clicking Check now or enabling automatic checking lets Sparkle request the signed release feed from GitHub and, with user approval, download/install the selected release. GitHub and its asset delivery providers receive ordinary request information such as IP address and the updater's User-Agent (which can include app/OS versions). PickBrowser sends no hovered URLs, browser/profile metadata, account identifiers, or telemetry. Sparkle system profiling and silent installations are disabled. Turning automatic checks off stops scheduled checks; a check or installation already in progress can still finish.

The download website also fetches public GitHub release metadata to show the current version and download. It uses no cookies, analytics, or browser storage. GitHub's own hosting/network privacy practices apply.

When you select a destination, the URL is passed to that browser. Browser history, network requests, and OS process inspection are outside PickBrowser's control. Browser stdout/stderr is discarded. Launch errors contain no intentional URL logging.

Quit PickBrowser to stop observation. Disable launch at login before removing the app, and revoke its Accessibility entry in System Settings if desired. No browser data is changed or deleted by uninstalling PickBrowser.
