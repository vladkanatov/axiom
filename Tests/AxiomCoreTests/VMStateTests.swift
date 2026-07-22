import XCTest
@testable import AxiomCore

final class VMStateTests: XCTestCase {
    func testVMStateCodableRoundTrip() throws {
        let original = VMState.running
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VMState.self, from: data)
        XCTAssertEqual(original, decoded)
    }
}