import Cocoa
import os.log

/// V1-compatible idle detection
/// Uses kCGAnyInputEventType like V1's macos.py seconds_since_last_input()
final class IdleDetector {

    // MARK: - Properties

    private let logger = Logger.services

    /// Idle threshold in seconds (V1 default: 60 seconds)
    var idleThreshold: TimeInterval = 60

    // MARK: - Public Methods

    /// V1: seconds_since_last_input() using kCGAnyInputEventType
    /// Returns seconds since last user input (keyboard/mouse)
    func secondsSinceLastInput() -> TimeInterval {
        // V1 uses kCGAnyInputEventType which catches all input events
        CGEventSource.secondsSinceLastEventType(
            .hidSystemState,
            eventType: CGEventType(rawValue: ~0)! // kCGAnyInputEventType
        )
    }

    /// Checks if user is currently idle (AFK)
    /// - Returns: true if idle time exceeds threshold
    func isUserIdle() -> Bool {
        let idleTime = secondsSinceLastInput()
        let isIdle = idleTime >= idleThreshold

        if isIdle {
            logger.debug("User is idle for \(Int(idleTime)) seconds")
        }

        return isIdle
    }

    /// Returns the last activity timestamp
    func lastActivityTime() -> Date {
        let idleSeconds = secondsSinceLastInput()
        return Date().addingTimeInterval(-idleSeconds)
    }
}
