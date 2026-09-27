import Testing
@testable import LumiCore
@testable import LumiRendering

struct LumiRenderingPackageSmokeTests {
    @Test func requiredTextureNamesCountIsFiftySix() {
        #expect(PetTextureCatalog.requiredTextureNames.count == 56)
    }

    @Test func accessibilityDescriptionReadsNaturally() throws {
        let config = try PetGenerator.generate(seed: 42, version: 1)
        let presentation = PetPresentation(configuration: config)
        #expect(presentation.accessibilityDescription.hasPrefix("A "))
        #expect(presentation.accessibilityDescription.contains("Lumi"))
    }
}
