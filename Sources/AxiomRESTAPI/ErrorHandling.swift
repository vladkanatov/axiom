import Foundation
import AxiomCore

/// Internal REST error representation with HTTP metadata.
public struct HTTPAPIError: Error, Sendable, Equatable {
    public let status: HTTPStatus
    public let code: String
    public let message: String

    public init(status: HTTPStatus, code: String, message: String) {
        self.status = status
        self.code = code
        self.message = message
    }
}

/// Encodes an API envelope into a JSON HTTP response.
public func makeAPIResponse<Payload: Encodable>(status: HTTPStatus = .ok, data: Payload) -> HTTPResponse {
    makeAPIResponse(status: status, response: APIResponse(success: status.isSuccess, data: data, error: nil))
}

/// Encodes an API error envelope into a JSON HTTP response.
public func makeAPIErrorResponse(status: HTTPStatus, code: String, message: String) -> HTTPResponse {
    makeAPIResponse(status: status, response: APIResponse<EmptyResponse>(success: false, data: nil, error: APIErrorPayload(code: code, message: message)))
}

/// Converts a known application error into an HTTP response.
public func makeAPIResponse<Payload: Encodable>(status: HTTPStatus, response: APIResponse<Payload>) -> HTTPResponse {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]

    let body = (try? encoder.encode(response)) ?? Data("{\"success\":false,\"data\":null,\"error\":{\"code\":\"INTERNAL_ERROR\",\"message\":\"serialization failed\"}}".utf8)
    return HTTPResponse(
        status: status,
        headers: ["Content-Type": "application/json; charset=utf-8"],
        body: body
    )
}

/// Converts the shared domain error type into a REST response.
public extension AxiomError {
    func toHTTPError() -> HTTPResponse {
        switch self {
        case .vmNotFound(let identifier):
            return makeAPIErrorResponse(status: .notFound, code: "VM_NOT_FOUND", message: "VM \(identifier.uuidString) was not found.")
        case .invalidConfiguration(let reason):
            return makeAPIErrorResponse(status: .badRequest, code: "INVALID_CONFIGURATION", message: reason)
        case .persistenceFailed(let reason):
            return makeAPIErrorResponse(status: .internalServerError, code: "PERSISTENCE_FAILED", message: reason)
        case .virtualizationUnavailable:
            return makeAPIErrorResponse(status: .internalServerError, code: "VIRTUALIZATION_UNAVAILABLE", message: "Virtualization is unavailable on this platform.")
        case .serverError(let reason):
            return makeAPIErrorResponse(status: .internalServerError, code: "INTERNAL_ERROR", message: reason)
        }
    }
}

/// Error payload placeholder used when no structured payload is needed.
public struct EmptyResponse: Codable, Sendable, Equatable {
    public init() {}
}

/// Maps any thrown error to a safe API response.
public func apiErrorResponse(for error: Error) -> HTTPResponse {
    if let apiError = error as? HTTPAPIError {
        return makeAPIErrorResponse(status: apiError.status, code: apiError.code, message: apiError.message)
    }

    if let axiomError = error as? AxiomError {
        return axiomError.toHTTPError()
    }

    return makeAPIErrorResponse(status: .internalServerError, code: "INTERNAL_ERROR", message: error.localizedDescription)
}
