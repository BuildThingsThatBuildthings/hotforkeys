// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HotForKeys",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "HotForKeys",
            path: "Sources"
        ),
        .testTarget(
            name: "HotForKeysTests",
            dependencies: ["HotForKeys"],
            path: "Tests"
        )
    ]
)
