import Foundation
import os.log

/// V1-compatible API client
/// Creates .trc files, caches offline, sends to /api/service/savetrace
final class APIClient {

    // MARK: - Properties

    private let configuration: Configuration
    private let logger = Logger.network
    private let session: URLSession

    // MARK: - Initialization

    init(configuration: Configuration) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Public Methods

    /// V1: save_usage() + save_traces() flow
    /// 1. Create .trc file (2-layer encrypted ZIP)
    /// 2. Try to send all pending .trc files
    func sendUsage(_ usage: UsagePayload) async {
        // Debug: Log the payload before encryption
        if configuration.isDebugMode {
            logger.info("📦 Creating .trc file...")
            logger.info("  DeviceType: \(usage.deviceType.rawValue)")
            logger.info("  Username: \(usage.username)")
            logger.info("  MachineName: \(usage.machineName)")
            logger.info("  IP: \(usage.ipAddress)")
            logger.info("  DataType: \(usage.dataType.rawValue)")
            logger.info("  Views: \(usage.views?.count ?? 0)")
        }

        do {
            // Step 1: Create .trc file
            let trcURL = try ZipEncryption.encryptUsage(
                usage,
                config: configuration,
                userPath: SystemInfo.userPath
            )
            logger.info("✅ Created .trc file: \(trcURL.lastPathComponent)")

            // Debug: Show file location
            if configuration.isDebugMode {
                logger.info("  Path: \(trcURL.path)")
            }

            // Step 2: Send all pending .trc files
            await sendPendingTraces()
        } catch {
            logger.error("❌ Failed to create .trc: \(error.localizedDescription)")
        }
    }

    /// V1: save_traces() - send all pending .trc files
    func sendPendingTraces() async {
        let traceFiles = ZipEncryption.getPendingTraceFiles(
            userPath: SystemInfo.userPath
        )

        if configuration.isDebugMode && !traceFiles.isEmpty {
            logger.info("📤 Found \(traceFiles.count) pending .trc file(s)")
        }

        for trcURL in traceFiles {
            let success = await sendTraceFile(trcURL)
            if success {
                ZipEncryption.deleteTraceFile(trcURL)
                logger.info("✅ Sent and deleted: \(trcURL.lastPathComponent)")
            } else if configuration.isDebugMode {
                logger.warning("⚠️ Failed to send, keeping for retry: \(trcURL.lastPathComponent)")
            }
        }
    }

    // MARK: - Private Methods

    /// V1: send() - send single .trc file to server
    private func sendTraceFile(_ trcURL: URL) async -> Bool {
        guard let serviceHost = configuration.serviceHost,
              !serviceHost.isEmpty else {
            logger.warning("⚠️ ServiceHost not configured - .trc files will be cached locally")
            return false
        }

        // Read .trc file and encode as base64
        guard let fileData = try? Data(contentsOf: trcURL) else {
            logger.error("Failed to read .trc file")
            return false
        }

        let base64Content = fileData.base64EncodedString()
        let recordDate = ZipEncryption.recordDate(from: trcURL)

        // V1 API payload format
        let payload = APIPayload(
            controlKey: configuration.controlKey,
            token: configuration.serviceKey ?? "",
            recordDate: recordDate,
            content: base64Content,
            userPath: SystemInfo.userPath,
            deviceType: .mac
        )

        if configuration.isDebugMode {
            logger.info("🌐 Sending to: \(serviceHost)/api/service/savetrace")
            logger.info("  UserPath: \(SystemInfo.userPath.prefix(16))...")
            logger.info("  RecordDate: \(recordDate)")
            logger.info("  Content size: \(base64Content.count) bytes (base64)")
        }

        // Try HTTPS first, then HTTP (V1 compatible)
        let protocols = ["https", "http"]
        for proto in protocols {
            let urlString = "\(proto)://\(serviceHost)/api/service/savetrace"
            if let url = URL(string: urlString) {
                do {
                    let response = try await sendRequest(payload, to: url)
                    if response.status == 0 {
                        if configuration.isDebugMode {
                            logger.info("✅ Server accepted (\(proto))")
                        }
                        return true
                    } else if configuration.isDebugMode {
                        logger.warning("⚠️ Server returned status: \(response.status)")
                    }
                } catch {
                    logger.debug("Failed with \(proto): \(error.localizedDescription)")
                    continue
                }
            }
        }

        return false
    }

    /// Send API request and decode response
    private func sendRequest(
        _ payload: APIPayload,
        to url: URL
    ) async throws -> APIResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/plain", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        request.httpBody = try encoder.encode(payload)

        // Debug: Log the actual JSON being sent
        if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
            print("📤 Request JSON: \(jsonString.prefix(500))")
        }
        print("📤 RecordDate: \(payload.recordDate)")

        let (data, response) = try await session.data(for: request)

        // Debug: Log the response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Response: \(responseString)")
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }

        let decoder = JSONDecoder()
        return try decoder.decode(APIResponse.self, from: data)
    }
}

// MARK: - JSON Key Helper

private struct AnyKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let code):
            return "Server error: \(code)"
        }
    }
}
