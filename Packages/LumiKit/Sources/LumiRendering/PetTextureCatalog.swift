import Foundation
import SpriteKit
import LumiCore

public enum PetTextureCatalogError: Error, Equatable {
    case missingEssential(Set<String>)
}

/// Validates that a texture source provides the essential textures and exposes
/// a fallback-aware lookup. Non-essential missing textures are tolerated (a
/// missing required part uses its fallback) and reported for diagnostics.
public struct PetTextureCatalog {
    /// All 56 texture names, built from the LumiCore enum raw values plus the
    /// fixed part/fallback names. Must equal the layout's texture keys.
    public static let requiredTextureNames: [String] = {
        var names: [String] = []

        // Bodies (one per BodyShape).
        for shape in BodyShape.allCases { names.append("body_\(shape.rawValue)") }
        names.append("abdomen_soft")
        names.append("paws_round")

        // Head + fur variants.
        names.append("head_base")
        for fur in FurStyle.allCases { names.append("fur_\(fur.rawValue)") }

        // Patterns (every PatternStyle except `none`).
        for pattern in PatternStyle.allCases where pattern != .none {
            names.append("pattern_\(pattern.rawValue)")
        }

        // Eye components.
        names.append("eyelid")
        names.append("iris_base")

        // Ears.
        for ear in EarStyle.allCases { names.append("ear_\(ear.rawValue)") }

        // Tails.
        for tail in TailStyle.allCases { names.append("tail_\(tail.rawValue)") }

        // Head tufts (every HeadTuftStyle except `none`).
        for tuft in HeadTuftStyle.allCases where tuft != .none {
            names.append("headtuft_\(tuft.rawValue)")
        }

        // Chest tufts (every ChestTuftStyle except `none`).
        for tuft in ChestTuftStyle.allCases where tuft != .none {
            names.append("chesttuft_\(tuft.rawValue)")
        }

        // Muzzles.
        for muzzle in MuzzleStyle.allCases { names.append("muzzle_\(muzzle.rawValue)") }

        // Noses.
        for nose in NoseStyle.allCases { names.append("nose_\(nose.rawValue)") }

        // Cheeks (every CheekStyle except `none`).
        for cheek in CheekStyle.allCases where cheek != .none {
            names.append("cheek_\(cheek.rawValue)")
        }

        // Magic (every MagicalFeature except `none`; orbitingLight → magic_orbiting_light).
        for feature in MagicalFeature.allCases where feature != .none {
            names.append(PetTextureCatalog.magicTextureName(for: feature))
        }

        // Fallbacks.
        names.append(contentsOf: [
            "fallback_body", "fallback_head", "fallback_ear",
            "fallback_tail", "fallback_paws", "fallback_eye"
        ])

        // Eyes.
        for eye in EyeShape.allCases { names.append("eye_\(eye.rawValue)") }

        // Pupils.
        for pupil in PupilStyle.allCases { names.append("pupil_\(pupil.rawValue)") }

        // Miscellaneous pre-colored parts.
        names.append("eye_catchlight")
        names.append("shadow_diffuse")

        return names
    }()

    public static let essentialTextureNames: Set<String> = [
        "fallback_body", "fallback_head", "fallback_eye", "fallback_ear",
        "fallback_tail", "fallback_paws", "shadow_diffuse", "iris_base",
        "pupil_round", "eye_catchlight"
    ]

    /// Maps a magical feature to its texture name (`orbitingLight` uses the
    /// snake-cased `magic_orbiting_light`).
    public static func magicTextureName(for feature: MagicalFeature) -> String {
        switch feature {
        case .none: return "magic_glow" // never used; `none` has no node.
        case .glow: return "magic_glow"
        case .sparkles: return "magic_sparkles"
        case .orbitingLight: return "magic_orbiting_light"
        }
    }

    private let availableNames: Set<String>
    private let textureLoader: (String) -> SKTexture

    /// Names in `requiredTextureNames` that are absent from the source.
    public let missingTextureNames: Set<String>

    public init(atlas: SKTextureAtlas) throws {
        // Strip `.png`/`@2x` suffixes SpriteKit may attach to atlas entries.
        let stripped = Set(atlas.textureNames.map { PetTextureCatalog.normalize($0) })
        try self.init(
            availableNames: stripped,
            textureLoader: { name in atlas.textureNamed(name) }
        )
    }

    init(availableNames: Set<String>, textureLoader: @escaping (String) -> SKTexture) throws {
        self.availableNames = availableNames
        self.textureLoader = textureLoader

        let missingEssential = PetTextureCatalog.essentialTextureNames.subtracting(availableNames)
        guard missingEssential.isEmpty else {
            throw PetTextureCatalogError.missingEssential(missingEssential)
        }

        self.missingTextureNames = Set(PetTextureCatalog.requiredTextureNames)
            .subtracting(availableNames)
    }

    private static func normalize(_ name: String) -> String {
        var result = name
        if result.hasSuffix(".png") { result.removeLast(4) }
        if result.hasSuffix("@2x") { result.removeLast(3) }
        if result.hasSuffix("@3x") { result.removeLast(3) }
        return result
    }

    public func contains(_ name: String) -> Bool {
        availableNames.contains(name)
    }

    /// Returns the texture for `named` if available, otherwise the `fallback`.
    public func texture(named: String, fallback: String) -> SKTexture {
        if availableNames.contains(named) {
            return textureLoader(named)
        }
        return textureLoader(fallback)
    }
}
