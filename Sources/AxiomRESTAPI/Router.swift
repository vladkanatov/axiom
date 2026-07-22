import Foundation
import os
import AxiomCore

/// Router that translates HTTP requests into `VMManager` operations.
public final class Router: @unchecked Sendable {
    public let vmm: VMManager

    private let logger = Logger(subsystem: "com.axiom", category: "RESTAPI.Router")
    private var handlersRegistered = false

    public init(vmm: VMManager) {
        self.vmm = vmm
        registerHandlers()
    }

    /// Registers route handlers. The current implementation keeps dispatch in code,
    /// but the method exists so tests can verify the router is configured explicitly.
    public func registerHandlers() {
        handlersRegistered = true
    }

    public func handle(request: HTTPRequest) async -> HTTPResponse {
        if !handlersRegistered {
            registerHandlers()
        }

        let route = normalizedRoute(from: request.path)
        logger.info("Incoming request: \(request.method, privacy: .public) \(route.path, privacy: .public)")

        let response: HTTPResponse
        do {
            response = try await dispatch(request: request, route: route)
            logger.info("Request succeeded: \(request.method, privacy: .public) \(route.path, privacy: .public)")
        } catch {
            logger.error("Request failed: \(request.method, privacy: .public) \(route.path, privacy: .public) - \(error.localizedDescription, privacy: .public)")
            response = apiErrorResponse(for: error)
        }

        return response
    }

    private func dispatch(request: HTTPRequest, route: RouteMatch) async throws -> HTTPResponse {
        let method = request.method.uppercased()

        if method == "GET" && route.segments.count == 1 && route.segments[0] == "vms" {
            return try await listVMs()
        }

        if method == "POST" && route.segments.count == 1 && route.segments[0] == "vms" {
            return try await createVM(request: request)
        }

        if method == "GET", route.segments.count == 2, route.segments[0] == "vms" {
            return try await getVM(uuidString: route.segments[1])
        }

        if method == "PUT", route.segments.count == 2, route.segments[0] == "vms" {
            return try await updateVM(uuidString: route.segments[1], request: request)
        }

        if method == "POST", route.segments.count == 3, route.segments[0] == "vms" {
            return try await performAction(uuidString: route.segments[1], action: route.segments[2])
        }

        if method == "DELETE", route.segments.count == 2, route.segments[0] == "vms" {
            return try await deleteVM(uuidString: route.segments[1])
        }

        if method == "POST", route.segments.count == 3, route.segments[0] == "vms", route.segments[2] == "disks" {
            return try await attachDisk(uuidString: route.segments[1], request: request)
        }

        if method == "GET" && route.segments.count == 1 && route.segments[0] == "images" {
            let images = try await vmm.listDiskImages()
            return makeAPIResponse(data: ImageCollectionPayload(images: images))
        }

        if method == "POST" && route.segments.count == 1 && route.segments[0] == "images" {
            return try await importImage(request: request)
        }

        return makeAPIErrorResponse(status: .notFound, code: "ROUTE_NOT_FOUND", message: "Route not found")
    }

    private func listVMs() async throws -> HTTPResponse {
        let vms = await vmm.listVMs().map {
            VMListItem(uuid: $0.id.uuidString, name: $0.configuration.name, state: $0.state.rawValue)
        }

        return makeAPIResponse(data: VMListPayload(vms: vms))
    }

    private func createVM(request: HTTPRequest) async throws -> HTTPResponse {
        let configuration = try decodeConfiguration(from: request.body)
        let uuid = try await vmm.createVM(config: configuration, uuid: configuration.id.uuidString)
        let createdConfiguration = VMConfiguration(
            id: UUID(uuidString: uuid) ?? configuration.id,
            name: configuration.name,
            cpuCount: configuration.cpuCount,
            memorySizeMiB: configuration.memorySizeMiB,
            diskImages: configuration.diskImages,
            network: configuration.network,
            bootLoader: configuration.bootLoader,
            console: configuration.console
        )

        return makeAPIResponse(status: .created, data: VMCreationPayload(uuid: uuid, config: createdConfiguration))
    }

    private func getVM(uuidString: String) async throws -> HTTPResponse {
        let uuid = try parseUUID(uuidString)
        guard let configuration = try await vmm.getVMConfig(uuid: uuid.uuidString) else {
            throw AxiomError.vmNotFound(uuid)
        }

        let state = try await vmm.getVMState(uuid: uuid.uuidString)
        return makeAPIResponse(data: VMDetailPayload(uuid: uuid.uuidString, config: configuration, state: state.rawValue))
    }

    private func updateVM(uuidString: String, request: HTTPRequest) async throws -> HTTPResponse {
        let uuid = try parseUUID(uuidString)
        let state = try await vmm.getVMState(uuid: uuid.uuidString)
        guard state == .stopped else {
            throw HTTPAPIError(status: .conflict, code: "VM_STATE_CONFLICT", message: "VM must be stopped before updating the configuration.")
        }

        let configuration = try decodeConfiguration(from: request.body)
        guard let updatedConfiguration = try await vmm.updateVMConfig(uuid: uuid.uuidString, config: configuration) else {
            throw AxiomError.vmNotFound(uuid)
        }

        return makeAPIResponse(data: VMDetailPayload(uuid: uuid.uuidString, config: updatedConfiguration, state: state.rawValue))
    }

