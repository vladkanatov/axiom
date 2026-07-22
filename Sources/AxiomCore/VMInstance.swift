import Foundation

public struct VMInstance: Codable, Sendable, Equatable {
    public var configuration: VMConfiguration
    public var state: VMState
    public var lastUpdated: Date

    public init(
        configuration: VMConfiguration,
        state: VMState = .created,
        lastUpdated: Date = .init()
    ) {
        self.configuration = configuration
        self.state = state
        self.lastUpdated = lastUpdated
    }

    public var id: UUID {
        configuration.id
    }

    public var summary: [String: Any] {
        [
            "uuid": id.uuidString,
            "name": configuration.name,
            "state": state.rawValue
        ]
    }

    public var details: [String: Any] {
        let interfaceName: Any = configuration.network.interfaceName ?? NSNull()

        return [
            "uuid": id.uuidString,
            "state": state.rawValue,
            "configuration": [
                "id": configuration.id.uuidString,
                "name": configuration.name,
                "cpuCount": configuration.cpuCount,
                "memorySizeMiB": configuration.memorySizeMiB,
                "diskImages": configuration.diskImages,
                "network": [
                    "mode": configuration.network.mode.rawValue,
                    "interfaceName": interfaceName
                ]
            ]
        ]
    }
}