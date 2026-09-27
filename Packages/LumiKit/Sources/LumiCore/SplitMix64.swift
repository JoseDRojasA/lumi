public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func unitDouble() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992
    }

    mutating func value(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + unitDouble() * (range.upperBound - range.lowerBound)
    }

    mutating func element<T>(from values: [T]) -> T {
        values[Int(next() % UInt64(values.count))]
    }
}
