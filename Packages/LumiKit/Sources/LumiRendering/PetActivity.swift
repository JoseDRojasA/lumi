import Foundation
import CoreGraphics

/// Easing applied across a keyframe segment. Matches the curve math used by
/// `BreathingCurve` / `SecondaryMotionController` so activity motion feels
/// consistent with the rest of the rig.
public enum ActivityEasing: Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    func apply(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        switch self {
        case .linear: return x
        case .easeIn: return x * x
        case .easeOut: return 1 - (1 - x) * (1 - x)
        case .easeInOut: return x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
        }
    }
}

/// One keyframe of a single channel track. Values are expressed as OFFSETS from
/// the rig's base pose: `dx`/`dy`/`rotation` are additive (neutral `0`), and
/// `xScale`/`yScale` are multiplicative (neutral `1`) — matching
/// `PetMotionOffset`'s composition rules. `easing` describes how to interpolate
/// FROM the previous keyframe TO this one.
public struct ActivityKeyframe: Sendable {
    public var time: Double            // normalized 0...1 within the activity
    public var dx: CGFloat
    public var dy: CGFloat
    public var xScale: CGFloat
    public var yScale: CGFloat
    public var rotation: CGFloat
    public var easing: ActivityEasing

    public init(
        time: Double,
        dx: CGFloat = 0,
        dy: CGFloat = 0,
        xScale: CGFloat = 1,
        yScale: CGFloat = 1,
        rotation: CGFloat = 0,
        easing: ActivityEasing = .easeInOut
    ) {
        self.time = time
        self.dx = dx
        self.dy = dy
        self.xScale = xScale
        self.yScale = yScale
        self.rotation = rotation
        self.easing = easing
    }
}

/// An ordered list of keyframes for one channel. Sampling interpolates between
/// the two surrounding keyframes using the *destination* keyframe's easing.
/// Additive components interpolate around `0`; scale components around `1`.
public struct ActivityTrack: Sendable {
    public var keyframes: [ActivityKeyframe]

    public init(_ keyframes: [ActivityKeyframe]) {
        // Keep keyframes ordered by time so sampling is well-defined.
        self.keyframes = keyframes.sorted { $0.time < $1.time }
    }

    /// The additive+multiplicative offset at normalized progress `p ∈ [0, 1]`.
    func sample(at p: Double) -> PetMotionOffset {
        guard let first = keyframes.first else { return .identity }
        if p <= first.time { return offset(of: first) }
        guard let last = keyframes.last else { return .identity }
        if p >= last.time { return offset(of: last) }

        // Find the segment [a, b] containing p.
        var a = first
        var b = last
        for i in 1..<keyframes.count {
            if keyframes[i].time >= p {
                a = keyframes[i - 1]
                b = keyframes[i]
                break
            }
        }
        let span = b.time - a.time
        let localT = span > 0 ? (p - a.time) / span : 1
        let e = b.easing.apply(localT)
        let ce = CGFloat(e)
        return PetMotionOffset(
            position: CGVector(
                dx: a.dx + (b.dx - a.dx) * ce,
                dy: a.dy + (b.dy - a.dy) * ce
            ),
            xScale: a.xScale + (b.xScale - a.xScale) * ce,
            yScale: a.yScale + (b.yScale - a.yScale) * ce,
            zRotation: a.rotation + (b.rotation - a.rotation) * ce
        )
    }

    private func offset(of k: ActivityKeyframe) -> PetMotionOffset {
        PetMotionOffset(
            position: CGVector(dx: k.dx, dy: k.dy),
            xScale: k.xScale,
            yScale: k.yScale,
            zRotation: k.rotation
        )
    }
}

/// A data-driven, timed animation described as keyframed per-channel offset
/// tracks. Pure and `Sendable`: it holds no SpriteKit references and performs
/// no side effects — `ActivityController` plays it against the composer.
///
/// Activities layer ADDITIVELY on top of breathing and secondary motion because
/// the composer sums position/rotation and multiplies scale across sources.
public struct PetActivity: Sendable, Identifiable {
    public let id: String
    public let duration: TimeInterval
    public let loops: Bool
    public let tracks: [PetMotionChannel: ActivityTrack]

    public init(
        id: String,
        duration: TimeInterval,
        loops: Bool,
        tracks: [PetMotionChannel: ActivityTrack]
    ) {
        self.id = id
        self.duration = duration
        self.loops = loops
        self.tracks = tracks
    }

