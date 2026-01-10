import Cocoa
import CoreGraphics
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
        let pid = app.processIdentifier
        let appName = app.localizedName ?? "Unknown"

        // Method 1: Try Accessibility API first (requires Accessibility permission)
        let (axTitle, axError) = getWindowTitleViaAccessibility(pid: pid)
        if let title = axTitle {
            return title
        }

        // Method 2: Fallback to CGWindowList API (requires Screen Recording permission)
        let (cgTitle, cgError) = getWindowTitleViaCGWindowList(pid: pid)
        if let title = cgTitle {
            return title
        }

        // Print debug info to understand the issue
        print("⚠️ NO TITLE for \(appName): AX=\(axError), CG=\(cgError)")

        return "No Window"
    }

    /// Get window title via Accessibility API
    /// Returns (title, errorDescription)
    private func getWindowTitleViaAccessibility(pid: pid_t) -> (String?, String) {
        let appRef = AXUIElementCreateApplication(pid)
        var windowValue: CFTypeRef?

        let result = AXUIElementCopyAttributeValue(
            appRef,
            kAXFocusedWindowAttribute as CFString,
            &windowValue
        )

        if result != .success {
            return (nil, "FocusedWindow err=\(result.rawValue)")
        }

        guard let window = windowValue else {
            return (nil, "window nil")
        }

        var titleValue: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(
            window as! AXUIElement,
            kAXTitleAttribute as CFString,
            &titleValue
        )

        if titleResult != .success {
            return (nil, "Title err=\(titleResult.rawValue)")
        }

        if let title = titleValue as? String, !title.isEmpty {
            return (title, "ok")
        }

        return (nil, "title empty")
    }

    /// Get window title via CGWindowList API (fallback)
    /// Returns (title, errorDescription)
    private func getWindowTitleViaCGWindowList(pid: pid_t) -> (String?, String) {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return (nil, "list nil")
        }

        var foundWindow = false
        // Find windows belonging to this process
        for window in windowList {
            guard let windowPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid else {
                continue
            }

            foundWindow = true
            let layer = window[kCGWindowLayer as String] as? Int ?? -1

            // Get window name (requires Screen Recording permission)
            if let windowName = window[kCGWindowName as String] as? String, !windowName.isEmpty {
                return (windowName, "ok")
            } else {
                let hasKey = window[kCGWindowName as String] != nil
                return (nil, "layer=\(layer) hasKey=\(hasKey)")
            }
        }

        return (nil, "no windows")
    }
}
