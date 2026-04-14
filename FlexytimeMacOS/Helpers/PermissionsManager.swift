import Cocoa
import ApplicationServices
import CoreGraphics
import ScreenCaptureKit

/// V1-compatible permissions manager
/// Matches macos.py ensure_permissions()
enum PermissionsManager {

    // Logging via FlexLog with .permissions category

    /// Dedicated queue for permission system calls (AltTab pattern)
    private static let permissionsQueue = OperationQueue()

    /// Check if accessibility permissions are granted
    /// Uses AXIsProcessTrustedWithOptions without prompt (AltTab pattern)
    static var hasAccessibilityPermission: Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        let result = AXIsProcessTrustedWithOptions(options as CFDictionary)
        return result
    }

    /// Check if screen recording permissions are granted
    /// CGPreflightScreenCaptureAccess is unreliable (not updated during app lifetime)
    /// AltTab pattern: SCShareableContent on macOS 12.3+, CGDisplayStream on older
    static var hasScreenRecordingPermission: Bool {
        if #available(macOS 12.3, *) {
            return checkScreenRecordingWithSCShareableContent()
        } else if #available(macOS 10.15, *) {
            return checkScreenRecordingOnAllDisplays()
        }
        return true
    }

    @available(macOS 12.3, *)
    private static func checkScreenRecordingWithSCShareableContent() -> Bool {
        return runWithTimeout { completion in
            SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: false) { content, error in
                completion(error == nil && content != nil)
            }
        }
    }

    /// AltTab pattern: try all displays, not just main
    @available(macOS 10.15, *)
    private static func checkScreenRecordingOnAllDisplays() -> Bool {
        let mainID = CGMainDisplayID()
        if checkDisplayStream(mainID) { return true }
        for screen in NSScreen.screens {
            if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               id != mainID, checkDisplayStream(id) {
                return true
            }
        }
        return false
    }

    @available(macOS 10.15, *)
    private static func checkDisplayStream(_ displayID: CGDirectDisplayID) -> Bool {
        return runWithTimeout { completion in
            let stream = CGDisplayStream(
                dispatchQueueDisplay: displayID,
                outputWidth: 1,
                outputHeight: 1,
                pixelFormat: Int32(kCVPixelFormatType_32BGRA),
                properties: nil,
                queue: .global()
            ) { _, _, _, _ in }
            completion(stream != nil)
        }
    }

    /// AltTab pattern: run permission check on dedicated queue with 6s timeout
    private static func runWithTimeout(_ block: @escaping (@escaping (Bool) -> Void) -> Void) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var result = false
        permissionsQueue.addOperation {
            block { value in
                result = value
                semaphore.signal()
            }
        }
        let timeout = semaphore.wait(timeout: .now() + 6)
        if timeout == .timedOut {
            FlexLog.warning("Permission check timed out after 6s", category: .permissions)
            return false
        }
        return result
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
            FlexLog.info("Screen Recording not granted, resetting popup flag", category: .permissions)
            hasShownScreenRecordingPopup = false
        }
    }

    /// Request screen capture - triggers system to add app to Screen Recording list
    static func requestOrOpenScreenRecording() {
        if #available(macOS 10.15, *) {
            FlexLog.info("Requesting Screen Recording access", category: .permissions)
            // This registers the app in the Screen Recording list
            CGRequestScreenCaptureAccess()
            // Also open System Settings so user can toggle it on
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

    /// Reset TCC permissions if app version changed (new binary invalidates old permissions)
    /// Should be called once at startup, before permission checks
    static func resetPermissionsIfVersionChanged() {
        let currentVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "0"
        let lastVersion = UserDefaults.standard.string(forKey: "lastPermissionVersion")

        guard currentVersion != lastVersion else { return }

        FlexLog.info(
            "Version changed (\(lastVersion ?? "none") -> \(currentVersion)), resetting TCC",
            category: .permissions
        )

        let bundleId = Bundle.main.bundleIdentifier ?? "com.flexytime.FlexytimeMacOS"
        resetTCC(service: "Accessibility", bundleId: bundleId)
        resetTCC(service: "ScreenCapture", bundleId: bundleId)

        UserDefaults.standard.set(currentVersion, forKey: "lastPermissionVersion")
    }

    /// Run tccutil reset for a specific service and bundle ID
    private static func resetTCC(service: String, bundleId: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", service, bundleId]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            FlexLog.info("TCC reset \(service): exit=\(task.terminationStatus)", category: .permissions)
        } catch {
            FlexLog.warning("TCC reset \(service) failed: \(error.localizedDescription)", category: .permissions)
        }
    }
}
