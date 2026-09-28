//
//  LumiPresets.swift
//  LumiCore
//
//  Hand-authored trait sets that reproduce specific reference characters,
//  bypassing the random generator.
//

import Foundation

public enum LumiPresets {
    /// The pastel lavender kitten from the character reference sheet:
    /// big head, big round amber eyes, pink pointed ears, a wild head tuft,
    /// a fluffy chest, blush cheeks and a big curled plume tail.
    ///
    /// Colors are chosen to pass `PetConfigurationValidator` unchanged
    /// (secondary/accent ≥ 0.28 and iris ≥ 0.34 RGB distance from the coat,
    /// nose ≥ 0.28 from the secondary), so the validator does not repaint them.
    public static let pastelKitten = PetConfiguration(
        formatVersion: 1,
        generatorVersion: PetGenerator.currentVersion,
        seed: 0x4C55_4D49_4B49_5454, // "LUMIKITT"; only identifies the preset
        body: BodyTraits(
            bodyShape: .round,
            bodyScale: 1.0,
            headScale: 1.15,          // chibi proportions: head at the max
            furStyle: .fluffy,
            patternStyle: .none,      // solid coat, no markings
            patternDensity: 0,
            patternScale: 1.0
        ),
        palette: Palette(
            // Pale lavender coat (#C5AAE0-ish). Brightness stays ≤ 0.90 so the
            // near-white secondary keeps enough contrast.
            baseColor: .hsb(hue: 0.75, saturation: 0.24, brightness: 0.88),
            // Near-white lavender for chest fluff and belly.
            secondaryColor: .hsb(hue: 0.78, saturation: 0.05, brightness: 1.0),
            // Lighter lavender highlight, used for the head tuft.
            accentColor: .hsb(hue: 0.76, saturation: 0.12, brightness: 1.0)
        ),
        face: FaceTraits(
            eyeShape: .round,
            eyeScale: 1.15,           // big, glossy eyes
            irisColor: .hsb(hue: 0.07, saturation: 0.78, brightness: 0.50), // warm amber-brown
            pupilStyle: .round,
            muzzleStyle: .small,
            noseStyle: .triangle,
            noseColor: .hsb(hue: 0.97, saturation: 0.40, brightness: 0.92), // pink
            cheekStyle: .blush,
            cheekColor: .hsb(hue: 0.97, saturation: 0.30, brightness: 1.0)
        ),
        ears: EarTraits(
            earStyle: .pointed,
            earScale: 1.15,
            earAngle: 0.5             // upright, no extra tilt
        ),
        tail: TailTraits(
            tailStyle: .plume,
            tailLength: 1.1,
            tailThickness: 1.2        // extra fluffy
        ),
        details: DetailTraits(
            headTuftStyle: .windswept,
            chestTuftStyle: .cloud,
            magicalFeature: .none,
            magicalColor: .hsb(hue: 0.76, saturation: 0.30, brightness: 1.0),
            magicalIntensity: 0
        ),
        motionPersonality: .curious
    )
}
