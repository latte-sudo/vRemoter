// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "vRemote",
    defaultLocalization: "en",
    platforms: [.macOS(.v12)],
    targets: [
        .executableTarget(
            name: "vRemote",
            path: "Sources/vRemote",
            resources: [.process("Resources")],
            swiftSettings: [
                .define("DEBUG", .when(configuration: .debug))
            ]
        )
    ]
)
