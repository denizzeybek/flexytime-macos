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
    /// Uses pyminizip via Python for 100% V1 compatibility
    /// - Parameters:
    ///   - inputPath: Path to file to compress
    ///   - outputPath: Path for output ZIP file
    ///   - filenameInZip: Name of file inside ZIP archive (not used - pyminizip uses original filename)
    ///   - password: Encryption password
    ///   - compressionLevel: 0-9 (default 5 for V1 compatibility)
    static func createPasswordZip(
        inputPath: String,
        outputPath: String,
        filenameInZip: String,
        password: String,
        compressionLevel: Int32 = 5
    ) throws {
        // Use pyminizip via Python for V1 compatibility
        let pythonScript = """
        import pyminizip
        pyminizip.compress('\(inputPath)', None, '\(outputPath)', '\(password)', \(compressionLevel))
        """

        let process = Process()
        // Use python3 from PATH (pyminizip may not be in /usr/bin/python3)
        process.executableURL = URL(fileURLWithPath: "/Library/Frameworks/Python.framework/Versions/3.9/bin/python3")
        process.arguments = ["-c", pythonScript]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("ZIP error: \(errorMessage)")
                throw ZipError.compressionFailed
            }
        } catch {
            throw ZipError.compressionFailed
        }
    }

    /// V1 compatible two-layer encryption process
    /// 1. Save JSON to file
    /// 2. Compress with internal password → SHA256 hash filename
    /// 3. Compress again with external password → ticks.trc filename
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

        // Step 2: Compress with internal password
        let jsonHash = sha256Hash(of: jsonData)
        let internalZipPath = "\(cacheDir)/\(jsonHash)"

        try createPasswordZip(
            inputPath: jsonPath,
            outputPath: internalZipPath,
            filenameInZip: "usage.json",
            password: config.internalPassword,
            compressionLevel: 5
        )

        // Delete temp JSON
        try? FileManager.default.removeItem(atPath: jsonPath)

        // Step 3: Compress with external password
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

        // Delete intermediate ZIP
        try? FileManager.default.removeItem(atPath: internalZipPath)

        return URL(fileURLWithPath: trcPath)
    }

    // MARK: - Private Helpers

    /// Encode usage to JSON with V1 compatible date format
    private static func encodeUsage(_ usage: UsagePayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            try container.encode(formatter.string(from: date))
        }
        return try encoder.encode(usage)
    }

    /// SHA256 hash of data as uppercase hex string
    private static func sha256Hash(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02X", $0) }.joined()
    }

    /// Ticks since epoch (V1 compatible: seconds since year 1)
    private static func ticksSinceEpoch() -> Int {
        // V1 calculates seconds from datetime(1,1,1) to now
        // This is a very large number, we'll use Unix timestamp instead
        // which is close enough for unique filenames
        let now = Date()
        // V1 epoch: Jan 1, year 1 (but we use unix timestamp for simplicity)
        // The actual V1 calculation:
        // t0 = datetime(1, 1, 1)
        // diff = (now - t0).total_seconds()
        // For compatibility, let's calculate properly
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: 1, month: 1, day: 1)
        let epoch = calendar.date(from: components)!
        let seconds = Int(now.timeIntervalSince(epoch))
        return seconds
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
