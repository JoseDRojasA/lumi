import Foundation
import CoreGraphics
import SpriteKit
import LumiCore

/// Immutable parameters for the secondary idle motions (blink, gaze, ear
/// twitch, tail sway, weight shift, magic pulse). All values derive purely from
/// the pet's `PetConfiguration`, its motion personality, whether Reduce Motion
/// is on, and whether effects (magic) are permitted by the render policy.
///
/// Amplitudes affected by Reduce Motion are quartered (`× 0.25`); blink timing
/// is never reduced. `magicPulse == 0` means magic is static.
public struct SecondaryMotionProfile: Equatable, Sendable {
    /// Range of seconds between (non-double) blinks.
    public let blinkInterval: ClosedRange<Double>
    /// Duration of one blink's close→open cycle, in seconds.
    public let blinkDuration: Double
    /// Probability that a blink is immediately followed by a second one.
    public let doubleBlinkChance: Double

    /// Range of seconds between gaze retargets.
    public let gazeInterval: ClosedRange<Double>
    /// Gaze radius as a fraction of eye width.
    public let gazeRadius: Double

    /// Range of seconds between ear twitches.
    public let earInterval: ClosedRange<Double>
    /// Peak ear-twitch rotation in radians.
    public let earAmplitude: Double

    /// Tail sway period in seconds.
    public let tailPeriod: Double
    /// Tail sway amplitude in radians.
    public let tailAmplitude: Double

    /// Range of seconds between weight shifts.
    public let weightInterval: ClosedRange<Double>
    /// Weight-shift horizontal offset as a fraction of body width.
    public let weightOffset: Double
    /// Weight-shift head tilt in radians (per unit lean).
    public let weightTilt: Double

    /// Magic pulse depth as a fraction of the base alpha; `0` disables it.
    public let magicPulse: Double

    public init(configuration: PetConfiguration, reduceMotion: Bool, includesEffects: Bool) {
        let personality = configuration.motionPersonality
        let earStyle = configuration.ears.earStyle
        let tailStyle = configuration.tail.tailStyle

        let ampScale = reduceMotion ? 0.25 : 1.0

        // MARK: Blink (not reduced by Reduce Motion)
        let sleepy = personality == .sleepy
        self.blinkInterval = sleepy ? (2.5 * 1.3)...(6.0 * 1.3) : 2.5...6.0
        self.blinkDuration = sleepy ? 0.24 : 0.16
        self.doubleBlinkChance = personality == .curious ? 0.30 : 0.15

        // MARK: Gaze
        self.gazeInterval = 3.0...8.0
        let gazeBase: Double
        switch personality {
        case .calm: gazeBase = 0.06
        case .curious, .lively: gazeBase = 0.14
        default: gazeBase = 0.10
        }
        self.gazeRadius = gazeBase * ampScale

        // MARK: Ear twitch
        self.earInterval = 5.0...12.0
        let earBase: Double
        switch earStyle {
        case .rounded: earBase = 0.10
        case .long: earBase = 0.12
        case .floppy: earBase = 0.06
        case .pointed: earBase = 0.14
        }
        self.earAmplitude = earBase * ampScale

        // MARK: Tail sway
        switch personality {
        case .calm: self.tailPeriod = 3.5
        case .curious: self.tailPeriod = 2.8
        case .playful: self.tailPeriod = 2.2
        case .lively: self.tailPeriod = 1.8
        case .sleepy: self.tailPeriod = 3.5
        }
        let tailStyleAmp: Double
        switch tailStyle {
        case .short: tailStyleAmp = 0.06
        case .long: tailStyleAmp = 0.12
        case .curled: tailStyleAmp = 0.08
        case .plume: tailStyleAmp = 0.10
        }
        let tailPersonality: Double
        switch personality {
        case .calm: tailPersonality = 0.7
        case .sleepy: tailPersonality = 0.6
        case .curious: tailPersonality = 1.0
        case .playful: tailPersonality = 1.1
        case .lively: tailPersonality = 1.2
        }
        self.tailAmplitude = tailStyleAmp * tailPersonality * ampScale

        // MARK: Weight shift
        self.weightInterval = 8.0...18.0
        let weightMultiplier = (personality == .calm || personality == .sleepy) ? 0.6 : 1.0
        self.weightOffset = 0.015 * weightMultiplier * ampScale
        self.weightTilt = 0.03 * weightMultiplier * ampScale

        // MARK: Magic
        let magicActive = includesEffects
            && !reduceMotion
            && configuration.details.magicalFeature != .none
        self.magicPulse = magicActive ? 0.25 : 0
    }
}

