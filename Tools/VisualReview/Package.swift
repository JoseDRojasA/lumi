// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LumiVisualReview",
    platforms: [
        .macOS(.v15)
    ],
    dependencies: [
        .package(path: "../../Packages/LumiKit")
    ],
    targets: [
        .executableTarget(
            name: "LumiVisualReview",
            dependencies: [
                .product(name: "LumiCore", package: "LumiKit"),
                .product(name: "LumiRendering", package: "LumiKit")
            ]
        )
    ]
)
