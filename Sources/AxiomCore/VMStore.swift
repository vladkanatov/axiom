import Foundation

public protocol VMStore: Sendable {
    func loadVMs() async throws -> [VMInstance]
    func saveVM(_ vm: VMInstance) async throws
    func deleteVM(id: UUID) async throws
}

public final class FileVMStore: VMStore {
    public init() {}

    public func loadVMs() async throws -> [VMInstance] {
        []
    }

    public func saveVM(_ vm: VMInstance) async throws {}

    public func deleteVM(id: UUID) async throws {}
}