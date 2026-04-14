import Cocoa
import SwiftUI

/// Application delegate handling app lifecycle and service management
/// V1-compatible startup sequence from main.py
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var activityCollector: ActivityCollector?
    private var setupWindow: NSWindow?
    private var permissionsWindow: NSWindow?

    /// Check if setup is needed (no ServiceKey configured)
    var needsSetup: Bool {
        let config = Configuration.shared
        return config.serviceKey == nil || config.serviceKey?.isEmpty == true
    }

    /// Check if permissions onboarding is needed
    /// Always checks actual permission status — binary updates invalidate old permissions
    var needsPermissions: Bool {
        return !PermissionsManager.hasAccessibilityPermission
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        FlexLog.info("Flexytime started", category: .app)

        // Reset TCC permissions if binary version changed (new build invalidates old permissions)
        PermissionsManager.resetPermissionsIfVersionChanged()

        if needsSetup {
            FlexLog.info("Setup required - showing setup window", category: .app)
            showSetupWindow()
            return
        }

        // Check permissions on background thread (screen recording check uses semaphore)
        DispatchQueue.global(qos: .userInitiated).async {
            let permsNeeded = self.needsPermissions
            DispatchQueue.main.async {
                if permsNeeded {
                    FlexLog.info("Permissions required - showing permissions window", category: .app)
                    self.showPermissionsWindow()
                } else {
                    self.startNormalOperation()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        FlexLog.info("Flexytime shutting down", category: .app)
        stopServices()
    }

    // MARK: - Setup

    func showSetupWindow() {
        let setupView = SetupView(onComplete: {
            self.setupWindow?.close()
            self.setupWindow = nil
            self.relaunchApp()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Flexytime Setup"
        window.contentView = NSHostingView(rootView: setupView)
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        setupWindow = window
    }

    func showPermissionsWindow() {
        let permissionsView = PermissionsView(onAllGranted: {
            UserDefaults.standard.set(true, forKey: "onboardingCompleted")
            self.permissionsWindow?.close()
            self.permissionsWindow = nil
            self.relaunchApp()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Flexytime needs permissions"
        window.contentView = NSHostingView(rootView: permissionsView)
        window.center()
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)
        permissionsWindow = window
    }

    // MARK: - Normal Operation

    private func startNormalOperation() {
        let hasAX = PermissionsManager.hasAccessibilityPermission
        let hasSR = PermissionsManager.hasScreenRecordingPermission
        FlexLog.info("Permissions: Accessibility=\(hasAX) ScreenRecording=\(hasSR)", category: .permissions)

        if !LoginItemsManager.isLoginItemEnabled {
            FlexLog.info("Adding to login items", category: .app)
            LoginItemsManager.ensureLoginItemEnabled()
        }

        setupServices()
    }

    private func setupServices() {
        let config = Configuration.shared
        activityCollector = ActivityCollector(configuration: config)
        activityCollector?.start()
    }

    private func stopServices() {
        activityCollector?.stop()
    }

    /// Relaunch the app (used after setup/permissions to get a clean start)
    private func relaunchApp() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", url.path]
        try? task.run()
        NSApp.terminate(nil)
    }
}
