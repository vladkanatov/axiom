import Foundation
import Models
import VMManager

public enum VMEvent: Sendable, Equatable {
    case created(uuid: String)
    case started(uuid: String)
    case stopped(uuid: String, graceful: Bool)
    case paused(uuid: String)
    case resumed(uuid: String)
    case deleted(uuid: String)
    case stateChanged(uuid: String, state: VMState)
    case failed(uuid: String?, message: String)
}

@available(macOS 13.0, *)
public protocol VirtualizationProvider: Sendable {
    func createVM(with configuration: VMConfiguration, uuid: String) async throws -> String
    func startVM(uuid: String) async throws
    func stopVM(uuid: String, graceful: Bool) async throws
    func pauseVM(uuid: String) async throws
    func resumeVM(uuid: String) async throws
    func deleteVM(uuid: String) async throws
    func getVMState(uuid: String) async throws -> VMState
    func listVMs() async throws -> [String: VMState]
    func eventStream() -> AsyncStream<VMEvent>
}
