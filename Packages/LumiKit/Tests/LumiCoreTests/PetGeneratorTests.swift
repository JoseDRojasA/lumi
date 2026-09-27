import Testing
@testable import LumiCore

struct PetGeneratorTests {
    @Test func sameSeedProducesSameCanonicalBytes() throws {
        let first = try PetGenerator.generate(seed: 9_001, version: 1)
        let second = try PetGenerator.generate(seed: 9_001, version: 1)
        #expect(try PetConfigurationCodec.encode(first) == PetConfigurationCodec.encode(second))
    }

    @Test func differentSeedsProduceVariation() throws {
        let first = try PetGenerator.generate(seed: 1, version: 1)
        let second = try PetGenerator.generate(seed: 2, version: 1)
        #expect(first != second)
    }

    @Test func unsupportedGeneratorVersionThrows() {
        #expect(throws: PetGeneratorError.unsupportedVersion(2)) {
            try PetGenerator.generate(seed: 1, version: 2)
        }
    }

    @Test func generatedMetadataRecordsSeedAndVersions() throws {
        let configuration = try PetGenerator.generate(seed: 77, version: 1)
        #expect(configuration.seed == 77)
        #expect(configuration.formatVersion == 1)
        #expect(configuration.generatorVersion == 1)
    }

    @Test func numericTraitsStayInsideDeclaredRanges() throws {
        for seed in UInt64(0)..<200 {
            let c = try PetGenerator.generate(seed: seed, version: 1)
            #expect((0.90...1.10).contains(c.body.bodyScale))
            #expect((0.90...1.15).contains(c.body.headScale))
            #expect((0...1).contains(c.body.patternDensity))
            #expect((0.75...1.25).contains(c.body.patternScale))
            #expect((0.85...1.15).contains(c.face.eyeScale))
            #expect((0.80...1.20).contains(c.ears.earScale))
            #expect((0...1).contains(c.ears.earAngle))
            #expect((0.80...1.20).contains(c.tail.tailLength))
            #expect((0.80...1.20).contains(c.tail.tailThickness))
            #expect((0...1).contains(c.details.magicalIntensity))
        }
    }

    @Test func generatorVersionOneOutputIsFrozen() throws {
        let json = String(
            decoding: try PetConfigurationCodec.encode(PetGenerator.generate(seed: 42, version: 1)),
            as: UTF8.self
        )
        // v1 = frozen draw order + PetConfigurationValidator. Regenerate only with a new generatorVersion.
        let expected = #"{"body":{"bodyScale":0.9319820785753841,"bodyShape":"compact","furStyle":"smooth","headScale":0.9696502825637847,"patternDensity":0.8682280765465323,"patternScale":0.8592025968560921,"patternStyle":"socks"},"details":{"chestTuftStyle":"none","headTuftStyle":"curl","magicalColor":{"alpha":1,"blue":0.9273064431965576,"green":0.8785307687375152,"red":0.6586066716764534},"magicalFeature":"none","magicalIntensity":0.7747831222683482},"ears":{"earAngle":0.7821562891438542,"earScale":1.0588378502418507,"earStyle":"long"},"face":{"cheekColor":{"alpha":1,"blue":0.7163640162788618,"green":0.7106665408189418,"red":0.983192661428044},"cheekStyle":"glow","eyeScale":0.998649597444773,"eyeShape":"sleepy","irisColor":{"alpha":1,"blue":0.14068087644252114,"green":0.2476279831430258,"red":0.33146504753231687},"muzzleStyle":"small","noseColor":{"alpha":1,"blue":0.5585210565246553,"green":0.4598774033917554,"red":0.7135562750567469},"noseStyle":"triangle","pupilStyle":"vertical"},"formatVersion":1,"generatorVersion":1,"motionPersonality":"lively","palette":{"accentColor":{"alpha":1,"blue":0.401728661842903,"green":0.8305152663950346,"red":0.46526489765183865},"baseColor":{"alpha":1,"blue":0.8313267719441042,"green":0.5636567501364536,"red":0.7788075743046732},"secondaryColor":{"alpha":1,"blue":0.9951339611632215,"green":0.9556076706891369,"red":0.981779772284483}},"seed":42,"tail":{"tailLength":0.9520091474328871,"tailStyle":"long","tailThickness":0.8252099976829589}}"#
        #expect(json == expected)
    }

    @Test func oneThousandSeedsProduceValidConfigurations() throws {
        for seed in UInt64(0)..<1_000 {
            let configuration = try PetGenerator.generate(seed: seed, version: 1)
            #expect(configuration.body.bodyScale >= 0.90)
            #expect(configuration.body.bodyScale <= 1.10)
            #expect(configuration.palette.secondaryColor.distance(to: configuration.palette.baseColor) >= 0.28)
            #expect(configuration.palette.accentColor.distance(to: configuration.palette.baseColor) >= 0.28)
            #expect(configuration.face.irisColor.distance(to: configuration.palette.baseColor) >= 0.34)
            #expect(configuration.face.noseColor.distance(to: configuration.palette.secondaryColor) >= 0.28)
            #expect(try PetConfigurationValidator.validate(configuration) == configuration)
        }
    }

    @Test func generatedColorsRarelyNeedRepair() throws {
        var repaired = ["secondary": 0, "accent": 0, "iris": 0, "nose": 0]
        for seed in UInt64(0)..<1_000 {
            let raw = PetGenerator.draw(seed: seed)
            let fixed = try PetConfigurationValidator.validate(raw)
            if raw.palette.secondaryColor != fixed.palette.secondaryColor { repaired["secondary", default: 0] += 1 }
            if raw.palette.accentColor != fixed.palette.accentColor { repaired["accent", default: 0] += 1 }
            if raw.face.irisColor != fixed.face.irisColor { repaired["iris", default: 0] += 1 }
            if raw.face.noseColor != fixed.face.noseColor { repaired["nose", default: 0] += 1 }
        }
        for (role, count) in repaired {
            #expect(count <= 5, "\(role) repaired \(count)/1000 times")
        }
    }

    @Test func secondaryColorIsLighterThanBase() throws {
        for seed in UInt64(0)..<200 {
            let c = try PetGenerator.generate(seed: seed, version: 1)
            let luminance: (RGBAColor) -> Double = { 0.2126 * $0.red + 0.7152 * $0.green + 0.0722 * $0.blue }
            #expect(luminance(c.palette.secondaryColor) > luminance(c.palette.baseColor))
        }
    }

    @Test func irisIsDarkerThanBase() throws {
        for seed in UInt64(0)..<200 {
            let c = try PetGenerator.generate(seed: seed, version: 1)
            let luminance: (RGBAColor) -> Double = { 0.2126 * $0.red + 0.7152 * $0.green + 0.0722 * $0.blue }
            #expect(luminance(c.face.irisColor) < luminance(c.palette.baseColor))
        }
    }

    @Test func hsbConversionMatchesKnownColors() {
        let red = RGBAColor.hsb(hue: 0, saturation: 1, brightness: 1)
        #expect(red == RGBAColor(red: 1, green: 0, blue: 0))
        let gray = RGBAColor.hsb(hue: 0.5, saturation: 0, brightness: 0.5)
        #expect(gray == RGBAColor(red: 0.5, green: 0.5, blue: 0.5))
        let blue = RGBAColor.hsb(hue: 2.0 / 3.0, saturation: 1, brightness: 1)
        #expect(abs(blue.blue - 1) < 1e-9 && abs(blue.red) < 1e-9 && abs(blue.green) < 1e-9)
    }
}
