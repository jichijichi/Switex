// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "switex",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "switex",
            path: "Sources"
        ),
    ]
)