/// Drives the pet's secondary idle motions purely from elapsed time so it is
/// fully deterministic and testable headless (no `SKAction`, no wall clock, no
/// system RNG). Composer channels (ears, tail, head) receive additive offsets
/// under this controller's own sources; eye children, eyelids and the magic
/// node are written ABSOLUTELY from values captured at init, so nothing drifts.
///
/// - Important: `advance(by:)` never calls `composer.apply()`; the frame driver
///   (the scene) applies the composer once per frame after breathing's actions.
@MainActor
public final class SecondaryMotionController {
    public static let earSource: PetMotionSource = "earTwitch"
    public static let tailSource: PetMotionSource = "tailSway"
    public static let weightSource: PetMotionSource = "weightShift"

    private let rig: PetRig
    private let composer: PetMotionComposer
    private let configuration: PetConfiguration
    private let includesEffects: Bool

    public private(set) var profile: SecondaryMotionProfile
    public private(set) var elapsed: TimeInterval = 0

    // Cached geometry.
    private let bodyWidth: CGFloat
    private let eyeWidth: CGFloat

    // Captured absolute base values (root-local) for the non-composer nodes.
    private struct EyeNodes {
        let iris: SKNode
        let pupil: SKNode
        let catchlight: SKNode
        let irisBase: CGPoint
        let pupilBase: CGPoint
        let catchlightBase: CGPoint
    }
    private let leftEyeNodes: EyeNodes?
    private let rightEyeNodes: EyeNodes?
    private let magicAlphaBase: CGFloat
    private let magicRotationBase: CGFloat

    // Deterministic scheduler.
    private var rng: SplitMix64

    // Blink schedule.
    private var nextBlinkTime: Double = 0
    private var activeBlink: BlinkState?
    private struct BlinkState {
        var startTime: Double
        var duration: Double
        var isSecondOfDouble: Bool
        var scheduledDoubleFollow: Bool
    }

    // Gaze schedule.
    private var gazeFromOffset: CGVector = .zero
    private var gazeToOffset: CGVector = .zero
    private var gazeMoveStart: Double = 0
    private var nextGazeTime: Double = 0
    private var currentGazeOffset: CGVector = .zero
    private static let gazeMoveDuration: Double = 0.35

    // Ear schedule.
    private enum EarSide { case left, right, both }
    private var earTwitchStart: Double = -1000
    private var earTwitchSide: EarSide = .both
    private var nextEarTime: Double = 0
    private static let earTwitchDuration: Double = 0.28

    // Weight schedule.
    private var weightFromLean: Double = 0
    private var weightToLean: Double = 0
    private var weightMoveStart: Double = 0
    private var nextWeightTime: Double = 0
    private var currentLean: Double = 0
    private static let weightMoveDuration: Double = 0.8

