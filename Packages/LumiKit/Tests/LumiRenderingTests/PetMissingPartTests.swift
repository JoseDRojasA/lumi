import Foundation
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

@MainActor
struct PetMissingPartTests {
    /// With `tail_plume` missing from the catalog and a plume-tail configuration,
    /// the rig still builds and the tail sprite uses the fallback_tail texture.
    @Test func plumeTailUsesFallbackWhenMissing() throws {
        final class Recorder: @unchecked Sendable { var requested: [String] = [] }
        let recorder = Recorder()
        let layout = try RenderingFixtures.realLayout()
        let available = Set(PetTextureCatalog.requiredTextureNames).subtracting(["tail_plume"])
        let catalog = try PetTextureCatalog(
            availableNames: available,
            textureLoader: { name in
                recorder.requested.append(name)
                return RenderingFixtures.solidTexture()
            }
        )

        // Find a seed whose tail style is plume.
        var config = try PetGenerator.generate(seed: 1, version: 1)
        var found = false
        for seed in UInt64(1)...2000 {
            let candidate = try PetGenerator.generate(seed: seed, version: 1)
            if candidate.tail.tailStyle == .plume {
                config = candidate
                found = true
                break
            }
        }
        #expect(found, "no plume-tail seed found in range")

        let presentation = PetPresentation(configuration: config)
        let factory = PetNodeFactory(catalog: catalog, layout: layout)
        let rig = try factory.makeRig(presentation: presentation)

        // Tail node still exists (it is a required node).
        #expect(rig.tail.name == "pet.tail")
        // The fallback texture must have been requested, not tail_plume.
        #expect(recorder.requested.contains("fallback_tail"))
        #expect(recorder.requested.contains("tail_plume") == false)
    }
}
