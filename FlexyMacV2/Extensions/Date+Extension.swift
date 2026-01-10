import Foundation

/// Date extensions for display formatting
extension Date {

    /// Returns a human-readable "time ago" string
    /// Example: "2 minutes ago", "1 hour ago", "just now"
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents(
            [.second, .minute, .hour, .day],
            from: self,
            to: now
        )

        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }

        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }

        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }

        if let seconds = components.second, seconds > 10 {
            return "\(seconds) seconds ago"
        }

        return "just now"
    }

    /// Returns ISO8601 formatted string
    func iso8601String() -> String {
        ISO8601DateFormatter().string(from: self)
    }
}
