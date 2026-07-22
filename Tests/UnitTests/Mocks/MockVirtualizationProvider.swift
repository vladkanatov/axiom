import Foundation
@testable import AxiomCore

final class MockVirtualizationProvider: VirtualizationProvider, @unchecked Sendable {
    enum Call: Equatable {
        case createVM(uuid: String)
        case startVM(uuid: String)
        case stopVM(uuid: String, graceful: Bool)
        case pauseVM(uuid: String)
        case resumeVM(uuid: String)
        case deleteVM(uuid: String)
    }

    private(set) var calls: [Call] = []
    var nextState: VMState = .stopped

    func createVM(with configuration: VMConfiguration, uuid: String) async throws -> String {
        calls.append(.createVM(uuid: uuid))
        return uuid
    }

    func startVM(uuid: String) async throws {
        calls.append(.startVM(uuid: uuid))
        nextState = .running
    }

    func stopVM(uuid: String, graceful: Bool) async throws {
        calls.append(.stopVM(uuid: uuid, graceful: graceful))
        nextState = .stopped
    }

    func pauseVM(uuid: String) async throws {
        calls.append(.pauseVM(uuid: uuid))
        nextState = .paused
    }

    func resumeVM(uuid: String) async throws {
        calls.append(.resumeVM(uuid: uuid))
        nextState = .running
    }

    func deleteVM(uuid: String) async throws {
        calls.append(.deleteVM(uuid: uuid))
    }

    func getVMState(uuid: String) async throws -> VMState {
        nextState
    }

    func listVMs() async throws -> [String : VMState] {
        [:]
    }

    func eventStream() -> AsyncStream<VMEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
