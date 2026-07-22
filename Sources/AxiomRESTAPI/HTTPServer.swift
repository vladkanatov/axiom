import Foundation
import Dispatch
import AxiomCore

#if os(Linux)
import Glibc
#else
import Darwin
#endif

public final class HTTPServer: @unchecked Sendable {
    public let host: String
    public private(set) var port: Int
    public let router: Router

    private let acceptQueue = DispatchQueue(label: "com.axiom.http.accept")
    private var running = false
    private var listeningSocket: Int32 = -1

    public init(host: String = "127.0.0.1", port: Int = 8889, router: Router) {
        self.host = host
        self.port = port
        self.router = router
    }

    deinit {
        stop()
    }

    @discardableResult
    public func start() throws -> Int {
        guard !running else {
            return port
        }

        let socket = socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else {
            throw AxiomError.serverError("Unable to create listening socket.")
        }

        var reuse: Int32 = 1
        _ = withUnsafePointer(to: &reuse) {
            setsockopt(socket, SOL_SOCKET, SO_REUSEADDR, $0, socklen_t(MemoryLayout<Int32>.size))
        }

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        let hostResult = host.withCString { inet_pton(AF_INET, $0, &address.sin_addr) }
        guard hostResult == 1 else {
            close(socket)
            throw AxiomError.serverError("Unable to parse host address \(host).")
        }

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.stride))
            }
        }

        guard bindResult == 0 else {
            close(socket)
            throw AxiomError.serverError("Unable to bind port \(port).")
        }

        guard listen(socket, 128) == 0 else {
            close(socket)
            throw AxiomError.serverError("Unable to listen on port \(port).")
        }

        listeningSocket = socket
        port = try actualPort(for: socket)
        running = true

        acceptQueue.async { [weak self] in
            self?.acceptLoop()
        }

        return port
    }

    public func stop() {
        running = false
        if listeningSocket >= 0 {
            close(listeningSocket)
            listeningSocket = -1
        }
    }

    private func acceptLoop() {
        while running {
            var address = sockaddr()
            var length = socklen_t(MemoryLayout<sockaddr>.size)
            let clientSocket = withUnsafeMutablePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(listeningSocket, $0, &length)
                }
            }

            guard clientSocket >= 0 else {
                if running {
                    continue
                }
                break
            }

            handleClient(socket: clientSocket)
        }
    }

    private func handleClient(socket: Int32) {
        Task {
            defer { close(socket) }

            let request = readRequest(from: socket)
            let response: HTTPResponse

            if let request {
                response = await router.handle(request: request)
            } else {
                response = .json(status: .badRequest, data: ErrorEnvelope(message: "Unable to parse request."), error: "Bad request")
            }

            let bytes = response.serialized()
            _ = bytes.withUnsafeBytes { buffer in
                guard let baseAddress = buffer.baseAddress else {
                    return 0
                }

                return send(socket, baseAddress, buffer.count, 0)
            }
        }
    }

    private func readRequest(from socket: Int32) -> HTTPRequest? {
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        let received = recv(socket, &buffer, buffer.count, 0)
        guard received > 0 else {
            return nil
        }

        return HTTPRequest.parse(Data(buffer.prefix(received)))
    }

    private func actualPort(for socket: Int32) throws -> Int {
        var address = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let result = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(socket, $0, &length)
            }
        }

        guard result == 0 else {
            throw AxiomError.serverError("Unable to read assigned port.")
        }

        return Int(UInt16(bigEndian: address.sin_port))
    }
}

private struct ErrorEnvelope: Encodable {
    let message: String
}