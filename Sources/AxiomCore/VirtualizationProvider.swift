import Foundation

@_exported import AxiomVirtualization

public struct NoopVirtualizationProvider: VirtualizationProvider {
    public init() {}

    public func createVM(with configuration: VMConfiguration, uuid: String) async throws -> String {
        uuid.isEmpty ? configuration.id.uuidString : uuid
    }

    public func updateVMConfiguration(uuid: String, configuration: VMConfiguration) async throws {}

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

    public func listDiskImages() async throws -> [DiskImage] {
        []
    }

    public func importDiskImage(from source: String, name: String?) async throws -> DiskImage {
        DiskImage(
            name: name ?? URL(fileURLWithPath: source).deletingPathExtension().lastPathComponent,
            path: source,
            source: source
        )
    }

    public func createEmptyDiskImage(name: String, sizeMiB: Int) async throws -> DiskImage {
        DiskImage(name: name, path: "/tmp/\(name).img", sizeMiB: sizeMiB, source: "empty")
    }

    public func attachDiskImage(_ image: DiskImage, toVM uuid: String) async throws -> VMConfiguration {
        let identifier = UUID(uuidString: uuid) ?? UUID()
        return VMConfiguration(id: identifier, name: image.name, diskImages: [image.path])
    }

    public func eventStream() -> AsyncStream<VMEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }
}
