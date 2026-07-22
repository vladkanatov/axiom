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

public enum VMBootLoader: Codable, Sendable, Equatable {
    case linux(kernelPath: String, initrdPath: String? = nil, commandLine: String? = nil)
    case macOS(recoveryImagePath: String? = nil)

    private enum CodingKeys: String, CodingKey {
        case kind
        case kernelPath
        case initrdPath
        case commandLine
        case recoveryImagePath
    }

    private enum Kind: String, Codable {
        case linux
        case macOS
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .linux:
            self = .linux(
                kernelPath: try container.decode(String.self, forKey: .kernelPath),
                initrdPath: try container.decodeIfPresent(String.self, forKey: .initrdPath),
                commandLine: try container.decodeIfPresent(String.self, forKey: .commandLine)
            )
        case .macOS:
            self = .macOS(recoveryImagePath: try container.decodeIfPresent(String.self, forKey: .recoveryImagePath))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .linux(kernelPath, initrdPath, commandLine):
            try container.encode(Kind.linux, forKey: .kind)
            try container.encode(kernelPath, forKey: .kernelPath)
            try container.encodeIfPresent(initrdPath, forKey: .initrdPath)
            try container.encodeIfPresent(commandLine, forKey: .commandLine)
        case let .macOS(recoveryImagePath):
            try container.encode(Kind.macOS, forKey: .kind)
            try container.encodeIfPresent(recoveryImagePath, forKey: .recoveryImagePath)
        }
    }
}

public struct VMConsoleConfiguration: Codable, Sendable, Equatable {
    public var logPath: String?

    public init(logPath: String? = nil) {
        self.logPath = logPath
    }
}

public struct DiskImage: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var path: String
    public var format: String
    public var sizeMiB: Int?
    public var source: String?

    public init(
        id: UUID = UUID(),
        name: String,
        path: String,
        format: String = "img",
        sizeMiB: Int? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.format = format
        self.sizeMiB = sizeMiB
        self.source = source
    }

    public static func example() -> DiskImage {
        DiskImage(name: "system", path: "/tmp/system.img")
    }
}

public struct VMConfiguration: Codable, Sendable, Equatable {
    public var id: UUID
    public var name: String
    public var cpuCount: Int
    public var memorySizeMiB: Int
    public var diskImages: [String]
    public var network: VMNetworkConfiguration
    public var bootLoader: VMBootLoader
    public var console: VMConsoleConfiguration

    public init(
        id: UUID = UUID(),
        name: String = "axiom-vm",
        cpuCount: Int = 2,
        memorySizeMiB: Int = 2048,
        diskImages: [String] = [],
        network: VMNetworkConfiguration = VMNetworkConfiguration(),
        bootLoader: VMBootLoader = .linux(kernelPath: "/usr/local/share/axiom/vmlinuz"),
        console: VMConsoleConfiguration = VMConsoleConfiguration()
    ) {
        self.id = id
        self.name = name
        self.cpuCount = cpuCount
        self.memorySizeMiB = memorySizeMiB
        self.diskImages = diskImages
        self.network = network
        self.bootLoader = bootLoader
        self.console = console
    }

    public static func placeholder(id: UUID = UUID()) -> VMConfiguration {
        VMConfiguration(id: id, name: "placeholder-vm")
    }

    public static func example() -> VMConfiguration {
        VMConfiguration(name: "demo-vm")
    }
}
