import Cocoa
import SwiftUI
import os.log

/// Application delegate handling app lifecycle and service management
/// V1-compatible startup sequence from main.py
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var activityCollector: ActivityCollector?
    private var setupWindow: NSWindow?
    private let logger = Logger.app

    /// Check if setup is needed (no ServiceKey configured)
    var needsSetup: Bool {
        let config = Configuration.shared
        return config.serviceKey == nil || config.serviceKey?.isEmpty == true
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Flexytime started")

        // Check if setup is needed
        if needsSetup {
            logger.info("Setup required - showing setup window")
            showSetupWindow()
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
            self?.startNormalOperation()
        })

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Flexytime Kurulumu"
        window.contentView = NSHostingView(rootView: setupView)
        window.center()
        window.makeKeyAndOrderFront(nil)

        // Bring app to foreground
        NSApp.activate(ignoringOtherApps: true)

        setupWindow = window
    }

    // MARK: - Normal Operation

    private func startNormalOperation() {
        logger.info("Starting normal operation")

        // V1: Add to login items if not already added
        if !LoginItemsManager.isLoginItemEnabled {
            logger.info("Adding application to login items")
            LoginItemsManager.ensureLoginItemEnabled()
        }

        // Check and request both permissions
        checkAndRequestPermissions()

        // V1: sleep(1) - wait for server to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.setupServices()
        }
    }

    private func checkAndRequestPermissions() {
        // Log current permission status
        let hasAccessibility = PermissionsManager.hasAccessibilityPermission
        let hasScreenRecording = PermissionsManager.hasScreenRecordingPermission

        logger.info("Permissions - Accessibility: \(hasAccessibility), Screen Recording: \(hasScreenRecording)")

        // Request accessibility permission (V1 compatible)
        if !hasAccessibility {
            logger.warning("Accessibility permission not granted")
            PermissionsManager.ensureAccessibilityPermission()
        }

        // Request screen recording permission (needed for window titles on macOS 10.15+)
        if !hasScreenRecording {
            logger.warning("Screen Recording permission not granted - window titles may not work")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                PermissionsManager.ensureScreenRecordingPermission()
            }
        }
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
