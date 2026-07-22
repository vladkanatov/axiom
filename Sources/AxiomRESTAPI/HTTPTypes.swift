import Foundation

public enum HTTPStatus: Int, Sendable {
    case ok = 200
    case created = 201
    case accepted = 202
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case conflict = 409
    case notFound = 404
    case methodNotAllowed = 405
    case internalServerError = 500

    public var reasonPhrase: String {
        switch self {
        case .ok: return "OK"
        case .created: return "Created"
        case .accepted: return "Accepted"
        case .badRequest: return "Bad Request"
        case .unauthorized: return "Unauthorized"
        case .forbidden: return "Forbidden"
        case .conflict: return "Conflict"
        case .notFound: return "Not Found"
        case .methodNotAllowed: return "Method Not Allowed"
        case .internalServerError: return "Internal Server Error"
        }
    }

    public var isSuccess: Bool {
        (200..<300).contains(rawValue)
    }
}

public struct HTTPRequest: Sendable {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: Data

    public init(method: String, path: String, headers: [String: String] = [:], body: Data = Data()) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
    }

    public static func parse(_ raw: Data) -> HTTPRequest? {
        guard let text = String(data: raw, encoding: .utf8) else {
            return nil
        }

        let sections = text.components(separatedBy: "\r\n\r\n")
        let headerText = sections.first ?? text
        let bodyText = sections.dropFirst().joined(separator: "\r\n\r\n")
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            return nil
        }

        let components = requestLine.split(separator: " ")
        guard components.count >= 2 else {
            return nil
        }

        let method = String(components[0]).uppercased()
        let rawPath = String(components[1])
        let path = rawPath.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? rawPath

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let separatorIndex = line.firstIndex(of: ":") else {
                continue
            }

            let name = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = line[line.index(after: separatorIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headers[name] = value
        }

        return HTTPRequest(method: method, path: path, headers: headers, body: Data(bodyText.utf8))
    }
}

public struct HTTPResponse: Sendable {
    public var status: HTTPStatus
    public var headers: [String: String]
    public var body: Data

    public init(status: HTTPStatus, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = headers
        self.body = body
    }

    public static func json<T: Encodable>(status: HTTPStatus = .ok, data: T, error: String? = nil) -> HTTPResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let payload: Any
        if let encoded = try? encoder.encode(data), let decoded = try? JSONSerialization.jsonObject(with: encoded) {
            payload = decoded
        } else {
            payload = ["value": "unavailable"]
        }

        let envelope: [String: Any] = [
            "success": status.isSuccess,
            "data": payload,
            "error": error ?? NSNull()
        ]

        let body = (try? JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])) ?? Data("{\"success\":false,\"data\":null,\"error\":\"serialization failed\"}".utf8)
        return HTTPResponse(
            status: status,
            headers: ["Content-Type": "application/json; charset=utf-8"],
            body: body
        )
    }

    public func serialized() -> Data {
        var headers = headers
        headers["Content-Type"] = headers["Content-Type"] ?? "application/json; charset=utf-8"
        headers["Content-Length"] = String(body.count)
        headers["Connection"] = "close"

        var responseText = "HTTP/1.1 \(status.rawValue) \(status.reasonPhrase)\r\n"
        for (name, value) in headers {
            responseText += "\(name): \(value)\r\n"
        }
        responseText += "\r\n"

        var responseData = Data(responseText.utf8)
        responseData.append(body)
        return responseData
    }
}