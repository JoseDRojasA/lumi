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
    case missingKittenLayout

    var errorDescription: String? {
        switch self {
        case .missingRigLayout:
            return "The Lumi rig layout (RigAnchors.json) is missing from the watch app bundle."
        case .missingKittenLayout:
            return "The kitten rig layout (KittenRig.json) is missing from the watch app bundle."
        }
    }
}

/// Which art the pet is drawn with. Mirrors the iOS `PetAppearance`.
enum WatchPetAppearance: Equatable {
    /// The procedural, randomly generated Lumi.
    case generated
    /// The hand-painted pastel kitten (`LumiKitten` atlas + `KittenRig.json`).
    case kitten
}

enum WatchPetSceneFactory {
    /// The name of the watch-specific texture atlas (0.5 px/pt).
    static let atlasName = "LumiPetWatch"

    /// Cached resources so multiple scenes don't reload the atlas.
    private static var cached: (catalog: PetTextureCatalog, layout: PetRigLayout)?
    private static var cachedKitten: (atlas: SKTextureAtlas, layout: KittenRigLayout)?

    /// Builds a watch scene for `pet` drawn with `appearance`.
    static func makeScene(
        for pet: Pet,
        appearance: WatchPetAppearance,
        reduceMotion: Bool,
        bundle: Bundle = .main
    ) throws -> PetScene {
        switch appearance {
        case .generated:
            return try makeScene(for: pet, reduceMotion: reduceMotion, bundle: bundle)
        case .kitten:
            return try makeKittenScene(for: pet, reduceMotion: reduceMotion, bundle: bundle)
        }
    }

    /// Builds a watch scene showing the hand-painted kitten.
    static func makeKittenScene(
        for pet: Pet,
        reduceMotion: Bool,
        bundle: Bundle = .main
    ) throws -> PetScene {
        let resources: (atlas: SKTextureAtlas, layout: KittenRigLayout)
        if let cachedKitten {
            resources = cachedKitten
        } else {
            guard let url = bundle.url(forResource: "KittenRig", withExtension: "json") else {
                throw WatchPetSceneFactoryError.missingKittenLayout
            }
            let layout = try KittenRigLayout.decode(Data(contentsOf: url))
            resources = (SKTextureAtlas(named: "LumiKitten"), layout)
            cachedKitten = resources
        }

        let presentation = PetPresentation(configuration: pet.configuration)
        let rig = try KittenNodeFactory(layout: resources.layout, atlas: resources.atlas)
            .makeRig(presentation: presentation)
        return PetScene(rig: rig, presentation: presentation, policy: .watch, reduceMotion: reduceMotion)
    }

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
