import Foundation

public actor VMManager {
    private var machines: [UUID: VMInstance]
    private let provider: any VirtualizationProvider

    public init(
        provider: any VirtualizationProvider = NativeVirtualizationProvider(),
        initialVMs: [VMInstance] = []
    ) {
        self.provider = provider
        self.machines = Dictionary(uniqueKeysWithValues: initialVMs.map { ($0.id, $0) })
    }

    public func listVMs() -> [VMInstance] {
        machines.values.sorted { $0.configuration.name < $1.configuration.name }
    }

    public func createVM(configuration: VMConfiguration = .example()) async throws -> VMInstance {
        let vm = VMInstance(configuration: configuration, state: .created)
        machines[vm.id] = vm
        return vm
    }

    public func getVM(id: UUID) -> VMInstance? {
        machines[id]
    }

    public func ensureVM(id: UUID) -> VMInstance {
        if let existing = machines[id] {
            return existing
        }

        let placeholder = VMInstance(configuration: .placeholder(id: id))
        machines[id] = placeholder
        return placeholder
    }

    public func updateVM(id: UUID, configuration: VMConfiguration) async throws -> VMInstance {
        let current = machines[id] ?? VMInstance(configuration: configuration)
        let updated = VMInstance(configuration: VMConfiguration(
            id: id,
            name: configuration.name,
            cpuCount: configuration.cpuCount,
            memorySizeMiB: configuration.memorySizeMiB,
            diskImages: configuration.diskImages,
            network: configuration.network
        ), state: current.state)
        machines[id] = updated
        return updated
    }

    public func deleteVM(id: UUID) async throws {
        machines[id] = nil
    }

    public func startVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let updated = VMInstance(configuration: vm.configuration, state: .running, lastUpdated: .init())
        machines[id] = updated
        try await provider.start(vm: updated)
        return updated
    }

    public func stopVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let updated = VMInstance(configuration: vm.configuration, state: .stopped, lastUpdated: .init())
        machines[id] = updated
        try await provider.stop(vm: updated)
        return updated
    }

    public func forceStopVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let updated = VMInstance(configuration: vm.configuration, state: .stopped, lastUpdated: .init())
        machines[id] = updated
        try await provider.forceStop(vm: updated)
        return updated
    }

    public func pauseVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let updated = VMInstance(configuration: vm.configuration, state: .paused, lastUpdated: .init())
        machines[id] = updated
        try await provider.pause(vm: updated)
        return updated
    }

    public func resumeVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let updated = VMInstance(configuration: vm.configuration, state: .running, lastUpdated: .init())
        machines[id] = updated
        try await provider.resume(vm: updated)
        return updated
    }
}