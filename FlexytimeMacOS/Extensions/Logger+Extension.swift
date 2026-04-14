import Foundation
import os.log

/// Unified logging — outputs to both Xcode console (print) and macOS log stream (os_log)
/// Usage: FlexLog.info("message", category: .network)
enum FlexLog {

    enum Category: String {
        case app
        case services
        case network
        case permissions
    }

    enum Level: String {
        case debug
        case info
        case warning
        case error
    }

    // MARK: - Convenience Methods

    static func debug(_ message: String, category: Category = .app) {
        log(message, level: .debug, category: category)
    }

    static func info(_ message: String, category: Category = .app) {
        log(message, level: .info, category: category)
    }

    static func warning(_ message: String, category: Category = .app) {
        log(message, level: .warning, category: category)
    }

    static func error(_ message: String, category: Category = .app) {
        log(message, level: .error, category: category)
    }

    // MARK: - Core

    private static func log(_ message: String, level: Level, category: Category) {
        let prefix: String
        switch level {
        case .debug: prefix = "DEBUG"
        case .info: prefix = "INFO"
        case .warning: prefix = "WARN"
        case .error: prefix = "ERROR"
        }

        // Xcode console
        print("[\(prefix)] [\(category.rawValue)] \(message)")

        // macOS log stream (log stream --process Flexytime)
        let osLog = OSLog(subsystem: "com.flexytime.macos", category: category.rawValue)
        let osLevel: OSLogType
        switch level {
        case .debug: osLevel = .debug
        case .info: osLevel = .info
        case .warning: osLevel = .default
        case .error: osLevel = .error
        }
        os_log(osLevel, log: osLog, "%{public}s", message)
    }
}
