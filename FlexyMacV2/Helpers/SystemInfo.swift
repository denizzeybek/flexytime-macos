import Foundation
import CryptoKit

/// V1-compatible system information helper
/// Matches machine.py functions EXACTLY
enum SystemInfo {

    /// V1: get_machinename() - hostname without .local suffix
    static var machineName: String {
        var hostname = ProcessInfo.processInfo.hostName
        // V1: hostname.replace(".local", "")
        hostname = hostname.replacingOccurrences(of: ".local", with: "")
        return hostname
    }

    /// V1: get_username() = machinename + "\\" + os_username
    /// Format: "MacBook-Pro\denizzeybek"
    static var username: String {
        let osUsername = NSUserName()
        return "\(machineName)\\\(osUsername)"
    }

    /// V1: get_ip() - returns primary IPv4 address
    static var ipAddress: String {
        // V1 uses socket connect trick to get primary IP
        var address = "127.0.0.1"

        let socketFD = socket(AF_INET, SOCK_DGRAM, 0)
        guard socketFD >= 0 else { return address }
        defer { close(socketFD) }

        var serverAddr = sockaddr_in()
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = 1
        inet_pton(AF_INET, "10.255.255.255", &serverAddr.sin_addr)

        let connectResult = withUnsafePointer(to: &serverAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard connectResult == 0 else { return address }

        var localAddr = sockaddr_in()
        var localAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

        let nameResult = withUnsafeMutablePointer(to: &localAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socketFD, $0, &localAddrLen)
            }
        }

        guard nameResult == 0 else { return address }

        var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &localAddr.sin_addr, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
        address = String(cString: ipBuffer)

        return address
    }

    /// V1: get_userpath() = SHA256(username).hexdigest().upper()
    /// MUST be UPPERCASE hex string
    static var userPath: String {
        let data = Data(username.utf8)
        let hash = SHA256.hash(data: data)
        // V1: .hexdigest().upper() - UPPERCASE!
        return hash.map { String(format: "%02X", $0) }.joined()
    }
}
