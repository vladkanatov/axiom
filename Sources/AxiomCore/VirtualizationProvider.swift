import Foundation

@_exported import AxiomVirtualization

public struct NoopVirtualizationProvider: VirtualizationProvider {
    public init() {}

    public func createVM(with configuration: VMConfiguration, uuid: String) async throws -> String {
        uuid.isEmpty ? configuration.id.uuidString : uuid
    }

    public func startVM(uuid: String) async throws {}

    public func stopVM(uuid: String, graceful: Bool) async throws {}

    public func pauseVM(uuid: String) async throws {}

    public func resumeVM(uuid: String) async throws {}

    public func deleteVM(uuid: String) async throws {}

    public func getVMState(uuid: String) async throws -> VMState {
        .stopped
    }

    public func listVMs() async throws -> [String: VMState] {
        [:]
    }

    public func eventStream() -> AsyncStream<VMEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
