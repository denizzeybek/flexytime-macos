import Foundation
import os.log

/// Logger extensions for categorized logging
extension Logger {

    // MARK: - Subsystem

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.flexytime.FlexyMacV2"

    // MARK: - Categories

    /// General app lifecycle logging
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Services (tracking, collection) logging
    static let services = Logger(subsystem: subsystem, category: "services")

    /// Network operations logging
    static let network = Logger(subsystem: subsystem, category: "network")

    /// UI related logging
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
