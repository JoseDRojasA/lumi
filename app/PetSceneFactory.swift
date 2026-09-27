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
    case missingKittenLayout

    var errorDescription: String? {
        switch self {
        case .missingRigLayout:
            return "The Lumi rig layout (RigAnchors.json) is missing from the app bundle."
        case .missingKittenLayout:
            return "The kitten rig layout (KittenRig.json) is missing from the app bundle."
        }
    }
}

/// Which art the pet is drawn with.
enum PetAppearance: Equatable {
    /// The procedural, randomly generated Lumi.
    case generated
    /// The hand-painted pastel kitten (`LumiKitten` atlas + `KittenRig.json`).
    case kitten
}

enum PetSceneFactory {
    /// Cached resources so multiple windows/scenes don't reload the atlas.
    private static var cached: (catalog: PetTextureCatalog, layout: PetRigLayout)?
    private static var cachedKitten: (atlas: SKTextureAtlas, layout: KittenRigLayout)?

    /// Builds a scene for `pet` drawn with `appearance`.
    static func makeScene(
        for pet: Pet,
        appearance: PetAppearance,
        policy: PetRenderPolicy,
        reduceMotion: Bool,
        bundle: Bundle = .main
    ) throws -> PetScene {
        switch appearance {
        case .generated:
            return try makeScene(for: pet, policy: policy, reduceMotion: reduceMotion, bundle: bundle)
        case .kitten:
            return try makeKittenScene(for: pet, policy: policy, reduceMotion: reduceMotion, bundle: bundle)
        }
    }

    /// Builds a scene showing the hand-painted kitten. The pet's configuration
    /// still drives motion (personality, seed) and the accessibility label.
    static func makeKittenScene(
        for pet: Pet,
        policy: PetRenderPolicy,
        reduceMotion: Bool,
        bundle: Bundle = .main
    ) throws -> PetScene {
        let resources: (atlas: SKTextureAtlas, layout: KittenRigLayout)
        if let cachedKitten {
            resources = cachedKitten
        } else {
            guard let url = bundle.url(forResource: "KittenRig", withExtension: "json") else {
                throw PetSceneFactoryError.missingKittenLayout
            }
            let layout = try KittenRigLayout.decode(Data(contentsOf: url))
            resources = (SKTextureAtlas(named: "LumiKitten"), layout)
            cachedKitten = resources
        }

        let presentation = PetPresentation(configuration: pet.configuration)
        let rig = try KittenNodeFactory(layout: resources.layout, atlas: resources.atlas)
            .makeRig(presentation: presentation)
        return PetScene(rig: rig, presentation: presentation, policy: policy, reduceMotion: reduceMotion)
    }

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
