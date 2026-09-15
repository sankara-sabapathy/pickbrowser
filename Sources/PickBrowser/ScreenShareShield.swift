import AppKit

/// Best-effort hint for capture implementations that still honor AppKit's
/// window sharing level. Modern full-display capture can ignore this value;
/// pausing hover detection is the reliable way to prevent picker presentation.
enum ScreenShareShield {
    static func apply(to window: NSWindow) {
        window.sharingType = .none
    }

    static func apply(to alert: NSAlert) {
        apply(to: alert.window)
    }
}
