import Foundation

public struct RGBAColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public func clamped() -> RGBAColor {
        RGBAColor(
            red: red.clamped(to: 0...1),
            green: green.clamped(to: 0...1),
            blue: blue.clamped(to: 0...1),
            alpha: alpha.clamped(to: 0...1)
        )
    }

    public func distance(to other: RGBAColor) -> Double {
        let dr = red - other.red
        let dg = green - other.green
        let db = blue - other.blue
        return (dr * dr + dg * dg + db * db).squareRoot()
    }

    /// Converts an HSB/HSV triple into an `RGBAColor` using the standard sector
    /// algorithm. Uses only arithmetic and `floor`/`truncatingRemainder` so the
    /// result is deterministic and independent of any platform color API.
    public static func hsb(
        hue: Double,
        saturation: Double,
        brightness: Double,
        alpha: Double = 1
    ) -> RGBAColor {
        let s = saturation
        let b = brightness

        // Normalize hue into [0, 1) then scale into six sectors.
        var normalizedHue = hue.truncatingRemainder(dividingBy: 1)
        if normalizedHue < 0 { normalizedHue += 1 }
        let h = normalizedHue * 6
        let i = h.rounded(.down)
        let f = h - i

        let p = b * (1 - s)
        let q = b * (1 - s * f)
        let t = b * (1 - s * (1 - f))

        let red: Double
        let green: Double
        let blue: Double
        switch Int(i) % 6 {
        case 0: (red, green, blue) = (b, t, p)
        case 1: (red, green, blue) = (q, b, p)
        case 2: (red, green, blue) = (p, b, t)
        case 3: (red, green, blue) = (p, q, b)
        case 4: (red, green, blue) = (t, p, b)
        default: (red, green, blue) = (b, p, q)
        }

        return RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Returns a color at least `minimum` RGB-Euclidean distance from
    /// `reference`. If the receiver is already far enough it is returned
    /// unchanged (clamped). Otherwise it is replaced deterministically with a
    /// pastel that contrasts, falling back to black/white when even the
    /// pastels are too close. Alpha is preserved.
    public func ensuringDistance(_ minimum: Double, from reference: RGBAColor) -> RGBAColor {
        let current = clamped()
        let reference = reference.clamped()
        guard current.distance(to: reference) < minimum else { return current }

        let pastelLight = RGBAColor(red: 0.96, green: 0.94, blue: 0.99, alpha: current.alpha)
        let pastelDark = RGBAColor(red: 0.20, green: 0.16, blue: 0.28, alpha: current.alpha)
        let pastelCandidate = pastelLight.distance(to: reference) >= pastelDark.distance(to: reference) ? pastelLight : pastelDark
        if pastelCandidate.distance(to: reference) >= minimum {
            return pastelCandidate
        }

        let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: current.alpha)
        let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: current.alpha)
        return black.distance(to: reference) >= white.distance(to: reference) ? black : white
    }
}

extension Double {
    /// Module-internal so the validator can clamp trait values.
    /// Clamps into `range`, mapping NaN to the lower bound so no non-finite
    /// value survives validation.
    func clamped(to range: ClosedRange<Double>) -> Double {
        guard !isNaN else { return range.lowerBound }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
