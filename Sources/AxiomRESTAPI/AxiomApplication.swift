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
    public let router: RESTRouter
    public let server: HTTPServer

    public init(
        configuration: AxiomApplicationConfiguration = AxiomApplicationConfiguration(),
        provider: any VirtualizationProvider = NoopVirtualizationProvider()
    ) {
        self.configuration = configuration
        let manager = VMManager(provider: provider)
        let router = RESTRouter(manager: manager)
        self.manager = manager
        self.router = router
        self.server = HTTPServer(host: configuration.host, port: configuration.port, router: router)
    }

    @discardableResult
    public func start() throws -> Int {
        try server.start()
    }

    public func stop() {
        server.stop()
    }
}