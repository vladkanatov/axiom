import Foundation
import AxiomCore

#if canImport(Virtualization)
import Virtualization
#endif

public final class NativeVirtualizationProvider: VirtualizationProvider {
    public init() {}

    public func start(vm: VMInstance) async throws {}

    public func stop(vm: VMInstance) async throws {}

    public func forceStop(vm: VMInstance) async throws {}

    public func pause(vm: VMInstance) async throws {}

    public func resume(vm: VMInstance) async throws {}
}