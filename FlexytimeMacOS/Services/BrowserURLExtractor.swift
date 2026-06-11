import Cocoa

/// Extracts active browser tab URL via AppleScript
///
/// The legacy .NET backend used to hard-code a switch over Windows process
/// names (`chrome`/`msedge`/`iexplore`/`opera`) — Arc, Safari, Firefox, Brave,
/// Vivaldi all silently fell through and lost URL info. v2's backend now
/// trusts whatever URL the agent sets in Properties.URL regardless of process
/// name, so this extractor is the actual gate: extend the enum here to let a
/// new browser's URLs flow through to classification.
///
/// All Chromium-based browsers (Arc, Brave, Vivaldi, Chrome, Edge) expose the
/// same `URL of active tab of front window` AppleScript surface. Safari uses
/// `URL of front document`. Firefox historically refused AppleScript URL
/// access and is intentionally excluded.
final class BrowserURLExtractor {

    // MARK: - Types

    /// Browsers with AppleScript URL support.
    /// `rawValue` matches `NSRunningApplication.localizedName` (which is what
    /// `WindowTracker` reports as `appName`, and what the backend sees as
    /// `view.ProcessName`).
    enum SupportedBrowser: String, CaseIterable {
        case safari = "Safari"
        case chrome = "Google Chrome"
        case edge = "Microsoft Edge"
        case arc = "Arc"
        case brave = "Brave Browser"
        case vivaldi = "Vivaldi"

        /// AppleScript to get the active tab URL
        var urlScript: String {
            switch self {
            case .safari:
                return "tell application \"Safari\" to return URL of front document"
            case .chrome:
                return """
                tell application "Google Chrome" \
                to return URL of active tab of front window
                """
            case .edge:
                return """
                tell application "Microsoft Edge" \
                to return URL of active tab of front window
                """
            case .arc:
                return """
                tell application "Arc" \
                to return URL of active tab of front window
                """
            case .brave:
                return """
                tell application "Brave Browser" \
                to return URL of active tab of front window
                """
            case .vivaldi:
                return """
                tell application "Vivaldi" \
                to return URL of active tab of front window
                """
            }
        }
    }

    // MARK: - Properties

    /// Cache: appName -> SupportedBrowser? (avoids repeated iteration)
    private var browserCache: [String: SupportedBrowser?] = [:]

    // MARK: - Public Methods

    /// Whether the given app is a supported browser
    func isBrowser(appName: String) -> Bool {
        resolvedBrowser(for: appName) != nil
    }

    /// Extract the active tab URL for a known browser.
    /// Returns nil for non-browsers or on any failure.
    func extractURL(appName: String) -> String? {
        guard let browser = resolvedBrowser(for: appName) else {
            return nil
        }
        return runAppleScript(browser.urlScript)
    }

    // MARK: - Private Methods

    private func resolvedBrowser(for appName: String) -> SupportedBrowser? {
        if let cached = browserCache[appName] {
            return cached
        }
        let match = SupportedBrowser.allCases.first { $0.rawValue == appName }
        browserCache[appName] = match
        return match
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else {
            return nil
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if error != nil {
            FlexLog.debug("AppleScript URL extraction failed", category: .services)
            return nil
        }

        guard let urlString = result.stringValue,
              !urlString.isEmpty else {
            return nil
        }

        return urlString
    }
}
