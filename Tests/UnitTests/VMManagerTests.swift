import XCTest
@testable import AxiomCore

final class VMManagerTests: XCTestCase {
    func testCreateAndStartUsesProvider() async throws {
        let provider = MockVirtualizationProvider()
        let manager = VMManager(provider: provider)
        let configuration = VMConfiguration(name: "test-vm")

        let vm = try await manager.createVM(configuration: configuration)
        _ = try await manager.startVM(id: vm.id)

        XCTAssertEqual(provider.calls, [
            .createVM(uuid: vm.id.uuidString),
            .startVM(uuid: vm.id.uuidString)
        ])
    }
}
