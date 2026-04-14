import Cocoa

/// Extracts active browser tab URL via AppleScript
/// Supports: Safari, Google Chrome, Microsoft Edge
final class BrowserURLExtractor {

    // MARK: - Types

    /// Browsers with AppleScript URL support
    /// rawValue matches macOS localizedName (and backend ProcessName)
    enum SupportedBrowser: String, CaseIterable {
        case safari = "Safari"
        case chrome = "Google Chrome"
        case edge = "Microsoft Edge"

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
