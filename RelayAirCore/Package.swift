// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RelayAirCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "RelayAirCore", targets: ["RelayAirCore"])
    ],
    targets: [
        // Swift 5 language mode to match the app targets.
        .target(name: "RelayAirCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .testTarget(
            name: "RelayAirCoreTests",
            dependencies: ["RelayAirCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
