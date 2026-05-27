// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CasprFlow",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CasprFlow", targets: ["CasprFlowApp"]),
        .executable(name: "CasprFlowChecks", targets: ["CasprFlowChecks"]),
        .library(name: "CasprFlowCore", targets: ["CasprFlowCore"])
    ],
    targets: [
        .executableTarget(
            name: "CasprFlowApp",
            dependencies: ["CasprFlowCore"]
        ),
        .executableTarget(
            name: "CasprFlowChecks",
            dependencies: ["CasprFlowCore"]
        ),
        .target(
            name: "CasprFlowCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Speech")
            ]
        )
    ]
)
