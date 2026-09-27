//
//  WatchPetSceneFactory.swift
//  LumiWatch Watch App
//
//  Loads the bundled watch atlas + rig layout once and builds PetScenes with
//  the watch render policy. Mirrors the iOS PetSceneFactory.
//

import Foundation
import SpriteKit
import LumiCore
import LumiRendering

enum WatchPetSceneFactoryError: LocalizedError {
    case missingRigLayout

    var errorDescription: String? {
        switch self {
        case .missingRigLayout:
            return "The Lumi rig layout (RigAnchors.json) is missing from the watch app bundle."
        }
    }
}

enum WatchPetSceneFactory {
    /// The name of the watch-specific texture atlas (0.5 px/pt).
    static let atlasName = "LumiPetWatch"

    /// Cached resources so multiple scenes don't reload the atlas.
    private static var cached: (catalog: PetTextureCatalog, layout: PetRigLayout)?

    /// Loads the texture catalog and rig layout from the given bundle.
    /// Throws a descriptive error if the rig layout is missing.
    static func loadResources(bundle: Bundle) throws -> (PetTextureCatalog, PetRigLayout) {
        let atlas = SKTextureAtlas(named: atlasName)
        let catalog = try PetTextureCatalog(atlas: atlas)

        guard let url = bundle.url(forResource: "RigAnchors", withExtension: "json") else {
            throw WatchPetSceneFactoryError.missingRigLayout
        }
        let data = try Data(contentsOf: url)
        let layout = try PetRigLayout.decode(data)
        return (catalog, layout)
    }

    /// Builds a watch PetScene for `pet`, loading (and caching) resources from `bundle`.
    static func makeScene(
        for pet: Pet,
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
            policy: .watch,
            reduceMotion: reduceMotion
        )
    }
}
