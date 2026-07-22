import Foundation
import os

public actor VMManager {
    private var machines: [UUID: VMInstance]
    private let provider: any VirtualizationProvider
    private let logger = Logger(subsystem: "com.axiom", category: "VMManager")

    public init(
        provider: any VirtualizationProvider = NoopVirtualizationProvider(),
        initialVMs: [VMInstance] = []
    ) {
        self.provider = provider
        self.machines = Dictionary(uniqueKeysWithValues: initialVMs.map { ($0.id, $0) })
    }

    public func listVMs() -> [VMInstance] {
        machines.values.sorted { $0.configuration.name < $1.configuration.name }
    }

    public func createVM(configuration: VMConfiguration = .example()) async throws -> VMInstance {
        let uuidString = try await provider.createVM(with: configuration, uuid: configuration.id.uuidString)
        let identifier = UUID(uuidString: uuidString) ?? configuration.id
        let vmConfiguration = VMConfiguration(
            id: identifier,
            name: configuration.name,
            cpuCount: configuration.cpuCount,
            memorySizeMiB: configuration.memorySizeMiB,
            diskImages: configuration.diskImages,
            network: configuration.network,
            bootLoader: configuration.bootLoader,
            console: configuration.console
        )
        let state = (try? await provider.getVMState(uuid: identifier.uuidString)) ?? .stopped
        let vm = VMInstance(configuration: vmConfiguration, state: state)
        machines[vm.id] = vm
        logger.info("Created VM \(vm.id.uuidString, privacy: .public)")
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
            network: configuration.network,
            bootLoader: configuration.bootLoader,
            console: configuration.console
        ), state: current.state)
        machines[id] = updated
        return updated
    }

    public func deleteVM(id: UUID) async throws {
        try await provider.deleteVM(uuid: id.uuidString)
        machines[id] = nil
    }

    public func startVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let current = VMInstance(configuration: vm.configuration, state: .starting, lastUpdated: .init())
        machines[id] = current
        try await provider.startVM(uuid: id.uuidString)
        let state = (try? await provider.getVMState(uuid: id.uuidString)) ?? .running
        let updated = VMInstance(configuration: vm.configuration, state: state, lastUpdated: .init())
        machines[id] = updated
        return updated
    }

    public func stopVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let current = VMInstance(configuration: vm.configuration, state: .stopping, lastUpdated: .init())
        machines[id] = current
        try await provider.stopVM(uuid: id.uuidString, graceful: true)
        let state = (try? await provider.getVMState(uuid: id.uuidString)) ?? .stopped
        let updated = VMInstance(configuration: vm.configuration, state: state, lastUpdated: .init())
        machines[id] = updated
        return updated
    }

    public func forceStopVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let current = VMInstance(configuration: vm.configuration, state: .stopping, lastUpdated: .init())
        machines[id] = current
        try await provider.stopVM(uuid: id.uuidString, graceful: false)
        let state = (try? await provider.getVMState(uuid: id.uuidString)) ?? .stopped
        let updated = VMInstance(configuration: vm.configuration, state: state, lastUpdated: .init())
        machines[id] = updated
        return updated
    }

    public func pauseVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let current = VMInstance(configuration: vm.configuration, state: .pausing, lastUpdated: .init())
        machines[id] = current
        try await provider.pauseVM(uuid: id.uuidString)
        let state = (try? await provider.getVMState(uuid: id.uuidString)) ?? .paused
        let updated = VMInstance(configuration: vm.configuration, state: state, lastUpdated: .init())
        machines[id] = updated
        return updated
    }

    public func resumeVM(id: UUID) async throws -> VMInstance {
        let vm = ensureVM(id: id)
        let current = VMInstance(configuration: vm.configuration, state: .starting, lastUpdated: .init())
        machines[id] = current
        try await provider.resumeVM(uuid: id.uuidString)
        let state = (try? await provider.getVMState(uuid: id.uuidString)) ?? .running
        let updated = VMInstance(configuration: vm.configuration, state: state, lastUpdated: .init())
        machines[id] = updated
        return updated
    }
}