    public init(
        rig: PetRig,
        composer: PetMotionComposer,
        configuration: PetConfiguration,
        reduceMotion: Bool,
        includesEffects: Bool
    ) {
        self.rig = rig
        self.composer = composer
        self.configuration = configuration
        self.includesEffects = includesEffects
        self.profile = SecondaryMotionProfile(
            configuration: configuration,
            reduceMotion: reduceMotion,
            includesEffects: includesEffects
        )

        self.bodyWidth = (rig.body.childNode(withName: "pet.body.base") as? SKSpriteNode)?.size.width ?? 440
        self.eyeWidth = (rig.leftEye as? SKSpriteNode)?.size.width ?? 150

        func eyeNodes(_ eye: SKNode) -> EyeNodes? {
            guard let name = eye.name,
                  let iris = eye.childNode(withName: name + ".iris"),
                  let pupil = eye.childNode(withName: name + ".pupil"),
                  let catchlight = eye.childNode(withName: name + ".catchlight")
            else { return nil }
            return EyeNodes(
                iris: iris, pupil: pupil, catchlight: catchlight,
                irisBase: iris.position, pupilBase: pupil.position,
                catchlightBase: catchlight.position
            )
        }
        self.leftEyeNodes = eyeNodes(rig.leftEye)
        self.rightEyeNodes = eyeNodes(rig.rightEye)
        self.magicAlphaBase = rig.magic?.alpha ?? 0
        self.magicRotationBase = rig.magic?.zRotation ?? 0

        // One deterministic stream seeded from the pet seed. Each channel draws
        // its first event with an independent initial offset so channels don't
        // start in sync, in a fixed order.
        self.rng = SplitMix64(seed: configuration.seed ^ 0xA11CE_5EED)

        // Fixed draw order at init: blink, gaze, ear, weight.
        self.nextBlinkTime = drawInterval(profile.blinkInterval) * unit()
        self.nextGazeTime = drawInterval(profile.gazeInterval) * unit()
        self.nextEarTime = drawInterval(profile.earInterval) * unit()
        self.nextWeightTime = drawInterval(profile.weightInterval) * unit()
    }

    // MARK: - Public API

    /// Advances internal schedules by `dt` (clamped to `0...0.1`), writes lids,
    /// eye children and the magic node directly, and sets composer offsets for
    /// ears, tail and head. Does NOT call `composer.apply()`.
    public func advance(by dt: TimeInterval) {
        let clamped = min(0.1, max(0, dt))
        elapsed += clamped

        updateBlink()
        updateGaze()
        updateEar()
        updateTail()
        updateWeight()
        updateMagic()
    }

    /// Rebuilds the profile with a new Reduce Motion setting. Amplitudes change
    /// immediately on the next `advance`; schedules continue uninterrupted.
    public func setReduceMotion(_ enabled: Bool) {
        profile = SecondaryMotionProfile(
            configuration: configuration,
            reduceMotion: enabled,
            includesEffects: includesEffects
        )
    }

    /// Clears this controller's composer sources, sets lids fully open, and
    /// returns eye children and the magic node to their captured base values.
    public func reset() {
        composer.clear(source: Self.earSource)
        composer.clear(source: Self.tailSource)
        composer.clear(source: Self.weightSource)

        rig.leftEyelid.alpha = 0
        rig.rightEyelid.alpha = 0

        if let e = leftEyeNodes {
            e.iris.position = e.irisBase
            e.pupil.position = e.pupilBase
            e.catchlight.position = e.catchlightBase
        }
        if let e = rightEyeNodes {
            e.iris.position = e.irisBase
            e.pupil.position = e.pupilBase
            e.catchlight.position = e.catchlightBase
        }
        if let magic = rig.magic {
            magic.alpha = magicAlphaBase
            magic.zRotation = magicRotationBase
        }
    }

    // MARK: - Blink

