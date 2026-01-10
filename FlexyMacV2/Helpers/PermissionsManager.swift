import Cocoa
import ApplicationServices
import CoreGraphics

/// V1-compatible permissions manager
/// Matches macos.py ensure_permissions()
enum PermissionsManager {

    /// Check if accessibility permissions are granted
    /// V1: AXIsProcessTrusted()
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Check if screen recording permissions are granted
    /// Required for kCGWindowName access since macOS 10.15+
    static var hasScreenRecordingPermission: Bool {
        checkScreenRecordingPermission()
    }

    /// Checks screen recording permission by testing if we can read window names
    /// Uses a more reliable method: checks if we can read names from regular app windows
    private static func checkScreenRecordingPermission() -> Bool {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        var foundOtherAppWindow = false
        var couldReadWindowName = false

        for window in windowList {
            guard let windowPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  windowPID != currentPID,
                  let windowLayer = window[kCGWindowLayer as String] as? Int,
                  windowLayer == 0 else { // Layer 0 = normal windows
                continue
            }

            // Found a normal window from another app
            foundOtherAppWindow = true

            // Check if we can read its name
            if let name = window[kCGWindowName as String] as? String, !name.isEmpty {
                couldReadWindowName = true
                break
            }
        }

        // If we found other app windows but couldn't read any names, permission is missing
        if foundOtherAppWindow && !couldReadWindowName {
            return false
        }

        // If no other windows found, we can't determine - assume no permission to be safe
        if !foundOtherAppWindow {
            return false
        }

        return true
    }

    /// Request accessibility permissions with alert
    /// V1: background_ensure_permissions()
    static func ensureAccessibilityPermission() {
        guard !hasAccessibilityPermission else { return }

        // Run on background thread like V1
        DispatchQueue.global(qos: .userInitiated).async {
            showAccessibilityAlert()
        }
    }

    /// Show alert asking user to grant accessibility permissions
    /// V1: NSAlert with "Open accessibility settings" button
    private static func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Missing accessibility permissions"
            alert.informativeText = """
                To let FlexyTime capture window titles grant it accessibility permissions.

                If you've already given FlexyTime accessibility permissions and are \
                still seeing this dialog, try removing and re-adding them.
                """
            alert.alertStyle = .warning

            alert.addButton(withTitle: "Open accessibility settings")
            alert.addButton(withTitle: "Close")

            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                openAccessibilitySettings()
            }
        }
    }

    /// Open System Preferences/Settings to Accessibility pane
    /// V1: NSWorkspace.sharedWorkspace().openURL_(NSURL.URLWithString_(
    ///     "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"))
    static func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )!
        NSWorkspace.shared.open(url)
    }

    /// Prompt for accessibility with options to trigger the system dialog
    /// This can trigger the "FlexyMacV2 wants to control this computer" dialog
    static func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Request screen recording permissions with alert
    static func ensureScreenRecordingPermission() {
        guard !hasScreenRecordingPermission else { return }

        DispatchQueue.main.async {
            showScreenRecordingAlert()
        }
    }

    /// Show alert asking user to grant screen recording permissions
    private static func showScreenRecordingAlert() {
        let alert = NSAlert()
        alert.messageText = "Missing screen recording permissions"
        alert.informativeText = """
            To let FlexyTime capture window titles, grant it screen recording permissions.

            This is required on macOS 10.15+ to read window names from other applications.
            """
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Open screen recording settings")
        alert.addButton(withTitle: "Close")

        let response = alert.runModal()

        if response == .alertFirstButtonReturn {
            openScreenRecordingSettings()
        }
    }

    /// Open System Preferences/Settings to Screen Recording pane
    static func openScreenRecordingSettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        )!
        NSWorkspace.shared.open(url)
    }

    /// Ensure both permissions are granted
    static func ensureAllPermissions() {
        ensureAccessibilityPermission()
        // Small delay to avoid alert overlap
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ensureScreenRecordingPermission()
        }
    }
}
