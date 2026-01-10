import Cocoa
import os.log

/// Tracks the currently active window and application
final class WindowTracker {

    // MARK: - Types

    struct WindowInfo: Equatable {
        let appName: String
        let windowTitle: String
        let bundleIdentifier: String?
        let timestamp: Date

        static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
            lhs.appName == rhs.appName && lhs.windowTitle == rhs.windowTitle
        }
    }

    // MARK: - Properties

    private let logger = Logger.services
    private var currentWindow: WindowInfo?

    // MARK: - Public Methods

    /// Gets the currently active window information
    /// - Returns: WindowInfo if available, nil otherwise
    func getCurrentWindow() -> WindowInfo? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            logger.warning("No frontmost application found")
            return nil
        }

        let appName = frontApp.localizedName ?? "Unknown"
        let bundleId = frontApp.bundleIdentifier
        let windowTitle = getActiveWindowTitle(for: frontApp)

        let info = WindowInfo(
            appName: appName,
            windowTitle: windowTitle,
            bundleIdentifier: bundleId,
            timestamp: Date()
        )

        if info != currentWindow {
            logger.debug("Window changed: \(appName) - \(windowTitle)")
            currentWindow = info
        }

        return info
    }

    // MARK: - Private Methods

    private func getActiveWindowTitle(for app: NSRunningApplication) -> String {
        // Try to get window title via Accessibility API
        guard let pid = Optional(app.processIdentifier) else {
            return "Unknown"
        }

        let appRef = AXUIElementCreateApplication(pid)
        var windowValue: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            appRef,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        )

        guard result == .success, let window = windowValue else {
            return "No Window"
        }

        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        if titleResult == .success, let title = titleValue as? String {
            return title
        }

        return "Untitled"
    }
}