    private func updateBlink() {
        // Start a scheduled blink.
        if activeBlink == nil, elapsed >= nextBlinkTime {
            let makesDouble = unit() < profile.doubleBlinkChance
            activeBlink = BlinkState(
                startTime: elapsed,
                duration: profile.blinkDuration,
                isSecondOfDouble: false,
                scheduledDoubleFollow: makesDouble
            )
        }

        guard let blink = activeBlink else {
            // Ensure lids are open when idle.
            rig.leftEyelid.alpha = 0
            rig.rightEyelid.alpha = 0
            return
        }

        let elapsedInBlink = elapsed - blink.startTime
        if elapsedInBlink >= blink.duration {
            // Blink finished.
            rig.leftEyelid.alpha = 0
            rig.rightEyelid.alpha = 0
            if blink.scheduledDoubleFollow && !blink.isSecondOfDouble {
                // Schedule the second blink 0.08 s after this one ends. Lids
                // stay open until its start time is reached on a later frame.
                activeBlink = BlinkState(
                    startTime: blink.startTime + blink.duration + 0.08,
                    duration: blink.duration,
                    isSecondOfDouble: true,
                    scheduledDoubleFollow: false
                )
                return
            } else {
                activeBlink = nil
                // Schedule the next regular blink.
                nextBlinkTime = elapsed + drawInterval(profile.blinkInterval)
                return
            }
        }

        // Waiting for a scheduled second blink to begin.
        if elapsed < blink.startTime {
            rig.leftEyelid.alpha = 0
            rig.rightEyelid.alpha = 0
            return
        }

        let alpha = Self.blinkAlpha(progress: elapsedInBlink / blink.duration)
        rig.leftEyelid.alpha = CGFloat(alpha)
        rig.rightEyelid.alpha = CGFloat(alpha)
    }

    /// Lid alpha over the blink: close over the first 40% (easeIn), hold 10%,
    /// open over the last 50% (easeOut). Reaches 1 at the top of the close.
    static func blinkAlpha(progress p: Double) -> Double {
        let x = min(1, max(0, p))
        if x < 0.40 {
            let t = x / 0.40
            return easeIn(t)
        } else if x < 0.50 {
            return 1
        } else {
            let t = (x - 0.50) / 0.50
            return 1 - easeOut(t)
        }
    }

    private static func easeIn(_ t: Double) -> Double { t * t }
    private static func easeOut(_ t: Double) -> Double { 1 - (1 - t) * (1 - t) }

    // MARK: - Gaze

    private func updateGaze() {
        if elapsed >= nextGazeTime {
            gazeFromOffset = currentGazeOffset
            gazeToOffset = drawGazeTarget()
            gazeMoveStart = elapsed
            nextGazeTime = elapsed + drawInterval(profile.gazeInterval)
        }

        let moveElapsed = elapsed - gazeMoveStart
        let offset: CGVector
        if moveElapsed >= Self.gazeMoveDuration {
            offset = gazeToOffset
        } else {
            let t = Self.easeInOut(moveElapsed / Self.gazeMoveDuration)
            offset = CGVector(
                dx: gazeFromOffset.dx + (gazeToOffset.dx - gazeFromOffset.dx) * CGFloat(t),
                dy: gazeFromOffset.dy + (gazeToOffset.dy - gazeFromOffset.dy) * CGFloat(t)
            )
        }
        currentGazeOffset = offset

        writeGaze(offset, to: leftEyeNodes)
        writeGaze(offset, to: rightEyeNodes)
    }

    private func writeGaze(_ offset: CGVector, to eye: EyeNodes?) {
        guard let e = eye else { return }
        e.iris.position = CGPoint(x: e.irisBase.x + offset.dx, y: e.irisBase.y + offset.dy)
        e.pupil.position = CGPoint(x: e.pupilBase.x + offset.dx, y: e.pupilBase.y + offset.dy)
        e.catchlight.position = CGPoint(
            x: e.catchlightBase.x + offset.dx * 0.3,
            y: e.catchlightBase.y + offset.dy * 0.3
        )
    }

    private func drawGazeTarget() -> CGVector {
        let radius = profile.gazeRadius * Double(eyeWidth)
        // Uniform direction, uniform magnitude within the disc (sqrt for area,
        // but here bounded by radius is sufficient — use magnitude <= radius).
        let angle = unit() * 2 * Double.pi
        let mag = radius * unit().squareRoot()
        return CGVector(dx: CGFloat(cos(angle) * mag), dy: CGFloat(sin(angle) * mag))
    }

    // MARK: - Ear

