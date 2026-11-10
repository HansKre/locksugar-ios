// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LockSugarCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "LockSugarCore",
            targets: ["LockSugarCore"]
        ),
    ],
    targets: [
        .target(
            name: "LockSugarCore",
            path: "Shared"
        ),
        .executableTarget(
            name: "TestRunner",
            dependencies: ["LockSugarCore"],
            path: "Tests"
        ),
    ]
)
