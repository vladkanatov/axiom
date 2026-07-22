import Foundation

public enum VMNetworkMode: String, Codable, Sendable {
    case nat
    case bridged
    case none
}

public struct VMNetworkConfiguration: Codable, Sendable, Equatable {
    public var mode: VMNetworkMode
    public var interfaceName: String?

    public init(mode: VMNetworkMode = .nat, interfaceName: String? = nil) {
        self.mode = mode
        self.interfaceName = interfaceName
    }
}

public struct VMConfiguration: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var cpuCount: Int
    public var memorySizeMiB: Int
    public var diskImages: [String]
    public var network: VMNetworkConfiguration

    public init(
        id: UUID = UUID(),
        name: String = "axiom-vm",
        cpuCount: Int = 2,
        memorySizeMiB: Int = 2048,
        diskImages: [String] = [],
        network: VMNetworkConfiguration = VMNetworkConfiguration()
    ) {
        self.id = id
        self.name = name
        self.cpuCount = cpuCount
        self.memorySizeMiB = memorySizeMiB
        self.diskImages = diskImages
        self.network = network
    }

    public static func placeholder(id: UUID = UUID()) -> VMConfiguration {
        VMConfiguration(id: id, name: "placeholder-vm")
    }

    public static func example() -> VMConfiguration {
        VMConfiguration(name: "demo-vm")
    }
}

public struct DiskImage: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var path: String
    public var format: String

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        format: String = "img"
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.format = format
    }

    public static func example() -> DiskImage {
        DiskImage(name: "system", path: "/tmp/system.img")
    }
}