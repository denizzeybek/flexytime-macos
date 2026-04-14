import Foundation

/// V1-compatible API client
/// Creates .trc files, caches offline, sends to /api/service/savetrace
final class APIClient {

    // MARK: - Properties

    private let configuration: Configuration
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
    func sendUsage(_ usage: UsagePayload) async {
        do {
            let trcURL = try ZipEncryption.encryptUsage(
                usage,
                config: configuration,
                userPath: SystemInfo.userPath
            )
            FlexLog.info("TRC created: \(trcURL.lastPathComponent)", category: .network)
            await sendPendingTraces()
        } catch {
            FlexLog.error("TRC create failed: \(error.localizedDescription)", category: .network)
        }
    }

    /// V1: save_traces() - send all pending .trc files
    func sendPendingTraces() async {
        let traceFiles = ZipEncryption.getPendingTraceFiles(
            userPath: SystemInfo.userPath
        )

        guard !traceFiles.isEmpty else { return }
        FlexLog.info("SEND: \(traceFiles.count) pending .trc file(s)", category: .network)

        for trcURL in traceFiles {
            let success = await sendTraceFile(trcURL)
            if success {
                ZipEncryption.deleteTraceFile(trcURL)
                FlexLog.info("SENT OK: \(trcURL.lastPathComponent)", category: .network)
            } else {
                FlexLog.warning("SEND FAIL: \(trcURL.lastPathComponent) (will retry)", category: .network)
            }
        }
    }

    // MARK: - Private Methods

    /// V1: send() - send single .trc file to server
    private func sendTraceFile(_ trcURL: URL) async -> Bool {
        let serviceHost = configuration.serviceHost
        guard !serviceHost.isEmpty else {
            FlexLog.warning("ServiceHost not configured - caching locally", category: .network)
            return false
        }

        guard let fileData = try? Data(contentsOf: trcURL) else {
            FlexLog.error("Cannot read .trc: \(trcURL.lastPathComponent)", category: .network)
            return false
        }

        let base64Content = fileData.base64EncodedString()
        let recordDate = ZipEncryption.recordDate(from: trcURL)

        let payload = APIPayload(
            controlKey: configuration.controlKey,
            token: configuration.serviceKey ?? "",
            recordDate: recordDate,
            content: base64Content,
            userPath: SystemInfo.userPath,
            deviceType: .mac
        )

        FlexLog.info("API: \(serviceHost) | \(fileData.count)B | \(recordDate)", category: .network)
        FlexLog.info("BASE64 TRC:\n\(base64Content)", category: .network)

        // Try HTTPS first, then HTTP (V1 compatible)
        for proto in ["https", "http"] {
            let urlString = "\(proto)://\(serviceHost)/api/service/savetrace"
            guard let url = URL(string: urlString) else { continue }

            do {
                let response = try await sendRequest(payload, to: url)
                if response.status == 0 {
                    FlexLog.info("API OK (\(proto))", category: .network)
                    return true
                }
                FlexLog.warning("API REJECT: Status=\(response.status)", category: .network)
            } catch {
                FlexLog.debug("API \(proto) failed: \(error.localizedDescription)", category: .network)
                continue
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

        let (data, response) = try await session.data(for: request)

        if let body = String(data: data, encoding: .utf8) {
            FlexLog.info("API response: \(body)", category: .network)
        }

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }

        return try JSONDecoder().decode(APIResponse.self, from: data)
    }

    /// Decode backend GuidEncoder token to CompanyId GUID
    private static func decodeCompanyId(from token: String?) -> String? {
        guard var base64 = token else { return nil }
        base64 = base64.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64), data.count == 16 else { return nil }
        let bytes = [UInt8](data)
        return String(
            format: "%02X%02X%02X%02X-%02X%02X-%02X%02X-%02X%02X-%02X%02X%02X%02X%02X%02X",
            bytes[3], bytes[2], bytes[1], bytes[0],
            bytes[5], bytes[4],
            bytes[7], bytes[6],
            bytes[8], bytes[9],
            bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        )
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
