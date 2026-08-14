// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkConsoleLite",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "NetworkCore", targets: ["NetworkCore"]),
        .executable(name: "NetworkConsoleApp", targets: ["NetworkConsoleApp"])
    ],
    targets: [
        .target(
            name: "NetworkCore",
            linkerSettings: [
                .linkedFramework("Network"),
                .linkedFramework("SystemConfiguration"),
                .linkedFramework("CoreWLAN")
            ]
        ),
        .executableTarget(
            name: "NetworkConsoleApp",
            dependencies: ["NetworkCore"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .testTarget(
            name: "NetworkCoreTests",
            dependencies: ["NetworkCore"]
        )
    ],
    swiftLanguageModes: [.v5]
)