    private func performAction(uuidString: String, action: String) async throws -> HTTPResponse {
        let uuid = try parseUUID(uuidString)
        let currentState = try await vmm.getVMState(uuid: uuid.uuidString)

        switch action {
        case "start":
            guard currentState != .running else {
                throw HTTPAPIError(status: .conflict, code: "VM_ALREADY_RUNNING", message: "VM is already running.")
            }
            try await vmm.startVM(uuid: uuid.uuidString)
            return makeAPIResponse(data: VMActionPayload(message: "VM started"))
        case "stop":
            guard currentState != .stopped else {
                throw HTTPAPIError(status: .conflict, code: "VM_ALREADY_STOPPED", message: "VM is already stopped.")
            }
            try await vmm.stopVM(uuid: uuid.uuidString, graceful: true)
            return makeAPIResponse(data: VMActionPayload(message: "VM stopped"))
        case "force-stop":
            guard currentState != .stopped else {
                throw HTTPAPIError(status: .conflict, code: "VM_ALREADY_STOPPED", message: "VM is already stopped.")
            }
            try await vmm.stopVM(uuid: uuid.uuidString, graceful: false)
            return makeAPIResponse(data: VMActionPayload(message: "VM force-stopped"))
        case "pause":
            guard currentState == .running else {
                throw HTTPAPIError(status: .conflict, code: "VM_STATE_CONFLICT", message: "VM must be running before it can be paused.")
            }
            try await vmm.pauseVM(uuid: uuid.uuidString)
            return makeAPIResponse(data: VMActionPayload(message: "VM paused"))
        case "resume":
            guard currentState == .paused else {
                throw HTTPAPIError(status: .conflict, code: "VM_STATE_CONFLICT", message: "VM must be paused before it can be resumed.")
            }
            try await vmm.resumeVM(uuid: uuid.uuidString)
            return makeAPIResponse(data: VMActionPayload(message: "VM resumed"))
        default:
            throw HTTPAPIError(status: .notFound, code: "VM_ACTION_NOT_FOUND", message: "Unknown VM action")
        }
    }

    private func deleteVM(uuidString: String) async throws -> HTTPResponse {
        let uuid = try parseUUID(uuidString)
        try await vmm.deleteVM(uuid: uuid.uuidString)
        return makeAPIResponse(data: VMActionPayload(message: "VM deleted"))
    }

    private func importImage(request: HTTPRequest) async throws -> HTTPResponse {
        let mutation = try JSONDecoder().decode(DiskImageMutationRequest.self, from: request.body)

        if let source = mutation.source {
            let image = try await vmm.importDiskImage(from: source, name: mutation.name)
            return makeAPIResponse(status: .created, data: ImageItemPayload(image: image))
        }

        guard let sizeMiB = mutation.sizeMiB else {
            throw HTTPAPIError(status: .badRequest, code: "INVALID_CONFIGURATION", message: "Either 'source' or 'sizeMiB' must be provided for image creation.")
        }

        let image = try await vmm.createEmptyDiskImage(name: mutation.name ?? "disk-image", sizeMiB: sizeMiB)
        return makeAPIResponse(status: .created, data: ImageItemPayload(image: image))
    }

    private func attachDisk(uuidString: String, request: HTTPRequest) async throws -> HTTPResponse {
        let uuid = try parseUUID(uuidString)
        let attachRequest = try JSONDecoder().decode(DiskImageAttachRequest.self, from: request.body)
        guard let configuration = try await vmm.attachDiskImage(uuid: uuid.uuidString, imagePath: attachRequest.path) else {
            throw AxiomError.vmNotFound(uuid)
        }

        let state = try await vmm.getVMState(uuid: uuid.uuidString)
        return makeAPIResponse(data: VMDetailPayload(uuid: uuid.uuidString, config: configuration, state: state.rawValue))
    }

    private func decodeConfiguration(from data: Data) throws -> VMConfiguration {
        do {
            return try JSONDecoder().decode(VMConfiguration.self, from: data)
        } catch {
            throw AxiomError.invalidConfiguration("The request body must be valid VMConfiguration JSON.")
        }
    }

    private func parseUUID(_ string: String) throws -> UUID {
        guard let uuid = UUID(uuidString: string) else {
            throw AxiomError.invalidConfiguration("Invalid UUID: \(string)")
        }
        return uuid
    }

    private func normalizedRoute(from path: String) -> RouteMatch {
        let trimmedPath: String
        if path.hasPrefix("/api/v1") {
            trimmedPath = String(path.dropFirst("/api/v1".count))
        } else {
            trimmedPath = path
        }

        let normalized = trimmedPath.isEmpty ? "/" : trimmedPath
        let segments = normalized.split(separator: "/").map(String.init)
        return RouteMatch(path: normalized, segments: segments)
    }
}

private struct RouteMatch: Sendable {
    let path: String
    let segments: [String]
}

