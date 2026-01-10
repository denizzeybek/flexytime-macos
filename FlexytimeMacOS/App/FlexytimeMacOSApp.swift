import SwiftUI

/// Main application entry point for Flexytime
/// This is a menu bar only app (no dock icon, no main window)
@main
struct FlexytimeMacOSApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Flexytime", image: "MenuBarIcon") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
    }
}
