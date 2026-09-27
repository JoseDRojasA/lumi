import Foundation

/// Per-channel breath intensities in `[0, 1]` where 0 is the base pose and 1 is
/// the fully-inhaled pose. Each channel is driven with a slightly different
/// timing so the animation reads as a living animal rather than a uniform pulse.
public struct BreathingSample: Equatable, Sendable {
    public let abdomen: Double
    public let chest: Double
    public let head: Double
    public let secondary: Double

    public init(abdomen: Double, chest: Double, head: Double, secondary: Double) {
        self.abdomen = abdomen
        self.chest = chest
        self.head = head
        self.secondary = secondary
    }

    static let zero = BreathingSample(abdomen: 0, chest: 0, head: 0, secondary: 0)
}

/// Pure, deterministic mapping from a normalized cycle phase `p ∈ [0, 1]` to the
/// four breath channels. Split into four asymmetric phases:
/// inhale (32%), pause (4%), exhale (44%), rest (20%).
public enum BreathingCurve {
    private static let inhaleEnd = 0.32
    private static let pauseEnd = 0.36
    private static let exhaleEnd = 0.80

    public static func sample(phase: Double) -> BreathingSample {
        // Guard against NaN and out-of-range phases: treat as base pose.
        guard phase.isFinite, phase > 0, phase < 1 else { return .zero }

        if phase < inhaleEnd {
            // Inhale. Abdomen leads; chest lags by 0.04; head lags by 0.06.
            let abdomen = easeOutCubic(clamp(phase / 0.32))
            let chest = easeOutCubic(clamp((phase - 0.04) / 0.28))
            let head = easeOutCubic(clamp((phase - 0.06) / 0.26))
            // Secondary follows the same delayed timing as head during inhale.
            let secondary = head
            return BreathingSample(abdomen: abdomen, chest: chest, head: head, secondary: secondary)
        } else if phase < pauseEnd {
            // Held-expanded pause: everything at full inhale.
            return BreathingSample(abdomen: 1, chest: 1, head: 1, secondary: 1)
        } else if phase < exhaleEnd {
            // Exhale. Body settles with ease-in-out; secondary (fur/tail) lags.
            let v = (phase - 0.36) / 0.44
            let settle = 1 - easeInOutCubic(clamp(v))
            // Secondary trails the body settling — a visible fur lag.
            let secondary = 1 - easeInOutCubic(clamp((v - 0.12) / 0.88))
            return BreathingSample(abdomen: settle, chest: settle, head: settle, secondary: secondary)
        } else {
            // Rest: near base (exactly base here for bit-exact restoration).
            return .zero
        }
    }

    // MARK: - Easing (pure Double)

    private static func easeOutCubic(_ x: Double) -> Double {
        1 - pow(1 - x, 3)
    }

    private static func easeInOutCubic(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
    }

    private static func clamp(_ x: Double) -> Double {
        min(1, max(0, x))
    }
}
