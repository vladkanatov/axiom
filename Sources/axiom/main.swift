import Foundation
import Dispatch
import AxiomRESTAPI

let port = Int(ProcessInfo.processInfo.environment["AXIOM_PORT"] ?? "8080") ?? 8080
let application = AxiomApplication(configuration: AxiomApplicationConfiguration(port: port))

do {
    let actualPort = try application.start()
    print("axiom listening on http://127.0.0.1:\(actualPort)/api/v1")
    dispatchMain()
} catch {
    fputs("Failed to start axiom: \(error)\n", stderr)
    exit(1)
}