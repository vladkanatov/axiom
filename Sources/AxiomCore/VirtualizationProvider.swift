import Foundation

public protocol VirtualizationProvider: Sendable {
    func start(vm: VMInstance) async throws
    func stop(vm: VMInstance) async throws
    func forceStop(vm: VMInstance) async throws
    func pause(vm: VMInstance) async throws
    func resume(vm: VMInstance) async throws
}