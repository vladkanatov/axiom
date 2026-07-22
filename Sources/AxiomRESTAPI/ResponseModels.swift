import Foundation
import Models

/// Standard API envelope returned by REST handlers.
public struct APIResponse<Payload: Encodable>: Encodable {
    public let success: Bool
    public let data: Payload?
    public let error: APIErrorPayload?

    public init(success: Bool, data: Payload?, error: APIErrorPayload?) {
        self.success = success
        self.data = data
        self.error = error
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(success, forKey: .success)
        if let data {
            try container.encode(data, forKey: .data)
        } else {
            try container.encodeNil(forKey: .data)
        }
        if let error {
            try container.encode(error, forKey: .error)
        } else {
            try container.encodeNil(forKey: .error)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case data
        case error
    }
}

/// Structured error payload returned in the API envelope.
public struct APIErrorPayload: Codable, Sendable, Equatable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

/// Item returned by `GET /vms`.
public struct VMListItem: Codable, Sendable, Equatable {
    public let uuid: String
    public let name: String
    public let state: String

    public init(uuid: String, name: String, state: String) {
        self.uuid = uuid
        self.name = name
        self.state = state
    }
}

/// Payload for the VM list endpoint.
public struct VMListPayload: Codable, Sendable, Equatable {
    public let vms: [VMListItem]

    public init(vms: [VMListItem]) {
        self.vms = vms
    }
}

/// Payload returned after VM creation.
public struct VMCreationPayload: Codable, Sendable, Equatable {
    public let uuid: String
    public let config: VMConfiguration

    public init(uuid: String, config: VMConfiguration) {
        self.uuid = uuid
        self.config = config
    }
}

/// Payload returned for VM details.
public struct VMDetailPayload: Codable, Sendable, Equatable {
    public let uuid: String
    public let config: VMConfiguration
    public let state: String
    public let uptime: Int?

    public init(uuid: String, config: VMConfiguration, state: String, uptime: Int? = nil) {
        self.uuid = uuid
        self.config = config
        self.state = state
        self.uptime = uptime
    }
}

/// Generic action response for state-changing routes.
public struct VMActionPayload: Codable, Sendable, Equatable {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

/// Payload used for image endpoints.
public struct ImageCollectionPayload: Codable, Sendable, Equatable {
    public let images: [DiskImage]

    public init(images: [DiskImage]) {
        self.images = images
    }
}

/// Payload used for a single image response.
public struct ImageItemPayload: Codable, Sendable, Equatable {
    public let image: DiskImage

    public init(image: DiskImage) {
        self.image = image
    }
}
