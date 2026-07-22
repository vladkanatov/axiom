import Foundation
import Dispatch
import AxiomCore
import AxiomRESTAPI
import AxiomVirtualization

let port = Int(ProcessInfo.processInfo.environment["AXIOM_PORT"] ?? "8889") ?? 8889
let provider: any VirtualizationProvider
if #available(macOS 13.0, *) {
    provider = VZProvider()
} else {
    provider = NoopVirtualizationProvider()
}

let manager = VMManager(provider: provider)
let application = AxiomApplication(
    configuration: AxiomApplicationConfiguration(port: port),
    manager: manager
)

do {
    let actualPort = try application.start()
    print("axiom listening on http://127.0.0.1:\(actualPort)/api/v1")
    dispatchMain()
} catch {
    fputs("Failed to start axiom: \(error)\n", stderr)
    exit(1)
}