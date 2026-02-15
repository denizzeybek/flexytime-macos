import Foundation

/// Application configuration - V1 compatible
/// Config file: ~/Library/Application Support/flexytime/config/flexytime/flexytime.ini
final class Configuration {

    // MARK: - Singleton

    static let shared = Configuration()

    // MARK: - Constants (V1 Compatible)

    /// Fixed control key - MUST match V1
    let controlKey = "53201045-1b89-47d4-909e-f0d326f393c0"

    /// Internal encryption password - MUST match V1
    let internalPassword = "99C5CB2EAA4EF8C3AB722F6B320FF006022783D063DC60DE217300B6A631A91B"

    /// External encryption password - MUST match V1
    let externalPassword = "23D405A00C105E32447B3700535CE159C820825658A6989208E16A1F1797F5BB"

    // MARK: - Debug Mode

    /// Enable verbose debug logging
    /// Set via Xcode scheme: -debug argument or environment variable DEBUG=1
    var isDebugMode: Bool {
        // Check command line args
        if CommandLine.arguments.contains("-debug") {
            return true
        }
        // Check environment variable
        if ProcessInfo.processInfo.environment["DEBUG"] == "1" {
            return true
        }
        // Check if running in Xcode (DEBUG build)
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    // MARK: - Timing Constants (V1 Compatible)

    /// Idle threshold in seconds (V1: 60)
    let idleThreshold: TimeInterval = 60

    /// Window polling interval in seconds (V1: 1)
    let pollingInterval: TimeInterval = 1

    /// AFK check interval in seconds (V1: 15)
    let afkCheckInterval: TimeInterval = 15

    /// Sync interval in seconds (V1: 60)
    let syncInterval: TimeInterval = 60

    /// Calendar event interval in seconds (V1: 15 * 60 = 900)
    let calendarInterval: TimeInterval = 900

    // MARK: - Configurable Properties

    /// Server host (set by developer in Info.plist before build)
    var serviceHost: String {
        Bundle.main.object(forInfoDictionaryKey: "ServiceHost") as? String ?? ""
    }

    /// API key/token (loaded from config file)
    var serviceKey: String? {
        get { loadConfigValue(key: "ServiceKey") }
        set {
            if let value = newValue {
                saveConfigValue(key: "ServiceKey", value: value)
            }
        }
    }

    /// Service version (set by developer in Info.plist before build)
    var serviceVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "ServiceVersion") as? String ?? "1.0.0"
    }

    /// App version for API requests
    var appVersion: String {
        serviceVersion
    }

    // MARK: - Computed Properties

    /// Full API endpoint URL
    var apiEndpoint: String {
        "https://\(serviceHost)/api/service/savetrace"
    }

    /// HTTP fallback endpoint
    var apiEndpointHTTP: String {
        "http://\(serviceHost)/api/service/savetrace"
    }

    // MARK: - Initialization

    private init() {
        ensureConfigDirectoryExists()
    }

    // MARK: - Private Methods

    private func loadConfigValue(key: String) -> String? {
        let configPath = Paths.configFile
        guard FileManager.default.fileExists(atPath: configPath) else {
            return nil
        }

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return nil
        }

        // Simple INI parser
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\(key)") {
                let parts = trimmed.components(separatedBy: "=")
                if parts.count >= 2 {
                    return parts[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }

    private func saveConfigValue(key: String, value: String) {
        ensureConfigDirectoryExists()
        var config = loadAllConfig()
        config[key] = value
        saveAllConfig(config)
    }

    private func loadAllConfig() -> [String: String] {
        var result: [String: String] = [:]
        let configPath = Paths.configFile

        guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            return result
        }

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("["), !trimmed.hasPrefix("#") else {
                continue
            }
            let parts = trimmed.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }
        return result
    }

    private func saveAllConfig(_ config: [String: String]) {
        var content = "[flexytime]\n"
        for (key, value) in config {
            content += "\(key) = \(value)\n"
        }
        try? content.write(toFile: Paths.configFile, atomically: true, encoding: .utf8)
    }

    private func ensureConfigDirectoryExists() {
        try? FileManager.default.createDirectory(
            atPath: Paths.configDir,
            withIntermediateDirectories: true
        )
    }
}

// MARK: - Paths (V1 Compatible)

enum Paths {
    /// Base data directory
    static var dataDir: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Application Support/flexytime"
    }

    /// Cache directory for .trc files
    static var cacheDir: String {
        "\(dataDir)/cache"
    }

    /// User-specific cache directory
    static func userCacheDir(userPath: String) -> String {
        "\(cacheDir)/\(userPath)"
    }

    /// Config directory
    static var configDir: String {
        "\(dataDir)/config/flexytime"
    }

    /// Config file path
    static var configFile: String {
        "\(configDir)/flexytime.ini"
    }

    /// Log directory
    static var logDir: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Logs/flexytime"
    }
}
