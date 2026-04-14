import Cocoa
import CoreGraphics

/// Tracks the currently active window and application
final class WindowTracker {

    // MARK: - Types

    struct WindowInfo: Equatable {
        let appName: String
        let windowTitle: String
        let bundleIdentifier: String?
        var url: String?
        let timestamp: Date

        static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
            lhs.appName == rhs.appName && lhs.windowTitle == rhs.windowTitle
        }
    }

    // MARK: - Properties

    private var currentWindow: WindowInfo?

    // MARK: - Public Methods

    /// Gets the currently active window information
    func getCurrentWindow() -> WindowInfo? {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            FlexLog.warning("No frontmost application found", category: .services)
            return nil
        }

        let appName = frontApp.localizedName ?? "Unknown"
        let bundleId = frontApp.bundleIdentifier
        let windowTitle = getActiveWindowTitle(for: frontApp)

        let info = WindowInfo(
            appName: appName,
            windowTitle: windowTitle,
            bundleIdentifier: bundleId,
            url: nil,
            timestamp: Date()
        )

        if info != currentWindow {
            FlexLog.debug("Window: \(appName) - \(windowTitle)", category: .services)
            currentWindow = info
        }

        return info
    }

    // MARK: - Private Methods

    private func getActiveWindowTitle(for app: NSRunningApplication) -> String {
        let pid = app.processIdentifier
        let appName = app.localizedName ?? "Unknown"

        // Method 1: Accessibility API (requires Accessibility permission)
        let (axTitle, axError) = getWindowTitleViaAccessibility(pid: pid)
        if let title = axTitle {
            return title
        }

        // Method 2: CGWindowList API (requires Screen Recording permission)
        let (cgTitle, cgError) = getWindowTitleViaCGWindowList(pid: pid)
        if let title = cgTitle {
            return title
        }

        FlexLog.warning("NO TITLE: \(appName) AX=\(axError) CG=\(cgError)", category: .permissions)

        return "No Window"
    }

    /// Get window title via Accessibility API
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
    private func getWindowTitleViaCGWindowList(pid: pid_t) -> (String?, String) {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return (nil, "list nil")
        }

        for window in windowList {
            guard let windowPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID == pid else {
                continue
            }

            let layer = window[kCGWindowLayer as String] as? Int ?? -1

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
