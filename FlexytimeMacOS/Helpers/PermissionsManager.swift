import Cocoa
import ApplicationServices
import CoreGraphics
import os.log

/// V1-compatible permissions manager
/// Matches macos.py ensure_permissions()
enum PermissionsManager {

    private static let logger = Logger(subsystem: "com.flexytime.macos", category: "Permissions")

    /// Check if accessibility permissions are granted
    /// V1: AXIsProcessTrusted()
    static var hasAccessibilityPermission: Bool {
        let result = AXIsProcessTrusted()
        logger.info("AXIsProcessTrusted returned: \(result)")
        return result
    }

    /// Check if screen recording permissions are granted
    /// Required for kCGWindowName access since macOS 10.15+
    static var hasScreenRecordingPermission: Bool {
        if #available(macOS 10.15, *) {
            let preflight = CGPreflightScreenCaptureAccess()
            logger.info("CGPreflightScreenCaptureAccess returned: \(preflight)")
            return preflight
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

    /// Request screen capture access - adds app to Screen Recording list
    /// This will show a system prompt, but it's necessary to add app to the list
    static func requestScreenCaptureAccess() {
        if #available(macOS 10.15, *) {
            CGRequestScreenCaptureAccess()
        }
    }

    /// Track if we've already requested screen recording
    private static var screenRecordingRequested: Bool {
        get { UserDefaults.standard.bool(forKey: "screenRecordingRequested") }
        set { UserDefaults.standard.set(newValue, forKey: "screenRecordingRequested") }
    }

    /// Check if we've already shown the popup this session
    private static var hasShownScreenRecordingPopup: Bool {
        get { UserDefaults.standard.bool(forKey: "hasShownScreenRecordingPopup") }
        set { UserDefaults.standard.set(newValue, forKey: "hasShownScreenRecordingPopup") }
    }

    /// Reset the flag if permission is not granted (called on app start)
    static func resetScreenRecordingFlagIfNeeded() {
        if !hasScreenRecordingPermission {
            logger.info("Permission not granted, resetting popup flag")
            hasShownScreenRecordingPopup = false
        }
    }

    /// Request screen capture - always opens System Settings
    /// CGRequestScreenCaptureAccess is unreliable for unsigned apps
    static func requestOrOpenScreenRecording() {
        if #available(macOS 10.15, *) {
            logger.info("requestOrOpenScreenRecording - opening System Settings directly")
            // CGRequestScreenCaptureAccess doesn't work reliably for unsigned apps
            // Just open System Settings directly - user will add app manually
            openScreenRecordingSettings()
        }
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
