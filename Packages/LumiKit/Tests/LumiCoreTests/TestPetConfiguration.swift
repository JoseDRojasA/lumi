@testable import LumiCore

extension PetConfiguration {
    static func fixture(seed: UInt64) -> PetConfiguration {
        PetConfiguration(
            formatVersion: 1,
            generatorVersion: 1,
            seed: seed,
            body: BodyTraits(bodyShape: .round, bodyScale: 1, headScale: 1.05, furStyle: .fluffy, patternStyle: .spots, patternDensity: 0.4, patternScale: 1),
            palette: Palette(
                baseColor: RGBAColor(red: 0.72, green: 0.62, blue: 0.92),
                secondaryColor: RGBAColor(red: 0.95, green: 0.90, blue: 0.98),
                accentColor: RGBAColor(red: 0.46, green: 0.72, blue: 0.94)
            ),
            face: FaceTraits(
                eyeShape: .round,
                eyeScale: 1.08,
                irisColor: RGBAColor(red: 0.28, green: 0.16, blue: 0.12),
                pupilStyle: .round,
                muzzleStyle: .small,
                noseStyle: .heart,
                noseColor: RGBAColor(red: 0.74, green: 0.36, blue: 0.48),
                cheekStyle: .blush,
                cheekColor: RGBAColor(red: 0.94, green: 0.62, blue: 0.72)
            ),
            ears: EarTraits(earStyle: .pointed, earScale: 1, earAngle: 0.5),
            tail: TailTraits(tailStyle: .plume, tailLength: 1, tailThickness: 1),
            details: DetailTraits(
                headTuftStyle: .windswept,
                chestTuftStyle: .cloud,
                magicalFeature: .sparkles,
                magicalColor: RGBAColor(red: 0.82, green: 0.72, blue: 1),
                magicalIntensity: 0.5
            ),
            motionPersonality: .curious
        )
    }
}
