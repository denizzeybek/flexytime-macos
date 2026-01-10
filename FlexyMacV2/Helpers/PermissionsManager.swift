import Cocoa
import ApplicationServices

/// V1-compatible permissions manager
/// Matches macos.py ensure_permissions()
enum PermissionsManager {

    /// Check if accessibility permissions are granted
    /// V1: AXIsProcessTrusted()
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
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
}
