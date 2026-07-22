import Foundation

public enum VMState: String, Codable, Sendable {
    case created
    case starting
    case running
    case paused
    case stopping
    case stopped
    case failed
}