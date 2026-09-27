public enum BodyShape: String, CaseIterable, Codable, Sendable { case round, compact, pear }
public enum FurStyle: String, CaseIterable, Codable, Sendable { case smooth, fluffy, spiky }
public enum PatternStyle: String, CaseIterable, Codable, Sendable { case none, spots, stripes, mask, socks, gradient }
public enum EyeShape: String, CaseIterable, Codable, Sendable { case round, almond, sleepy }
public enum PupilStyle: String, CaseIterable, Codable, Sendable { case round, vertical, star }
public enum EarStyle: String, CaseIterable, Codable, Sendable { case pointed, rounded, long, floppy }
public enum TailStyle: String, CaseIterable, Codable, Sendable { case short, long, curled, plume }
public enum HeadTuftStyle: String, CaseIterable, Codable, Sendable { case none, curl, split, windswept }
public enum ChestTuftStyle: String, CaseIterable, Codable, Sendable { case none, small, layered, cloud }
public enum MuzzleStyle: String, CaseIterable, Codable, Sendable { case small, round, pronounced }
public enum NoseStyle: String, CaseIterable, Codable, Sendable { case dot, triangle, heart }
public enum CheekStyle: String, CaseIterable, Codable, Sendable { case none, blush, freckles, glow }
public enum MagicalFeature: String, CaseIterable, Codable, Sendable { case none, glow, sparkles, orbitingLight }
public enum MotionPersonality: String, CaseIterable, Codable, Sendable { case calm, curious, playful, lively, sleepy }

public struct BodyTraits: Codable, Equatable, Sendable {
    public var bodyShape: BodyShape
    public var bodyScale: Double
    public var headScale: Double
    public var furStyle: FurStyle
    public var patternStyle: PatternStyle
    public var patternDensity: Double
    public var patternScale: Double

    public init(
        bodyShape: BodyShape,
        bodyScale: Double,
        headScale: Double,
        furStyle: FurStyle,
        patternStyle: PatternStyle,
        patternDensity: Double,
        patternScale: Double
    ) {
        self.bodyShape = bodyShape
        self.bodyScale = bodyScale
        self.headScale = headScale
        self.furStyle = furStyle
        self.patternStyle = patternStyle
        self.patternDensity = patternDensity
        self.patternScale = patternScale
    }
}

public struct Palette: Codable, Equatable, Sendable {
    public var baseColor: RGBAColor
    public var secondaryColor: RGBAColor
    public var accentColor: RGBAColor

    public init(baseColor: RGBAColor, secondaryColor: RGBAColor, accentColor: RGBAColor) {
        self.baseColor = baseColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
    }
}

public struct FaceTraits: Codable, Equatable, Sendable {
    public var eyeShape: EyeShape
    public var eyeScale: Double
    public var irisColor: RGBAColor
    public var pupilStyle: PupilStyle
    public var muzzleStyle: MuzzleStyle
    public var noseStyle: NoseStyle
    public var noseColor: RGBAColor
    public var cheekStyle: CheekStyle
    public var cheekColor: RGBAColor

    public init(
        eyeShape: EyeShape,
        eyeScale: Double,
        irisColor: RGBAColor,
        pupilStyle: PupilStyle,
        muzzleStyle: MuzzleStyle,
        noseStyle: NoseStyle,
        noseColor: RGBAColor,
        cheekStyle: CheekStyle,
        cheekColor: RGBAColor
    ) {
        self.eyeShape = eyeShape
        self.eyeScale = eyeScale
        self.irisColor = irisColor
        self.pupilStyle = pupilStyle
        self.muzzleStyle = muzzleStyle
        self.noseStyle = noseStyle
        self.noseColor = noseColor
        self.cheekStyle = cheekStyle
        self.cheekColor = cheekColor
    }
}

public struct EarTraits: Codable, Equatable, Sendable {
    public var earStyle: EarStyle
    public var earScale: Double
    public var earAngle: Double

    public init(earStyle: EarStyle, earScale: Double, earAngle: Double) {
        self.earStyle = earStyle
        self.earScale = earScale
        self.earAngle = earAngle
    }
}

public struct TailTraits: Codable, Equatable, Sendable {
    public var tailStyle: TailStyle
    public var tailLength: Double
    public var tailThickness: Double

    public init(tailStyle: TailStyle, tailLength: Double, tailThickness: Double) {
        self.tailStyle = tailStyle
        self.tailLength = tailLength
        self.tailThickness = tailThickness
    }
}

public struct DetailTraits: Codable, Equatable, Sendable {
    public var headTuftStyle: HeadTuftStyle
    public var chestTuftStyle: ChestTuftStyle
    public var magicalFeature: MagicalFeature
    public var magicalColor: RGBAColor
    public var magicalIntensity: Double

    public init(
        headTuftStyle: HeadTuftStyle,
        chestTuftStyle: ChestTuftStyle,
        magicalFeature: MagicalFeature,
        magicalColor: RGBAColor,
        magicalIntensity: Double
    ) {
        self.headTuftStyle = headTuftStyle
        self.chestTuftStyle = chestTuftStyle
        self.magicalFeature = magicalFeature
        self.magicalColor = magicalColor
        self.magicalIntensity = magicalIntensity
    }
}
