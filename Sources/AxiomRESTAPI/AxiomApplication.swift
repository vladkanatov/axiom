import Foundation
import AxiomCore
import AxiomVirtualization

public struct AxiomApplicationConfiguration: Sendable {
    public var host: String
    public var port: Int

    public init(host: String = "127.0.0.1", port: Int = 8889) {
        self.host = host
        self.port = port
    }
}

public final class AxiomApplication {
    public let configuration: AxiomApplicationConfiguration
    public let manager: VMManager
    public let router: Router
    public let server: HTTPServer

    public init(
        configuration: AxiomApplicationConfiguration = AxiomApplicationConfiguration(),
        manager: VMManager
    ) {
        self.configuration = configuration
        self.manager = manager
        self.router = Router(vmm: manager)
        self.server = HTTPServer(host: configuration.host, port: configuration.port, router: self.router)
    }

    public convenience init(
        configuration: AxiomApplicationConfiguration = AxiomApplicationConfiguration(),
        provider: any VirtualizationProvider = NoopVirtualizationProvider()
    ) {
        self.init(configuration: configuration, manager: VMManager(provider: provider))
    }

    @discardableResult
    public func start() throws -> Int {
        try server.start()
    }

    public func stop() {
        server.stop()
    }
}