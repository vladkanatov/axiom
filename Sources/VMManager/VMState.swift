import Foundation

public enum VMState: String, Codable, Sendable {
    case stopped
    case starting
    case running
    case pausing
    case paused
    case stopping
    case error
}
