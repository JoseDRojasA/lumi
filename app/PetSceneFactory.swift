//
//  PetSceneFactory.swift
//  app
//
//  Loads the bundled atlas + rig layout once and builds PetScenes for a pet.
//

import Foundation
import SpriteKit
import LumiCore
import LumiRendering

enum PetSceneFactoryError: LocalizedError {
    case missingRigLayout

    var errorDescription: String? {
        switch self {
        case .missingRigLayout:
            return "The Lumi rig layout (RigAnchors.json) is missing from the app bundle."
        }
    }
}

enum PetSceneFactory {
    /// Cached resources so multiple windows/scenes don't reload the atlas.
    private static var cached: (catalog: PetTextureCatalog, layout: PetRigLayout)?

    /// Loads the texture catalog and rig layout from the given bundle.
    /// Throws a descriptive error if the rig layout is missing.
    static func loadResources(bundle: Bundle) throws -> (PetTextureCatalog, PetRigLayout) {
        let atlas = SKTextureAtlas(named: "LumiPet")
        let catalog = try PetTextureCatalog(atlas: atlas)

        guard let url = bundle.url(forResource: "RigAnchors", withExtension: "json") else {
            throw PetSceneFactoryError.missingRigLayout
        }
        let data = try Data(contentsOf: url)
        let layout = try PetRigLayout.decode(data)
        return (catalog, layout)
    }

    /// Builds a PetScene for `pet`, loading (and caching) resources from `bundle`.
    static func makeScene(
        for pet: Pet,
        policy: PetRenderPolicy,
        reduceMotion: Bool,
        bundle: Bundle = .main
    ) throws -> PetScene {
        let resources: (catalog: PetTextureCatalog, layout: PetRigLayout)
        if let cached {
            resources = cached
        } else {
            let loaded = try loadResources(bundle: bundle)
            cached = (loaded.0, loaded.1)
            resources = (loaded.0, loaded.1)
        }

        let presentation = PetPresentation(configuration: pet.configuration)
        return try PetScene(
            presentation: presentation,
            catalog: resources.catalog,
            layout: resources.layout,
            policy: policy,
            reduceMotion: reduceMotion
        )
    }
}
