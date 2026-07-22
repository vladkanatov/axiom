import Foundation

public protocol VirtualizationProvider: Sendable {
    func start(vm: VMInstance) async throws
    func stop(vm: VMInstance) async throws
    func forceStop(vm: VMInstance) async throws
    func pause(vm: VMInstance) async throws
    func resume(vm: VMInstance) async throws
}

public struct NoopVirtualizationProvider: VirtualizationProvider {
    public init() {}

    public func start(vm: VMInstance) async throws {}

    public func stop(vm: VMInstance) async throws {}

    public func forceStop(vm: VMInstance) async throws {}

    public func pause(vm: VMInstance) async throws {}

    public func resume(vm: VMInstance) async throws {}
}