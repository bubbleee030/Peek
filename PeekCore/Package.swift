// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PeekCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PeekCore", targets: ["PeekCore"]),
    ],
    targets: [
        .systemLibrary(name: "CLibArchive", path: "Sources/CLibArchive"),
        .target(name: "PeekCore", dependencies: ["CLibArchive"]),
        .testTarget(name: "PeekCoreTests", dependencies: ["PeekCore"]),
    ]
)
