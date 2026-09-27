import Foundation
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Builds an `SKTextureAtlas` from the real PNGs on disk (via a dictionary of
/// filename→image) and asserts the catalog validates with no missing textures.
/// This stands in for an app-hosted bundle test until the package is linked to
/// the app target in a later task.
@MainActor
struct PetTextureAtlasContractTests {
    private func makeAtlas(atlasDirectory: URL) throws -> SKTextureAtlas {
        let contents = try FileManager.default.contentsOfDirectory(
            at: atlasDirectory,
            includingPropertiesForKeys: nil
        )
        var dictionary: [String: Any] = [:]
        for url in contents where url.pathExtension.lowercased() == "png" {
            let key = url.deletingPathExtension().lastPathComponent
            let data = try Data(contentsOf: url)
            #if canImport(UIKit)
            guard let image = UIImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            dictionary[key] = image
            #elseif canImport(AppKit)
            guard let image = NSImage(data: data) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            dictionary[key] = image
            #endif
        }
        return SKTextureAtlas(dictionary: dictionary)
    }

    @Test func mainAppAtlasSatisfiesCatalog() throws {
        let dir = RenderingFixtures.repoRoot
            .appendingPathComponent("app")
            .appendingPathComponent("LumiPet.atlas")
        let atlas = try makeAtlas(atlasDirectory: dir)
        let catalog = try PetTextureCatalog(atlas: atlas)
        #expect(catalog.missingTextureNames.isEmpty)
    }

    @Test func watchAtlasSatisfiesCatalog() throws {
        let dir = RenderingFixtures.repoRoot
            .appendingPathComponent("LumiWatch Watch App")
            .appendingPathComponent("LumiPetWatch.atlas")
        let atlas = try makeAtlas(atlasDirectory: dir)
        let catalog = try PetTextureCatalog(atlas: atlas)
        #expect(catalog.missingTextureNames.isEmpty)
    }
}
