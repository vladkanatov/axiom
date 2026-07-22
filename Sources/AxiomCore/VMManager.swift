import Foundation
import os
import Models
import AxiomVirtualization

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

    public func createVM(config: VMConfiguration, uuid: String? = nil) async throws -> String {
        let identifier = uuid.flatMap(UUID.init(uuidString:)) ?? config.id
        let vm = try await createVM(configuration: VMConfiguration(
            id: identifier,
            name: config.name,
            cpuCount: config.cpuCount,
            memorySizeMiB: config.memorySizeMiB,
            diskImages: config.diskImages,
            network: config.network,
            bootLoader: config.bootLoader,
            console: config.console
        ))
        return vm.id.uuidString
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

    public func updateVMConfig(uuid: String, config: VMConfiguration) async throws -> VMConfiguration? {
        guard let identifier = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }

        let currentState = try await getVMState(uuid: uuid)
        guard currentState == .stopped else {
            throw AxiomError.serverError("VM \(uuid) must be stopped before updating the configuration.")
        }

        let updated = try await updateVM(id: identifier, configuration: VMConfiguration(
            id: identifier,
            name: config.name,
            cpuCount: config.cpuCount,
            memorySizeMiB: config.memorySizeMiB,
            diskImages: config.diskImages,
            network: config.network,
            bootLoader: config.bootLoader,
            console: config.console
        ))

        return updated.configuration
    }

    public func deleteVM(id: UUID) async throws {
        try await provider.deleteVM(uuid: id.uuidString)
        machines[id] = nil
    }

    public func deleteVM(uuid: String) async throws {
        guard let identifier = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }
        try await deleteVM(id: identifier)
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

    public func startVM(uuid: String) async throws {
        guard let identifier = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }
        _ = try await startVM(id: identifier)
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

    public func stopVM(uuid: String, graceful: Bool) async throws {
        guard let identifier = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }
        if graceful {
            _ = try await stopVM(id: identifier)
        } else {
            _ = try await forceStopVM(id: identifier)
        }
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

    public func pauseVM(uuid: String) async throws {
        guard let identifier = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }
        _ = try await pauseVM(id: identifier)
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

    public func resumeVM(uuid: String) async throws {
        guard let identifier = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }
        _ = try await resumeVM(id: identifier)
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

    public func getVMConfig(uuid: String) async throws -> VMConfiguration? {
        guard let identifier = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }

        return machines[identifier]?.configuration
    }

    public func getVMState(uuid: String) async throws -> VMState {
        guard let identifier = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }

        if let state = machines[identifier]?.state {
            return state
        }

        return try await provider.getVMState(uuid: uuid)
    }
}