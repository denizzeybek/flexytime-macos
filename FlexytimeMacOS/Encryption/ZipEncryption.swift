import Foundation
import CryptoKit

/// V1 Compatible ZIP encryption
/// Creates password-protected ZIP files matching pyminizip output
final class ZipEncryption {

    // MARK: - Errors

    enum ZipError: LocalizedError {
        case compressionFailed
        case fileNotFound
        case writeError
        case invalidPassword

        var errorDescription: String? {
            switch self {
            case .compressionFailed: return "ZIP compression failed"
            case .fileNotFound: return "Input file not found"
            case .writeError: return "Failed to write ZIP file"
            case .invalidPassword: return "Invalid password"
            }
        }
    }

    // MARK: - Public Methods

    /// Creates a password-protected ZIP file (V1 compatible)
    /// Uses native C minizip-bridge for cross-machine compatibility
    static func createPasswordZip(
        inputPath: String,
        outputPath: String,
        filenameInZip: String,
        password: String,
        compressionLevel: Int32 = 5
    ) throws {
        let result = create_password_zip(
            outputPath,
            inputPath,
            filenameInZip,
            password,
            Int32(compressionLevel)
        )

        guard result == ZIP_OK else {
            FlexLog.error("ZIP compression failed (code \(result))", category: .network)
            throw ZipError.compressionFailed
        }
    }

    /// V1 compatible two-layer encryption process
    static func encryptUsage(
        _ usage: UsagePayload,
        config: Configuration,
        userPath: String
    ) throws -> URL {
        let cacheDir = Paths.userCacheDir(userPath: userPath)
        try FileManager.default.createDirectory(
            atPath: cacheDir,
            withIntermediateDirectories: true
        )

        // Step 1: Save JSON
        let jsonPath = "\(cacheDir)/usage.json"
        let jsonData = try encodeUsage(usage)
        try jsonData.write(to: URL(fileURLWithPath: jsonPath))

        let viewCount = usage.views?.count ?? 0
        let dataType = usage.dataType == .input ? "input" : "calendar"
        FlexLog.info("ZIP: \(jsonData.count)B JSON, \(viewCount) views, type=\(dataType)", category: .network)

        // Log raw JSON payload for debugging
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            FlexLog.info("JSON PAYLOAD:\n\(jsonString)", category: .network)
        }

        // Step 2: Inner ZIP (password protected, entry = "usage.json")
        let jsonHash = sha256Hash(of: jsonData)
        let internalZipPath = "\(cacheDir)/temp_inner.zip"

        try createPasswordZip(
            inputPath: jsonPath,
            outputPath: internalZipPath,
            filenameInZip: "usage.json",
            password: config.internalPassword,
            compressionLevel: 5
        )

        let innerSize = (try? Data(contentsOf: URL(fileURLWithPath: internalZipPath)))?.count ?? 0
        FlexLog.info("ZIP: inner=\(innerSize)B, hash=\(jsonHash.prefix(16))...", category: .network)

        try? FileManager.default.removeItem(atPath: jsonPath)

        // Step 3: Outer ZIP (password protected, entry = SHA256 hash)
        let ticks = ticksSinceEpoch()
        let trcFilename = "\(ticks).trc"
        let trcPath = "\(cacheDir)/\(trcFilename)"

        try createPasswordZip(
            inputPath: internalZipPath,
            outputPath: trcPath,
            filenameInZip: jsonHash,
            password: config.externalPassword,
            compressionLevel: 5
        )

        try? FileManager.default.removeItem(atPath: internalZipPath)

        let trcSize = (try? Data(contentsOf: URL(fileURLWithPath: trcPath)))?.count ?? 0
        FlexLog.info("ZIP: \(trcFilename) \(trcSize)B ready", category: .network)

        return URL(fileURLWithPath: trcPath)
    }

    // MARK: - Private Helpers

    /// Encode usage to JSON with ISO8601 date format
    private static func encodeUsage(_ usage: UsagePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(usage)
    }

    /// SHA256 hash of data as uppercase hex string
    private static func sha256Hash(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02X", $0) }.joined()
    }

    /// Ticks since epoch (V1 compatible: seconds since year 1)
    private static func ticksSinceEpoch() -> Int {
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 1, month: 1, day: 1)
        let epoch = calendar.date(from: components)!
        return Int(now.timeIntervalSince(epoch))
    }
}

// MARK: - File Operations Extension

extension ZipEncryption {

    /// Get all pending .trc files in cache directory
    static func getPendingTraceFiles(userPath: String) -> [URL] {
        let cacheDir = Paths.userCacheDir(userPath: userPath)
        let fileManager = FileManager.default

        guard let files = try? fileManager.contentsOfDirectory(atPath: cacheDir) else {
            return []
        }

        return files
            .filter { $0.hasSuffix(".trc") }
            .map { URL(fileURLWithPath: "\(cacheDir)/\($0)") }
    }

    /// Delete a trace file after successful upload
    static func deleteTraceFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Extract record date from .trc filename (ticks)
    static func recordDate(from trcURL: URL) -> Date {
        let filename = trcURL.deletingPathExtension().lastPathComponent
        guard let ticks = Int(filename) else {
            return Date()
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 1, month: 1, day: 1)
        let epoch = calendar.date(from: components)!
        return epoch.addingTimeInterval(TimeInterval(ticks))
    }
}
