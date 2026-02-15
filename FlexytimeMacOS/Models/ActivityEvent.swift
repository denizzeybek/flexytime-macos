import Foundation

// MARK: - V1 Compatible Enums

/// Device type enum - MUST match V1 exactly
enum DeviceType: Int, Codable {
    case windows = 0
    case mac = 1
}

/// Usage data type enum - MUST match V1 exactly
enum UsageDataType: Int, Codable {
    case input = 0      // Normal activity with views
    case calendar = 1   // 15-minute ping event
}

// MARK: - View Event (Single Activity)

/// Represents a single window activity event
/// V1 creates new event ONLY when ProcessName changes (NOT Title)
struct ViewEvent: Codable {
    let processName: String
    let title: String
    let time: Date
    var expireTime: Date
    let properties: [String: String]

    enum CodingKeys: String, CodingKey {
        case processName = "ProcessName"
        case title = "Title"
        case time = "Time"
        case expireTime = "ExpireTime"
        case properties = "Properties"
    }

    /// Maps macOS app names to backend-expected process names
    /// Backend PerformJob.cs TryCreateWebAllocation() uses these exact strings
    private static let backendProcessNameMap: [String: String] = [
        "Google Chrome": "chrome",
        "Microsoft Edge": "msedge",
        "Opera": "opera",
        "Safari": "safari"
    ]

    /// Custom encode: maps ProcessName to backend format
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let mapped = Self.backendProcessNameMap[processName] ?? processName
        try container.encode(mapped, forKey: .processName)
        try container.encode(title, forKey: .title)
        try container.encode(time, forKey: .time)
        try container.encode(expireTime, forKey: .expireTime)
        try container.encode(properties, forKey: .properties)
    }

    /// Duration in seconds
    var duration: TimeInterval {
        expireTime.timeIntervalSince(time)
    }

    /// Check if this event should be saved (V1: duration > 1 second)
    var isValid: Bool {
        duration > 1.0
    }
}

// MARK: - Usage Payload (Before Encryption)

/// Complete usage data sent to server
/// This is the JSON that gets encrypted into .trc file
struct UsagePayload: Codable {
    let deviceType: DeviceType
    let version: String
    let username: String
    let machineName: String
    let ipAddress: String
    let dataType: UsageDataType
    let recordDate: Date
    let views: [ViewEvent]?
    let calendar: String?

    enum CodingKeys: String, CodingKey {
        case deviceType = "DeviceType"
        case version = "Version"
        case username = "Username"
        case machineName = "MachineName"
        case ipAddress = "IpAddress"
        case dataType = "DataType"
        case recordDate = "RecordDate"
        case views = "Views"
        case calendar = "Calendar"
    }

    /// Custom encode to always include Calendar as null (Swift skips nil by default)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceType, forKey: .deviceType)
        try container.encode(version, forKey: .version)
        try container.encode(username, forKey: .username)
        try container.encode(machineName, forKey: .machineName)
        try container.encode(ipAddress, forKey: .ipAddress)
        try container.encode(dataType, forKey: .dataType)
        try container.encode(recordDate, forKey: .recordDate)
        try container.encode(views, forKey: .views)
        try container.encodeNil(forKey: .calendar)
    }
}

// MARK: - API Request Payload

/// Final payload sent to /api/service/savetrace
/// Contains base64 encoded encrypted .trc file
struct APIPayload: Codable {
    let controlKey: String
    let token: String
    let recordDate: Date
    let content: String  // Base64 encoded .trc file
    let userPath: String // SHA256 hash of username
    let deviceType: DeviceType

    enum CodingKeys: String, CodingKey {
        case controlKey = "ControlKey"
        case token = "Token"
        case recordDate = "RecordDate"
        case content = "Content"
        case userPath = "UserPath"
        case deviceType = "DeviceType"
    }
}

// MARK: - API Response

/// Server response from savetrace endpoint
struct APIResponse: Codable {
    let status: Int

    enum CodingKeys: String, CodingKey {
        case status = "Status"
    }

    var isSuccess: Bool {
        status == 0
    }
}
