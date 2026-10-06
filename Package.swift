// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "WorkTimer",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "WorkTimerCore"),
        .executableTarget(name: "WorkTimer", dependencies: ["WorkTimerCore"]),
        .testTarget(name: "WorkTimerCoreTests", dependencies: ["WorkTimerCore"]),
    ]
)
