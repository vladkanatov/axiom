import Dispatch
import Foundation
import os
import Virtualization
import Models
import VMManager

@available(macOS 13.0, *)
public actor VZProvider: VirtualizationProvider {
    private let fileManager: FileManager
    public let baseDirectory: URL
    public let imagesDirectory: URL
    public let configsDirectory: URL

    private var machines: [String: VZVirtualMachine] = [:]
    private var configurations: [String: VMConfiguration] = [:]
    private var states: [String: VMState] = [:]
    private var queues: [String: DispatchQueue] = [:]
    private var delegates: [String: VZEventDelegate] = [:]
    private var streamContinuations: [UUID: AsyncStream<VMEvent>.Continuation] = [:]
    private let logger = Logger(subsystem: "com.axiom", category: "VZProvider")

    public init(baseDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".axiom")) {
        self.fileManager = .default
        self.baseDirectory = baseDirectory
        self.imagesDirectory = baseDirectory.appendingPathComponent("images", isDirectory: true)
        self.configsDirectory = baseDirectory.appendingPathComponent("vms", isDirectory: true)

        try? fileManager.createDirectory(at: self.imagesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: self.configsDirectory, withIntermediateDirectories: true)
    }

    public nonisolated func eventStream() -> AsyncStream<VMEvent> {
        AsyncStream { continuation in
            let token = UUID()
            Task { await self.registerStreamContinuation(continuation, token: token) }
            continuation.onTermination = { @Sendable _ in
                Task { await self.removeStreamContinuation(token: token) }
            }
        }
    }

    public func createVM(with configuration: VMConfiguration, uuid: String) async throws -> String {
        try ensureSupported()

        let identifier = normalizedUUIDString(uuid, fallback: configuration.id.uuidString)
        let resolvedConfiguration = VMConfiguration(
            id: UUID(uuidString: identifier) ?? configuration.id,
            name: configuration.name,
            cpuCount: configuration.cpuCount,
            memorySizeMiB: configuration.memorySizeMiB,
            diskImages: configuration.diskImages,
            network: configuration.network,
            bootLoader: configuration.bootLoader,
            console: configuration.console
        )

        try saveConfiguration(resolvedConfiguration, uuid: identifier)
        let machine = try makeMachine(for: resolvedConfiguration, uuid: identifier)
        machines[identifier] = machine
        configurations[identifier] = resolvedConfiguration
        states[identifier] = .stopped

        logger.info("Created VM \(identifier, privacy: .public)")
        publish(.created(uuid: identifier))
        return identifier
    }

    public func startVM(uuid: String) async throws {
        let identifier = try requireUUIDString(uuid)
        let machine = try machine(for: identifier)

        states[identifier] = .starting
        await publish(.stateChanged(uuid: identifier, state: .starting))
        logger.info("Starting VM \(identifier, privacy: .public)")

        try await machine.start()

        let newState = state(from: machine.state)
        states[identifier] = newState
        publish(.started(uuid: identifier))
        publish(.stateChanged(uuid: identifier, state: newState))
    }

    public func stopVM(uuid: String, graceful: Bool) async throws {
        let identifier = try requireUUIDString(uuid)
        let machine = try machine(for: identifier)

        states[identifier] = .stopping
        await publish(.stateChanged(uuid: identifier, state: .stopping))
        logger.info("Stopping VM \(identifier, privacy: .public), graceful: \(graceful, privacy: .public)")

        if graceful {
            try requestGuestStop(machine: machine, uuid: identifier)
            states[identifier] = .stopping
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            machine.stop { error in
                if let error {
                    continuation.resume(throwing: Self.mapFrameworkError(error, uuid: identifier))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        states[identifier] = .stopped
        publish(.stopped(uuid: identifier, graceful: false))
        publish(.stateChanged(uuid: identifier, state: .stopped))
    }

    public func pauseVM(uuid: String) async throws {
        let identifier = try requireUUIDString(uuid)
        let machine = try machine(for: identifier)

        states[identifier] = .pausing
        publish(.stateChanged(uuid: identifier, state: .pausing))
        logger.info("Pausing VM \(identifier, privacy: .public)")

        try await machine.pause()

        let newState = state(from: machine.state)
        states[identifier] = newState
        publish(.paused(uuid: identifier))
        publish(.stateChanged(uuid: identifier, state: newState))
    }

    public func resumeVM(uuid: String) async throws {
        let identifier = try requireUUIDString(uuid)
        let machine = try machine(for: identifier)

        states[identifier] = .starting
        publish(.stateChanged(uuid: identifier, state: .starting))
        logger.info("Resuming VM \(identifier, privacy: .public)")

        try await machine.resume()

        let newState = state(from: machine.state)
        states[identifier] = newState
        publish(.resumed(uuid: identifier))
        publish(.stateChanged(uuid: identifier, state: newState))
    }

    public func deleteVM(uuid: String) async throws {
        let identifier = try requireUUIDString(uuid)
        machines[identifier] = nil
        configurations[identifier] = nil
        states[identifier] = nil
        queues[identifier] = nil
        delegates[identifier] = nil
        try? fileManager.removeItem(at: vmDirectory(for: identifier))
        publish(.deleted(uuid: identifier))
        logger.info("Deleted VM \(identifier, privacy: .public)")
    }

    public func getVMState(uuid: String) async throws -> VMState {
        let identifier = try requireUUIDString(uuid)
        if let state = states[identifier] {
            return state
        }

        if let machine = machines[identifier] {
            let state = state(from: machine.state)
            states[identifier] = state
            return state
        }

        if fileManager.fileExists(atPath: configurationFile(for: identifier).path) {
            return .stopped
        }

        throw AxiomError.vmNotFound(UUID(uuidString: identifier) ?? UUID())
    }

    public func listVMs() async throws -> [String: VMState] {
        var result = states

        let directoryContents = (try? fileManager.contentsOfDirectory(
            at: configsDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for vmDirectory in directoryContents where isDirectory(url: vmDirectory) {
            let identifier = vmDirectory.lastPathComponent
            if result[identifier] == nil {
                result[identifier] = .stopped
            }
        }

        return result
    }

    private func registerStreamContinuation(_ continuation: AsyncStream<VMEvent>.Continuation, token: UUID) {
        streamContinuations[token] = continuation
    }

    private func removeStreamContinuation(token: UUID) {
        streamContinuations[token] = nil
    }

    private func publish(_ event: VMEvent) {
        for continuation in streamContinuations.values {
            continuation.yield(event)
        }
    }

    private func ensureSupported() throws {
        guard VZVirtualMachine.isSupported else {
            throw AxiomError.virtualizationUnavailable
        }
    }

    private func machine(for uuid: String) throws -> VZVirtualMachine {
        if let machine = machines[uuid] {
            return machine
        }

        let configuration = try loadConfiguration(for: uuid)
        let machine = try makeMachine(for: configuration, uuid: uuid)
        machines[uuid] = machine
        configurations[uuid] = configuration
        states[uuid] = states[uuid] ?? .stopped
        return machine
    }

    private func makeMachine(for configuration: VMConfiguration, uuid: String) throws -> VZVirtualMachine {
        let vmConfiguration = try makeVirtualMachineConfiguration(from: configuration)
        let queue = queues[uuid] ?? DispatchQueue(label: "com.axiom.vz.\(uuid)")
        queues[uuid] = queue

        let machine = VZVirtualMachine(configuration: vmConfiguration, queue: queue)
        let delegate = VZEventDelegate(
            guestDidStopHandler: { [weak self] in
                Task { await self?.handleGuestDidStop(uuid: uuid) }
            },
            didStopWithErrorHandler: { [weak self] error in
                Task { await self?.handleFailure(uuid: uuid, error: error) }
            },
            networkAttachmentDisconnectedHandler: { [weak self] error in
                Task { await self?.handleFailure(uuid: uuid, error: error) }
            }
        )
        machine.delegate = delegate
        delegates[uuid] = delegate
        return machine
    }

    private func makeVirtualMachineConfiguration(from configuration: VMConfiguration) throws -> VZVirtualMachineConfiguration {
        let vmConfiguration = VZVirtualMachineConfiguration()
        vmConfiguration.cpuCount = max(1, min(configuration.cpuCount, ProcessInfo.processInfo.activeProcessorCount))
        vmConfiguration.memorySize = UInt64(max(1024, configuration.memorySizeMiB)) * 1024 * 1024
        vmConfiguration.bootLoader = try makeBootLoader(from: configuration.bootLoader)
        vmConfiguration.platform = makePlatform(for: configuration.bootLoader)
        vmConfiguration.storageDevices = try makeStorageDevices(from: configuration.diskImages)
        vmConfiguration.networkDevices = try makeNetworkDevices(from: configuration.network)
        vmConfiguration.serialPorts = [makeSerialPort(from: configuration.console)]

        do {
            try vmConfiguration.validate()
        } catch {
            throw Self.mapFrameworkError(error, uuid: configuration.id.uuidString)
        }

        return vmConfiguration
    }

    private func makeBootLoader(from bootLoader: VMBootLoader) throws -> VZBootLoader {
        switch bootLoader {
        case let .linux(kernelPath, initrdPath, commandLine):
            let loader = VZLinuxBootLoader(kernelURL: URL(fileURLWithPath: kernelPath))
            if let initrdPath {
                loader.initialRamdiskURL = URL(fileURLWithPath: initrdPath)
            }
            if let commandLine {
                loader.commandLine = commandLine
            }
            return loader
        case .macOS:
            return VZMacOSBootLoader()
        }
    }

    private func makePlatform(for bootLoader: VMBootLoader) -> VZPlatformConfiguration {
        switch bootLoader {
        case .linux:
            return VZGenericPlatformConfiguration()
        case .macOS:
            return VZMacPlatformConfiguration()
        }
    }

    private func makeStorageDevices(from diskImages: [String]) throws -> [VZStorageDeviceConfiguration] {
        try diskImages.map { diskPath in
            let attachment = try makeDiskAttachment(path: diskPath)
            let device = VZVirtioBlockDeviceConfiguration(attachment: attachment)
            return device
        }
    }

    private func makeDiskAttachment(path: String) throws -> VZDiskImageStorageDeviceAttachment {
        do {
            return try VZDiskImageStorageDeviceAttachment(url: URL(fileURLWithPath: path), readOnly: false)
        } catch {
            throw Self.mapFrameworkError(error, uuid: path)
        }
    }

    private func makeNetworkDevices(from network: VMNetworkConfiguration) throws -> [VZNetworkDeviceConfiguration] {
        guard network.mode != .none else {
            return []
        }

        let device = VZVirtioNetworkDeviceConfiguration()
        switch network.mode {
        case .nat:
            device.attachment = VZNATNetworkDeviceAttachment()
        case .bridged:
            guard
                let interfaceName = network.interfaceName,
                let interface = VZBridgedNetworkInterface.networkInterfaces.first(where: { $0.identifier == interfaceName })
            else {
                throw AxiomError.invalidConfiguration("A bridged interface name is required for bridged networking.")
            }
            device.attachment = VZBridgedNetworkDeviceAttachment(interface: interface)
        case .none:
            break
        }

        return [device]
    }

    private func makeSerialPort(from console: VMConsoleConfiguration) -> VZSerialPortConfiguration {
        let serialPort = VZVirtioConsoleDeviceSerialPortConfiguration()
        if let logPath = console.logPath {
            let fileHandle = FileHandle(forWritingAtPath: logPath)
            serialPort.attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: nil, fileHandleForWriting: fileHandle)
        } else {
            serialPort.attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: nil, fileHandleForWriting: nil)
        }
        return serialPort
    }

    private func state(from state: VZVirtualMachine.State) -> VMState {
        switch state {
        case .running:
            return .running
        case .paused:
            return .paused
        case .starting:
            return .starting
        case .pausing:
            return .pausing
        case .resuming:
            return .starting
        case .stopping:
            return .stopping
        case .saving, .restoring:
            return .starting
        case .error:
            return .error
        case .stopped:
            return .stopped
        @unknown default:
            return .error
        }
    }

    private func requestGuestStop(machine: VZVirtualMachine, uuid: String) throws {
        try machine.requestStop()
    }

    private func handleGuestDidStop(uuid: String) {
        states[uuid] = .stopped
        publish(.stopped(uuid: uuid, graceful: true))
        publish(.stateChanged(uuid: uuid, state: .stopped))
    }

    private func handleFailure(uuid: String, error: Error) {
        states[uuid] = .error
        publish(.failed(uuid: uuid, message: error.localizedDescription))
        publish(.stateChanged(uuid: uuid, state: .error))
        logger.error("VM \(uuid, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
    }

    private func loadConfiguration(for uuid: String) throws -> VMConfiguration {
        let url = configurationFile(for: uuid)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(VMConfiguration.self, from: data)
    }

    private func saveConfiguration(_ configuration: VMConfiguration, uuid: String) throws {
        let directory = vmDirectory(for: uuid)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(configuration)
        try data.write(to: configurationFile(for: uuid), options: [.atomic])
    }

    private func configurationFile(for uuid: String) -> URL {
        vmDirectory(for: uuid).appendingPathComponent("configuration.json")
    }

    private func vmDirectory(for uuid: String) -> URL {
        configsDirectory.appendingPathComponent(uuid, isDirectory: true)
    }

    private func normalizedUUIDString(_ uuid: String, fallback: String) -> String {
        UUID(uuidString: uuid)?.uuidString ?? UUID(uuidString: fallback)?.uuidString ?? fallback
    }

    private func requireUUIDString(_ uuid: String) throws -> String {
        guard let validUUID = UUID(uuidString: uuid) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(uuid)")
        }
        return validUUID.uuidString
    }

    nonisolated private static func mapFrameworkError(_ error: Error, uuid: String) -> AxiomError {
        if let axiomError = error as? AxiomError {
            return axiomError
        }

        return .serverError("VM \(uuid): \(error.localizedDescription)")
    }

    private func isDirectory(url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }
}
