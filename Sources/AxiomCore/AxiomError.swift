import Foundation

public enum AxiomError: Error, LocalizedError, Sendable {
    case vmNotFound(UUID)
    case invalidConfiguration(String)
    case persistenceFailed(String)
    case virtualizationUnavailable
    case serverError(String)

    public var errorDescription: String? {
        switch self {
        case .vmNotFound(let identifier):
            return "VM \(identifier.uuidString) was not found."
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .persistenceFailed(let reason):
            return "Persistence failed: \(reason)"
        case .virtualizationUnavailable:
            return "Virtualization is unavailable on this platform."
        case .serverError(let reason):
            return "Server error: \(reason)"
        }
    }
}