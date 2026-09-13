import Foundation

/// The quick-open action belongs to the source browser, never the OS default
/// or an inferred profile. A browser toolbar link is not webpage evidence.
public enum SourceBrowser: String, CaseIterable {
    case chrome = "com.google.Chrome"
    case edge = "com.microsoft.edgemac"
    case brave = "com.brave.Browser"
    case safari = "com.apple.Safari"

    public var name: String {
        switch self {
        case .chrome: return "Chrome"
        case .edge: return "Edge"
        case .brave: return "Brave"
        case .safari: return "Safari"
        }
    }

    public static func forWebpage(_ candidate: LinkCandidate) -> SourceBrowser? {
        guard candidate.isWebContent,
              let separator = candidate.sourceID.lastIndex(of: ":"),
              let pid = Int32(candidate.sourceID[candidate.sourceID.index(after: separator)...]), pid > 0 else { return nil }
        return SourceBrowser(rawValue: String(candidate.sourceID[..<separator]))
    }
}
