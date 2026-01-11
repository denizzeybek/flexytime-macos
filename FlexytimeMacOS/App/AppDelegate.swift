import Cocoa
import SwiftUI
import os.log

/// Application delegate handling app lifecycle and service management
/// V1-compatible startup sequence from main.py
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var activityCollector: ActivityCollector?
    private var setupWindow: NSWindow?
    private var permissionsWindow: NSWindow?
    private let logger = Logger.app

    /// Check if setup is needed (no ServiceKey configured)
    var needsSetup: Bool {
        let config = Configuration.shared
        return config.serviceKey == nil || config.serviceKey?.isEmpty == true
    }

    /// Check if permissions are missing
    var needsPermissions: Bool {
        !PermissionsManager.hasAccessibilityPermission || !PermissionsManager.hasScreenRecordingPermission
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Flexytime started")

        // Check if setup is needed (ServiceKey)
        if needsSetup {
            logger.info("Setup required - showing setup window")
            showSetupWindow()
            return
        }

        // Check if permissions are needed
        if needsPermissions {
            logger.info("Permissions required - showing permissions window")
            showPermissionsWindow()
            return
        }

        // Normal startup
        startNormalOperation()
    }

    func applicationWillTerminate(_ notification: Notification) {
        logger.info("Flexytime shutting down")
        stopServices()
    }

    // MARK: - Setup

    func showSetupWindow() {
        let setupView = SetupView(onComplete: { [weak self] in
            self?.setupWindow?.close()
            self?.setupWindow = nil
            // After setup, check permissions
            if self?.needsPermissions == true {
                self?.showPermissionsWindow()
            } else {
                self?.startNormalOperation()
            }
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

        // Bring app to foreground
        NSApp.activate(ignoringOtherApps: true)

        setupWindow = window
    }

    func showPermissionsWindow() {
        let permissionsView = PermissionsView(onAllGranted: { [weak self] in
            self?.permissionsWindow?.close()
            self?.permissionsWindow = nil
            self?.startNormalOperation()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Flexytime needs permissions"
        window.contentView = NSHostingView(rootView: permissionsView)
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Bring app to foreground
        NSApp.activate(ignoringOtherApps: true)

        permissionsWindow = window
    }

    // MARK: - Normal Operation

    private func startNormalOperation() {
        logger.info("Starting normal operation")

        // Log permission status
        let hasAccessibility = PermissionsManager.hasAccessibilityPermission
        let hasScreenRecording = PermissionsManager.hasScreenRecordingPermission
        logger.info("Permissions - Accessibility: \(hasAccessibility), Screen Recording: \(hasScreenRecording)")

        // V1: Add to login items if not already added
        if !LoginItemsManager.isLoginItemEnabled {
            logger.info("Adding application to login items")
            LoginItemsManager.ensureLoginItemEnabled()
        }

        // Start services
        setupServices()
    }

    private func setupServices() {
        let config = Configuration.shared
        activityCollector = ActivityCollector(configuration: config)
        activityCollector?.start()
        logger.info("Services initialized")
    }

    private func stopServices() {
        activityCollector?.stop()
        logger.info("Services stopped")
    }
}
