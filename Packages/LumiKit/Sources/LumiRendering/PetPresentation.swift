import LumiCore

public struct PetPresentation: Equatable, Sendable {
    public let configuration: PetConfiguration
    public let accessibilityDescription: String

    public init(configuration: PetConfiguration) {
        self.configuration = configuration
        self.accessibilityDescription = configuration.accessibilityDescription
    }
}

extension PetConfiguration {
    /// e.g. "A curious, fluffy Lumi with pointed ears and a plume tail"
    var accessibilityDescription: String {
        "A \(motionPersonality.rawValue), \(body.furStyle.rawValue) Lumi with \(ears.earStyle.rawValue) ears and a \(tail.tailStyle.rawValue) tail"
    }
}
