import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import AxiomRESTAPI

final class HTTPServerIntegrationTests: XCTestCase {
    func testHealthLikeListVMsEndpointRespondsWithJSON() async throws {
        let application = AxiomApplication(configuration: AxiomApplicationConfiguration(port: 0))
        let port = try application.start()
        defer { application.stop() }

        let url = URL(string: "http://127.0.0.1:\(port)/api/v1/vms")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)

        XCTAssertEqual(httpResponse.statusCode, 200)

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["success"] as? Bool, true)
    }
}