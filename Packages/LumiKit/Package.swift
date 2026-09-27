// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11)
    ],
    products: [
        .library(name: "LumiCore", targets: ["LumiCore"]),
        .library(name: "LumiPersistence", targets: ["LumiPersistence"]),
        .library(name: "LumiRendering", targets: ["LumiRendering"])
    ],
    targets: [
        .target(name: "LumiCore"),
        .target(name: "LumiPersistence", dependencies: ["LumiCore"]),
        .target(name: "LumiRendering", dependencies: ["LumiCore"]),
        .testTarget(name: "LumiCoreTests", dependencies: ["LumiCore"]),
        .testTarget(name: "LumiPersistenceTests", dependencies: ["LumiPersistence", "LumiCore"]),
        .testTarget(name: "LumiRenderingTests", dependencies: ["LumiRendering", "LumiCore"])
    ]
)