    /// Samples every channel track at progress `p ∈ [0, 1]`, scaling the motion
    /// by `amplitudeScale` (used for Reduce Motion). Scaling is applied to the
    /// DELTA from neutral: position/rotation × scale, and `(value − 1) × scale`
    /// for the multiplicative scale components (so `amplitudeScale == 0` yields
    /// `.identity` everywhere).
    func sample(atProgress p: Double, amplitudeScale: Double) -> [PetMotionChannel: PetMotionOffset] {
        let s = CGFloat(max(0, amplitudeScale))
        var result: [PetMotionChannel: PetMotionOffset] = [:]
        for (channel, track) in tracks {
            let raw = track.sample(at: p)
            result[channel] = PetMotionOffset(
                position: CGVector(dx: raw.position.dx * s, dy: raw.position.dy * s),
                xScale: 1 + (raw.xScale - 1) * s,
                yScale: 1 + (raw.yScale - 1) * s,
                zRotation: raw.zRotation * s
            )
        }
        return result
    }
}

// MARK: - Built-in activities

public extension PetActivity {
    /// A springy hop: anticipation crouch → takeoff arc with body stretch and
    /// paw lift → apex → landing squash → settle. Non-looping (~0.9 s).
    ///
    /// Note: the right ear is a mirrored node (`xScale -1`), so its rotation
    /// offset is the NEGATION of the left ear's to twitch in the same visual
    /// direction — mirroring `SecondaryMotionController`.
    static let jump = PetActivity(
        id: "jump",
        duration: 0.9,
        loops: false,
        tracks: [
            .root: ActivityTrack([
                .init(time: 0.00, dy: 0, easing: .easeInOut),
                .init(time: 0.18, dy: -14, easing: .easeOut),   // crouch
                .init(time: 0.50, dy: 120, easing: .easeOut),   // apex
                .init(time: 0.82, dy: -10, easing: .easeIn),    // land squash
                .init(time: 1.00, dy: 0, easing: .easeOut)      // settle
            ]),
            .chest: ActivityTrack([
                .init(time: 0.00, xScale: 1, yScale: 1),
                .init(time: 0.18, xScale: 1.08, yScale: 0.90, easing: .easeOut),  // squash
                .init(time: 0.50, xScale: 0.94, yScale: 1.12, easing: .easeOut),  // stretch
                .init(time: 0.82, xScale: 1.08, yScale: 0.90, easing: .easeIn),   // land squash
                .init(time: 1.00, xScale: 1, yScale: 1, easing: .easeOut)
            ]),
            .abdomen: ActivityTrack([
                .init(time: 0.00, xScale: 1, yScale: 1),
                .init(time: 0.18, xScale: 1.06, yScale: 0.92, easing: .easeOut),
                .init(time: 0.50, xScale: 0.96, yScale: 1.08, easing: .easeOut),
                .init(time: 0.82, xScale: 1.06, yScale: 0.92, easing: .easeIn),
                .init(time: 1.00, xScale: 1, yScale: 1, easing: .easeOut)
            ]),
            .paws: ActivityTrack([
                .init(time: 0.00, dy: 0),
                .init(time: 0.50, dy: 26, easing: .easeOut),    // tuck up at apex
                .init(time: 0.82, dy: 0, easing: .easeIn)
            ]),
            .head: ActivityTrack([
                .init(time: 0.00, dy: 0),
                .init(time: 0.18, dy: -6, easing: .easeOut),
                .init(time: 0.50, dy: 10, easing: .easeOut),    // follow-through up
                .init(time: 0.82, dy: -4, easing: .easeIn),
                .init(time: 1.00, dy: 0, easing: .easeOut)
            ]),
            .leftEar: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.50, rotation: 0.20, easing: .easeOut),
                .init(time: 0.90, rotation: -0.08, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeOut)
            ]),
            .rightEar: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.50, rotation: -0.20, easing: .easeOut),
                .init(time: 0.90, rotation: 0.08, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeOut)
            ]),
            .tail: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.45, rotation: -0.22, easing: .easeOut),
                .init(time: 0.80, rotation: 0.14, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeOut)
            ])
        ]
    )

    /// A looping bop: rhythmic side sway + bob, counter head tilt, alternating
    /// ears, tail swish, subtle chest pulse. Loops (~2.0 s period).
    static let dance = PetActivity(
        id: "dance",
        duration: 2.0,
        loops: true,
        tracks: [
            .root: ActivityTrack([
                .init(time: 0.00, dx: 0, dy: 0),
                .init(time: 0.25, dx: 18, dy: 8, easing: .easeInOut),
                .init(time: 0.50, dx: 0, dy: 0, easing: .easeInOut),
                .init(time: 0.75, dx: -18, dy: 8, easing: .easeInOut),
                .init(time: 1.00, dx: 0, dy: 0, easing: .easeInOut)
            ]),
            .chest: ActivityTrack([
                .init(time: 0.00, yScale: 1),
                .init(time: 0.25, yScale: 1.05, easing: .easeInOut),
                .init(time: 0.50, yScale: 1, easing: .easeInOut),
                .init(time: 0.75, yScale: 1.05, easing: .easeInOut),
                .init(time: 1.00, yScale: 1, easing: .easeInOut)
            ]),
            .head: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.25, rotation: -0.12, easing: .easeInOut),
                .init(time: 0.50, rotation: 0, easing: .easeInOut),
                .init(time: 0.75, rotation: 0.12, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ]),
            .leftEar: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.25, rotation: 0.18, easing: .easeInOut),
                .init(time: 0.50, rotation: 0, easing: .easeInOut),
                .init(time: 0.75, rotation: -0.10, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ]),
            .rightEar: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.25, rotation: -0.10, easing: .easeInOut),
                .init(time: 0.50, rotation: 0, easing: .easeInOut),
                .init(time: 0.75, rotation: 0.18, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ]),
            .tail: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.25, rotation: 0.24, easing: .easeInOut),
                .init(time: 0.50, rotation: 0, easing: .easeInOut),
                .init(time: 0.75, rotation: -0.24, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ])
        ]
    )

    /// A slow full-body stretch: rise + vertical stretch, paw reach, head dip.
    /// Non-looping (~1.4 s).
    static let stretch = PetActivity(
        id: "stretch",
        duration: 1.4,
        loops: false,
        tracks: [
            .root: ActivityTrack([
                .init(time: 0.00, dy: 0),
                .init(time: 0.45, dy: 16, easing: .easeOut),
                .init(time: 0.70, dy: 16, easing: .linear),
                .init(time: 1.00, dy: 0, easing: .easeInOut)
            ]),
            .chest: ActivityTrack([
                .init(time: 0.00, xScale: 1, yScale: 1),
                .init(time: 0.45, xScale: 0.95, yScale: 1.12, easing: .easeOut),
                .init(time: 0.70, xScale: 0.95, yScale: 1.12, easing: .linear),
                .init(time: 1.00, xScale: 1, yScale: 1, easing: .easeInOut)
            ]),
            .head: ActivityTrack([
                .init(time: 0.00, dy: 0, rotation: 0),
                .init(time: 0.45, dy: -6, rotation: -0.10, easing: .easeOut),
                .init(time: 0.70, dy: -6, rotation: -0.10, easing: .linear),
                .init(time: 1.00, dy: 0, rotation: 0, easing: .easeInOut)
            ]),
            .paws: ActivityTrack([
                .init(time: 0.00, dy: 0),
                .init(time: 0.45, dy: -10, easing: .easeOut),
                .init(time: 0.70, dy: -10, easing: .linear),
                .init(time: 1.00, dy: 0, easing: .easeInOut)
            ])
        ]
    )

    /// Curious look-around: head turns left, then right, tail drifts. Non-looping (~1.6 s).
    static let lookAround = PetActivity(
        id: "lookAround",
        duration: 1.6,
        loops: false,
        tracks: [
            .head: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.30, rotation: 0.16, easing: .easeInOut),
                .init(time: 0.65, rotation: -0.16, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ]),
            .leftEar: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.30, rotation: 0.10, easing: .easeInOut),
                .init(time: 0.65, rotation: -0.06, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ]),
            .rightEar: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.30, rotation: -0.10, easing: .easeInOut),
                .init(time: 0.65, rotation: 0.06, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ]),
            .tail: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.50, rotation: 0.12, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ])
        ]
    )

    /// A happy little wiggle: quick side-to-side sway + tail swish. Non-looping (~1.0 s).
    static let happyWiggle = PetActivity(
        id: "happyWiggle",
        duration: 1.0,
        loops: false,
        tracks: [
            .root: ActivityTrack([
                .init(time: 0.00, dx: 0),
                .init(time: 0.20, dx: 10, easing: .easeInOut),
                .init(time: 0.45, dx: -10, easing: .easeInOut),
                .init(time: 0.70, dx: 8, easing: .easeInOut),
                .init(time: 1.00, dx: 0, easing: .easeInOut)
            ]),
            .head: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.20, rotation: 0.08, easing: .easeInOut),
                .init(time: 0.45, rotation: -0.08, easing: .easeInOut),
                .init(time: 0.70, rotation: 0.06, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ]),
            .tail: ActivityTrack([
                .init(time: 0.00, rotation: 0),
                .init(time: 0.25, rotation: 0.2, easing: .easeInOut),
                .init(time: 0.55, rotation: -0.2, easing: .easeInOut),
                .init(time: 0.80, rotation: 0.12, easing: .easeInOut),
                .init(time: 1.00, rotation: 0, easing: .easeInOut)
            ])
        ]
    )

    /// Idle activities the director schedules at random during rest.
    static let idleActivities: [PetActivity] = [.stretch, .lookAround, .happyWiggle]

    /// All built-in activities, keyed by id (for `play(id:)` / debug UIs).
    static let allBuiltIn: [PetActivity] = [.jump, .dance, .stretch, .lookAround, .happyWiggle]

    static func builtIn(id: String) -> PetActivity? {
        allBuiltIn.first { $0.id == id }
    }
}
