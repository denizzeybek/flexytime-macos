import Foundation
import ServiceManagement

/// V1-compatible Login Items manager
/// Ensures app starts on login like V1's loginItems.py
enum LoginItemsManager {

    /// Add app to login items if not already added
    /// V1: add_login_item(appPath, 0)
    static func ensureLoginItemEnabled() {
        if #available(macOS 13.0, *) {
            // macOS 13+ uses SMAppService
            let service = SMAppService.mainApp
            if service.status != .enabled {
                do {
                    try service.register()
                } catch {
                    print("Failed to register login item: \(error)")
                }
            }
        } else {
            // Older macOS uses LSSharedFileList (deprecated but works)
            enableLoginItemLegacy()
        }
    }

    /// Check if app is in login items
    static var isLoginItemEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return isLoginItemEnabledLegacy()
        }
    }

    /// Remove app from login items
    static func disableLoginItem() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if service.status == .enabled {
                do {
                    try service.unregister()
                } catch {
                    print("Failed to unregister login item: \(error)")
                }
            }
        } else {
            disableLoginItemLegacy()
        }
    }

    // MARK: - Legacy Implementation (macOS 12 and earlier)

    private static func enableLoginItemLegacy() {
        guard let bundleURL = Bundle.main.bundleURL as CFURL? else { return }

        if let loginItems = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() {
            LSSharedFileListInsertItemURL(
                loginItems,
                kLSSharedFileListItemLast.takeRetainedValue(),
                nil,
                nil,
                bundleURL,
                nil,
                nil
            )
        }
    }

    private static func isLoginItemEnabledLegacy() -> Bool {
        guard let bundlePath = Bundle.main.bundlePath as CFString? else {
            return false
        }

        guard let loginItems = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() else {
            return false
        }

        guard let items = LSSharedFileListCopySnapshot(
            loginItems,
            nil
        )?.takeRetainedValue() as? [LSSharedFileListItem] else {
            return false
        }

        for item in items {
            if let url = LSSharedFileListItemCopyResolvedURL(
                item,
                0,
                nil
            )?.takeRetainedValue() as URL? {
                if url.path == bundlePath as String {
                    return true
                }
            }
        }

        return false
    }

    private static func disableLoginItemLegacy() {
        guard let bundlePath = Bundle.main.bundlePath as CFString? else { return }

        guard let loginItems = LSSharedFileListCreate(
            nil,
            kLSSharedFileListSessionLoginItems.takeRetainedValue(),
            nil
        )?.takeRetainedValue() else {
            return
        }

        guard let items = LSSharedFileListCopySnapshot(
            loginItems,
            nil
        )?.takeRetainedValue() as? [LSSharedFileListItem] else {
            return
        }

        for item in items {
            if let url = LSSharedFileListItemCopyResolvedURL(
                item,
                0,
                nil
            )?.takeRetainedValue() as URL? {
                if url.path == bundlePath as String {
                    LSSharedFileListItemRemove(loginItems, item)
                }
            }
        }
    }
}
