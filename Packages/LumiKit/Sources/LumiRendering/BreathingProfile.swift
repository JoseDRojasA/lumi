import Foundation
import CoreGraphics
import LumiCore

/// Immutable parameters describing one resting-breath cycle for a pet rig.
///
/// Amplitudes are expressed as fractions: `abdomen*Amplitude` are fractions of
/// the abdomen's base scale; `chestRise`, `headRise` and `secondaryAmplitude`
/// are fractions of the body sprite height. The four phase shares are fixed
/// class-level constants shared by every profile.
public struct BreathingProfile: Equatable, Sendable {
    /// Inhale occupies the first 32% of the cycle (abdomen leads, chest/head follow).
    public static let inhaleShare: Double = 0.32
    /// A brief held-expanded pause (4%).
    public static let pauseShare: Double = 0.04
    /// Exhale settles the body over 44% — longer and eased differently than inhale.
    public static let exhaleShare: Double = 0.44
    /// Near-base rest for the final 20%.
    public static let restShare: Double = 0.20

    public let duration: TimeInterval
    /// Fraction of the abdomen's base xScale to add at full inhale (e.g. 0.028 = +2.8%).
    public let abdomenXAmplitude: CGFloat
    /// Fraction of the abdomen's base yScale to add at full inhale.
    public let abdomenYAmplitude: CGFloat
    /// Chest rise as a fraction of body height at full inhale.
    public let chestRise: CGFloat
    /// Head rise as a fraction of body height at full inhale.
    public let headRise: CGFloat
    /// Fraction of body height driving delayed secondary motion (tuft/cheek/tail).
    /// Zero disables all secondary motion (used by the watch rig).
    public let secondaryAmplitude: CGFloat

    public init(personality: MotionPersonality, reduceMotion: Bool, includesSecondaryMotion: Bool = true) {
        self.duration = Self.duration(for: personality)

        // Reduce Motion scales every amplitude by exactly 0.4.
        let scale: CGFloat = reduceMotion ? 0.4 : 1.0

        self.abdomenXAmplitude = 0.028 * scale
        self.abdomenYAmplitude = 0.018 * scale
        self.chestRise = 0.015 * scale
        self.headRise = 0.008 * scale
        self.secondaryAmplitude = includesSecondaryMotion ? (0.006 * scale) : 0
    }

    private static func duration(for personality: MotionPersonality) -> TimeInterval {
        switch personality {
        case .calm: return 3.6
        case .curious: return 3.1
        case .playful: return 2.8
        case .lively: return 2.4
        case .sleepy: return 4.0
        }
    }
}
