// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "axiom",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "AxiomCore", targets: ["AxiomCore"]),
        .library(name: "AxiomVirtualization", targets: ["AxiomVirtualization"]),
        .library(name: "AxiomRESTAPI", targets: ["AxiomRESTAPI"]),
        .executable(name: "axiom", targets: ["axiom"])
    ],
    targets: [
        .target(name: "AxiomCore"),
        .target(name: "AxiomVirtualization", dependencies: ["AxiomCore"]),
        .target(name: "AxiomRESTAPI", dependencies: ["AxiomCore", "AxiomVirtualization"]),
        .executableTarget(name: "axiom", dependencies: ["AxiomRESTAPI"]),
        .testTarget(name: "AxiomCoreTests", dependencies: ["AxiomCore"]),
        .testTarget(name: "AxiomIntegrationTests", dependencies: ["AxiomRESTAPI"])
    ]
)