import Foundation
import AxiomCore

public struct RESTRouter: Sendable {
    public let manager: VMManager

    public init(manager: VMManager) {
        self.manager = manager
    }

    public func handle(request: HTTPRequest) async -> HTTPResponse {
        let route = normalizedPath(from: request.path)

        switch (request.method.uppercased(), route.path) {
        case ("GET", "/vms"):
            let vms = await manager.listVMs()
            return .json(data: VMCollectionResponse(vms: vms))
        case ("POST", "/vms"):
            let configuration = (try? JSONDecoder().decode(VMConfiguration.self, from: request.body)) ?? VMConfiguration.example()
            let vm = try? await manager.createVM(configuration: configuration)
            return .json(status: .created, data: VMItemResponse(vm: vm ?? VMInstance(configuration: configuration)))
        case ("GET", let path) where path.hasPrefix("/vms/") && route.segments.count == 2:
            let vm = await manager.ensureVM(id: route.identifier)
            return .json(data: VMItemResponse(vm: vm))
        case ("PUT", let path) where path.hasPrefix("/vms/") && route.segments.count == 2:
            let configuration = (try? JSONDecoder().decode(VMConfiguration.self, from: request.body)) ?? VMConfiguration.placeholder(id: route.identifier)
            let vm = try? await manager.updateVM(id: route.identifier, configuration: configuration)
            return .json(data: VMItemResponse(vm: vm ?? VMInstance(configuration: configuration)))
        case ("POST", let path) where path.hasPrefix("/vms/") && route.segments.count == 3:
            return await handleVMAction(path: route.path, action: route.segments[2])
        case ("DELETE", let path) where path.hasPrefix("/vms/") && route.segments.count == 2:
            _ = try? await manager.deleteVM(id: route.identifier)
            return .json(data: ActionResponse(action: "delete", uuid: route.identifier.uuidString, state: "deleted"))
        case ("GET", "/images"):
            return .json(data: ImageCollectionResponse(images: [DiskImage.example()]))
        case ("POST", "/images"):
            let importRequest = (try? JSONDecoder().decode(ImageImportRequest.self, from: request.body)) ?? ImageImportRequest(path: "/tmp/imported.img")
            return .json(status: .created, data: ImageItemResponse(image: DiskImage(name: importRequest.name ?? "imported-image", path: importRequest.path)))
        default:
            return .json(status: .notFound, data: ErrorResponse(message: "Route not found"), error: "Route not found")
        }
    }

    private func handleVMAction(path: String, action: String) async -> HTTPResponse {
        let identifier = normalizedPath(from: path).identifier

        switch action {
        case "start":
            let vm = try? await manager.startVM(id: identifier)
            return .json(data: ActionResponse(action: action, uuid: identifier.uuidString, state: vm?.state.rawValue ?? VMState.running.rawValue))
        case "stop":
            let vm = try? await manager.stopVM(id: identifier)
            return .json(data: ActionResponse(action: action, uuid: identifier.uuidString, state: vm?.state.rawValue ?? VMState.stopped.rawValue))
        case "force-stop":
            let vm = try? await manager.forceStopVM(id: identifier)
            return .json(data: ActionResponse(action: action, uuid: identifier.uuidString, state: vm?.state.rawValue ?? VMState.stopped.rawValue))
        case "pause":
            let vm = try? await manager.pauseVM(id: identifier)
            return .json(data: ActionResponse(action: action, uuid: identifier.uuidString, state: vm?.state.rawValue ?? VMState.paused.rawValue))
        case "resume":
            let vm = try? await manager.resumeVM(id: identifier)
            return .json(data: ActionResponse(action: action, uuid: identifier.uuidString, state: vm?.state.rawValue ?? VMState.running.rawValue))
        default:
            return .json(status: .notFound, data: ErrorResponse(message: "Unknown VM action"), error: "Unknown VM action")
        }
    }

    private func normalizedPath(from path: String) -> RouteMatch {
        let trimmedPath: String
        if path.hasPrefix("/api/v1") {
            trimmedPath = String(path.dropFirst("/api/v1".count))
        } else {
            trimmedPath = path
        }

        let normalized = trimmedPath.isEmpty ? "/" : trimmedPath
        let segments = normalized.split(separator: "/").map(String.init)
        let identifier = segments.count >= 2 ? UUID(uuidString: segments[1]) ?? UUID() : UUID()

        return RouteMatch(path: normalized, segments: segments, identifier: identifier)
    }
}

private struct RouteMatch: Sendable {
    let path: String
    let segments: [String]
    let identifier: UUID
}

private struct VMCollectionResponse: Encodable {
    let vms: [VMInstance]
}

private struct VMItemResponse: Encodable {
    let vm: VMInstance
}

private struct ActionResponse: Encodable {
    let action: String
    let uuid: String
    let state: String
}

private struct ImageCollectionResponse: Encodable {
    let images: [DiskImage]
}

private struct ImageItemResponse: Encodable {
    let image: DiskImage
}

private struct ImageImportRequest: Codable {
    let name: String?
    let path: String
}

private struct ErrorResponse: Encodable {
    let message: String
}