    private func updateEar() {
        if elapsed >= nextEarTime {
            earTwitchStart = elapsed
            earTwitchSide = drawEarSide()
            nextEarTime = elapsed + drawInterval(profile.earInterval)
        }

        let t = elapsed - earTwitchStart
        let offset: Double
        if t >= 0 && t <= Self.earTwitchDuration {
            offset = profile.earAmplitude
                * sin(Double.pi * t / Self.earTwitchDuration)
                * (1 - t / Self.earTwitchDuration)
        } else {
            offset = 0
        }

        var leftRot = 0.0
        var rightRot = 0.0
        switch earTwitchSide {
        case .left: leftRot = offset
        case .right: rightRot = offset
        case .both: leftRot = offset; rightRot = offset
        }

        setEar(leftRot, channel: .leftEar)
        // Right ear is mirrored (xScale -1): apply -offset.
        setEar(-rightRot, channel: .rightEar)
    }

    private func setEar(_ rotation: Double, channel: PetMotionChannel) {
        if rotation == 0 {
            composer.set(.identity, for: channel, from: Self.earSource)
        } else {
            composer.set(PetMotionOffset(zRotation: CGFloat(rotation)), for: channel, from: Self.earSource)
        }
    }

    private func drawEarSide() -> EarSide {
        let r = next() % 3
        switch r {
        case 0: return .left
        case 1: return .right
        default: return .both
        }
    }

    // MARK: - Tail

    private func updateTail() {
        let amp = profile.tailAmplitude
        let rot = amp * sin(2 * Double.pi * elapsed / profile.tailPeriod)
        if rot == 0 {
            composer.set(.identity, for: .tail, from: Self.tailSource)
        } else {
            composer.set(PetMotionOffset(zRotation: CGFloat(rot)), for: .tail, from: Self.tailSource)
        }
    }

    // MARK: - Weight

    private func updateWeight() {
        if elapsed >= nextWeightTime {
            weightFromLean = currentLean
            weightToLean = drawLean()
            weightMoveStart = elapsed
            nextWeightTime = elapsed + drawInterval(profile.weightInterval)
        }

        let moveElapsed = elapsed - weightMoveStart
        let lean: Double
        if moveElapsed >= Self.weightMoveDuration {
            lean = weightToLean
        } else {
            let t = Self.easeInOut(moveElapsed / Self.weightMoveDuration)
            lean = weightFromLean + (weightToLean - weightFromLean) * t
        }
        currentLean = lean

        let dx = lean * profile.weightOffset * Double(bodyWidth)
        let rot = -lean * profile.weightTilt
        composer.set(
            PetMotionOffset(position: CGVector(dx: CGFloat(dx), dy: 0), zRotation: CGFloat(rot)),
            for: .head,
            from: Self.weightSource
        )
    }

    private func drawLean() -> Double {
        // In [-1, 1].
        unit() * 2 - 1
    }

    // MARK: - Magic

    private func updateMagic() {
        guard let magic = rig.magic else { return }
        if profile.magicPulse == 0 {
            magic.alpha = magicAlphaBase
            magic.zRotation = magicRotationBase
            return
        }
        magic.alpha = magicAlphaBase * CGFloat(1 + profile.magicPulse * sin(2 * Double.pi * elapsed / 4.0))
        if configuration.details.magicalFeature == .orbitingLight {
            let rot = Double(magicRotationBase) + 0.25 * elapsed
            magic.zRotation = CGFloat(rot.truncatingRemainder(dividingBy: 2 * Double.pi))
        } else {
            magic.zRotation = magicRotationBase
        }
    }

    // MARK: - RNG helpers

    private func next() -> UInt64 { rng.next() }

    /// A uniform Double in `[0, 1)` from the internal stream.
    private func unit() -> Double {
        Double(rng.next() >> 11) / 9_007_199_254_740_992
    }

    /// Draws a value uniformly inside `range`.
    private func drawInterval(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + unit() * (range.upperBound - range.lowerBound)
    }

    private static func easeInOut(_ x: Double) -> Double {
        let t = min(1, max(0, x))
        return t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
    }
}
