/// Short-lived status strings only. Callers must not supply URLs or source text.
/// This is never persisted and is cleared when troubleshooting is disabled.
public struct DetectionDiagnostics {
    public private(set) var entries: [String] = []
    public init() {}
    public mutating func record(_ status: String) {
        guard entries.last != status else { return }
        entries.append(status)
        if entries.count > 8 { entries.removeFirst(entries.count - 8) }
    }
    public mutating func clear() { entries.removeAll() }
}
