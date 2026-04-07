// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacBright",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacBright",
            path: "Sources/MacBright"
        )
    ]
)
