// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pawmodoro",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PawmodoroKit"),
        .testTarget(
            name: "PawmodoroKitTests",
            dependencies: ["PawmodoroKit"]
        ),
        .executableTarget(
            name: "Pawmodoro",
            dependencies: ["PawmodoroKit"]
        ),
    ]
)
