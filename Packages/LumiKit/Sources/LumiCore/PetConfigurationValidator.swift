// PetConfigurationValidator — clamps numeric traits into their declared v1
// ranges and repairs low-contrast colors so every configuration renders
// legibly. Validation is deterministic: identical input always yields
// identical output, and validating an already-valid configuration is a no-op
// (the validator is idempotent).

public enum PetValidationError: Error, Equatable {
    case unsupportedFormat(Int)
}

public enum PetConfigurationValidator {
    public static func validate(_ input: PetConfiguration) throws -> PetConfiguration {
        guard input.formatVersion == 1 else {
            throw PetValidationError.unsupportedFormat(input.formatVersion)
        }

        var output = input
        output.body.bodyScale = output.body.bodyScale.clamped(to: 0.90...1.10)
        output.body.headScale = output.body.headScale.clamped(to: 0.90...1.15)
        output.body.patternDensity = output.body.patternDensity.clamped(to: 0...1)
        output.body.patternScale = output.body.patternScale.clamped(to: 0.75...1.25)
        output.face.eyeScale = output.face.eyeScale.clamped(to: 0.85...1.15)
        output.ears.earScale = output.ears.earScale.clamped(to: 0.80...1.20)
        output.ears.earAngle = output.ears.earAngle.clamped(to: 0...1)
        output.tail.tailLength = output.tail.tailLength.clamped(to: 0.80...1.20)
        output.tail.tailThickness = output.tail.tailThickness.clamped(to: 0.80...1.20)
        output.details.magicalIntensity = output.details.magicalIntensity.clamped(to: 0...1)
        output.palette.baseColor = output.palette.baseColor.clamped()
        output.palette.secondaryColor = output.palette.secondaryColor.clamped().ensuringDistance(0.28, from: output.palette.baseColor)
        output.palette.accentColor = output.palette.accentColor.clamped().ensuringDistance(0.28, from: output.palette.baseColor)
        output.face.irisColor = output.face.irisColor.clamped().ensuringDistance(0.34, from: output.palette.baseColor)
        output.face.noseColor = output.face.noseColor.clamped().ensuringDistance(0.28, from: output.palette.secondaryColor)
        output.face.cheekColor = output.face.cheekColor.clamped()
        output.details.magicalColor = output.details.magicalColor.clamped()
        return output
    }
}
