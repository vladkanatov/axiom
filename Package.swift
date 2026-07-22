// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "axiom",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "Models", targets: ["Models"]),
        .library(name: "VMManager", targets: ["VMManager"]),
        .library(name: "AxiomCore", targets: ["AxiomCore"]),
        .library(name: "AxiomVirtualization", targets: ["AxiomVirtualization"]),
        .library(name: "AxiomRESTAPI", targets: ["AxiomRESTAPI"]),
        .executable(name: "axiom", targets: ["axiom"])
    ],
    targets: [
        .target(name: "Models", path: "Sources/Models"),
        .target(name: "VMManager", path: "Sources/VMManager"),
        .target(name: "AxiomVirtualization", dependencies: ["Models", "VMManager"], path: "Sources/Virtualization"),
        .target(name: "AxiomCore", dependencies: ["Models", "VMManager", "AxiomVirtualization"]),
        .target(name: "AxiomRESTAPI", dependencies: ["AxiomCore"]),
        .executableTarget(name: "axiom", dependencies: ["AxiomRESTAPI", "AxiomVirtualization"]),
        .testTarget(name: "AxiomCoreTests", dependencies: ["AxiomCore"]),
        .testTarget(name: "AxiomIntegrationTests", dependencies: ["AxiomRESTAPI"]),
        .testTarget(name: "UnitTests", dependencies: ["AxiomCore", "AxiomVirtualization"], path: "Tests/UnitTests")
    ]
)