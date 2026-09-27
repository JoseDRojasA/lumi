import Foundation
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

@MainActor
struct PetTextureCatalogTests {
    @Test func missingEssentialThrows() throws {
        let available = Set(PetTextureCatalog.requiredTextureNames).subtracting(["fallback_eye"])
        #expect {
            _ = try PetTextureCatalog(
                availableNames: available,
                textureLoader: { _ in RenderingFixtures.solidTexture() }
            )
        } throws: { error in
            guard case let PetTextureCatalogError.missingEssential(names) = error else { return false }
            return names.contains("fallback_eye")
        }
    }

    @Test func missingNonEssentialSucceedsAndReports() throws {
        let catalog = try RenderingFixtures.testCatalog(missing: ["tail_plume"])
        #expect(catalog.missingTextureNames.contains("tail_plume"))
        #expect(catalog.contains("tail_plume") == false)
    }

    @Test func missingTextureFallsBackViaLoader() throws {
        // Record which names the loader is asked for.
        final class Recorder: @unchecked Sendable { var requested: [String] = [] }
        let recorder = Recorder()
        let available = Set(PetTextureCatalog.requiredTextureNames).subtracting(["tail_plume"])
        let catalog = try PetTextureCatalog(
            availableNames: available,
            textureLoader: { name in
                recorder.requested.append(name)
                return RenderingFixtures.solidTexture()
            }
        )
        _ = catalog.texture(named: "tail_plume", fallback: "fallback_tail")
        // The missing texture must not have been loaded; the fallback must.
        #expect(recorder.requested.contains("fallback_tail"))
        #expect(recorder.requested.contains("tail_plume") == false)
    }
}
