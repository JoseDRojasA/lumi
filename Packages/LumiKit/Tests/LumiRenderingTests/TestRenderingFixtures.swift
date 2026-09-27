import Foundation
import SpriteKit
@testable import LumiCore
@testable import LumiRendering

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Shared fixtures for the LumiRendering test suite. These helpers never touch
/// disk for texture loading — they synthesize solid 4x4 textures so the tests
/// run deterministically on any host without an app bundle.
enum RenderingFixtures {
    /// Repo root derived from this file's path:
    /// `<root>/Packages/LumiKit/Tests/LumiRenderingTests/<file>` → up 4 levels.
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // LumiRenderingTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // LumiKit
            .deletingLastPathComponent() // Packages
            .deletingLastPathComponent() // repo root
    }

    /// The real RigAnchors.json shipped in the app target.
    static func realLayout() throws -> PetRigLayout {
        let url = repoRoot
            .appendingPathComponent("app")
            .appendingPathComponent("RigAnchors.json")
        let data = try Data(contentsOf: url)
        return try PetRigLayout.decode(data)
    }

    static let referenceSeeds: [UInt64] = [
        1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987,
        1597, 2584, 4181, 6765, 10946, 17711, 28657, 46368, 75025
    ]

    /// A 4x4 solid RGBA texture. Never touches disk.
    @MainActor
    static func solidTexture() -> SKTexture {
        let side = 4
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            bytes[i] = 255
            bytes[i + 1] = 255
            bytes[i + 2] = 255
            bytes[i + 3] = 255
        }
        let data = Data(bytes)
        return SKTexture(data: data, size: CGSize(width: side, height: side))
    }

    /// A catalog backed by synthesized textures, with `missing` names removed.
    @MainActor
    static func testCatalog(missing: Set<String> = []) throws -> PetTextureCatalog {
        let available = Set(PetTextureCatalog.requiredTextureNames).subtracting(missing)
        return try PetTextureCatalog(
            availableNames: available,
            textureLoader: { _ in solidTexture() }
        )
    }

    @MainActor
    static func testRig(seed: UInt64 = 101) throws -> PetRig {
        let layout = try realLayout()
        let catalog = try testCatalog()
        let configuration = try PetGenerator.generate(seed: seed, version: 1)
        let presentation = PetPresentation(configuration: configuration)
        let factory = PetNodeFactory(catalog: catalog, layout: layout)
        return try factory.makeRig(presentation: presentation)
    }
}
