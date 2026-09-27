import Testing
@testable import LumiCore

struct PetConfigurationValidatorTests {
    @Test func clampsAllNumericTraits() throws {
        var input = PetConfiguration.fixture(seed: 7)
        input.body.bodyScale = 4
        input.body.headScale = -1
        input.body.patternDensity = 2
        input.body.patternScale = 0
        input.face.eyeScale = 3
        input.ears.earScale = 0
        input.ears.earAngle = -3
        input.tail.tailLength = 9
        input.tail.tailThickness = -9
        input.details.magicalIntensity = 9

        let output = try PetConfigurationValidator.validate(input)

        #expect(output.body.bodyScale == 1.10)
        #expect(output.body.headScale == 0.90)
        #expect(output.body.patternDensity == 1)
        #expect(output.body.patternScale == 0.75)
        #expect(output.face.eyeScale == 1.15)
        #expect(output.ears.earScale == 0.80)
        #expect(output.ears.earAngle == 0)
        #expect(output.tail.tailLength == 1.20)
        #expect(output.tail.tailThickness == 0.80)
        #expect(output.details.magicalIntensity == 1)
    }

    @Test func repairsLowContrastColorsDeterministically() throws {
        var input = PetConfiguration.fixture(seed: 8)
        input.palette.secondaryColor = input.palette.baseColor
        let first = try PetConfigurationValidator.validate(input)
        let second = try PetConfigurationValidator.validate(input)
        #expect(first == second)
        #expect(first.palette.secondaryColor.distance(to: first.palette.baseColor) >= 0.28)
    }

    @Test func leavesAlreadyValidConfigurationUnchanged() throws {
        var input = PetConfiguration.fixture(seed: 10)
        input.palette.baseColor = RGBAColor(red: 0.2, green: 0.2, blue: 0.6)
        input.palette.secondaryColor = RGBAColor(red: 0.95, green: 0.9, blue: 0.9)
        input.palette.accentColor = RGBAColor(red: 0.9, green: 0.8, blue: 0.2)
        input.face.irisColor = RGBAColor(red: 0.95, green: 0.95, blue: 0.95)
        input.face.noseColor = RGBAColor(red: 0.4, green: 0.1, blue: 0.2)
        #expect(try PetConfigurationValidator.validate(input) == input)
    }

    @Test func ensuringDistanceGuaranteesThresholdForMidGray() {
        let gray = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
        #expect(gray.ensuringDistance(0.34, from: gray).distance(to: gray) >= 0.34)
    }

    @Test func ensuringDistancePreservesAlpha() {
        let reference = RGBAColor(red: 0.5, green: 0.5, blue: 0.5)
        let translucent = RGBAColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.4)
        #expect(translucent.ensuringDistance(0.28, from: reference).alpha == 0.4)
    }

    @Test func sanitizesNonFiniteNumericTraits() throws {
        var input = PetConfiguration.fixture(seed: 11)
        input.body.bodyScale = .nan
        input.body.headScale = .infinity
        input.ears.earAngle = -.infinity
        input.details.magicalIntensity = .nan
        let output = try PetConfigurationValidator.validate(input)
        #expect(output.body.bodyScale == 0.90)
        #expect(output.body.headScale == 1.15)
        #expect(output.ears.earAngle == 0)
        #expect(output.details.magicalIntensity == 0)
    }

    @Test func sanitizesNonFiniteColorChannelsAndStaysIdempotent() throws {
        var input = PetConfiguration.fixture(seed: 12)
        input.palette.baseColor = RGBAColor(red: .nan, green: 0.5, blue: 0.5)
        input.palette.secondaryColor = RGBAColor(red: .nan, green: .nan, blue: .nan, alpha: .nan)
        input.face.irisColor = RGBAColor(red: .infinity, green: 0.1, blue: 0.1)
        let once = try PetConfigurationValidator.validate(input)
        let colors = [once.palette.baseColor, once.palette.secondaryColor, once.palette.accentColor, once.face.irisColor, once.face.noseColor, once.face.cheekColor, once.details.magicalColor]
        for color in colors {
            #expect(color.red.isFinite && color.green.isFinite && color.blue.isFinite && color.alpha.isFinite)
        }
        #expect(once.palette.secondaryColor.distance(to: once.palette.baseColor) >= 0.28)
        #expect(once.face.irisColor.distance(to: once.palette.baseColor) >= 0.34)
        #expect(try PetConfigurationValidator.validate(once) == once)
    }

    @Test func rejectsUnsupportedFormat() {
        var input = PetConfiguration.fixture(seed: 9)
        input.formatVersion = 2
        #expect(throws: PetValidationError.unsupportedFormat(2)) {
            try PetConfigurationValidator.validate(input)
        }
    }
}
