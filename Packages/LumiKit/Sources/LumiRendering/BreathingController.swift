import Foundation
import CoreGraphics
import SpriteKit
import LumiCore

/// Drives one pet rig's resting breath. Instead of writing node transforms
/// directly, it contributes additive offsets to a shared ``PetMotionComposer``
/// under a stable source key. This lets other controllers (ear twitch, tail
/// sway, gaze, blink, weight shift) animate the same rig concurrently without
/// overwriting each other — the composer recomputes every channel absolutely
/// from `rig.base` plus the sum of all sources' offsets on each `apply()`, so
/// motion composes additively and can never accumulate drift.
@MainActor
public final class BreathingController {
    public static let actionKey = "pet.breathing"

    /// The source key under which breathing contributes offsets.
    public static let source: PetMotionSource = "breathing"

    private let rig: PetRig
    private let composer: PetMotionComposer
    public private(set) var profile: BreathingProfile

    /// Body sprite height (points) cached at init, used to convert fractional
    /// rises into points. Falls back to 380 if the base sprite is unavailable.
    private let bodyHeight: CGFloat

    public init(rig: PetRig, composer: PetMotionComposer, profile: BreathingProfile) {
        self.rig = rig
        self.composer = composer
        self.profile = profile
        self.bodyHeight = (rig.body.childNode(withName: "//pet.body.base") as? SKSpriteNode)?.size.height ?? 380
    }

    /// Live-vs-restart semantics: an amplitude change applies on the next frame
    /// (the next `apply(phase:)`), because amplitudes are read per frame.
    /// A *duration* change only takes effect after restarting (`stop` + `start`,
    /// or ``restart(on:variationSeed:)``), because the running `SKAction`'s
    /// cycle durations are baked in when the action is built.
    public func setProfile(_ profile: BreathingProfile) {
        self.profile = profile
    }

    /// Computes the breath offsets for a normalized `phase ∈ [0, 1]` and writes
    /// them into the composer under ``source``. Does **not** call
    /// `composer.apply()` and never writes node transforms directly; the caller
    /// (frame callback) is responsible for calling `composer.apply()` afterward.
    public func apply(phase: Double) {
        let s = BreathingCurve.sample(phase: phase)

        // All-zero sample => breathing contributes nothing this frame. Clearing
        // the source lets the composer write those channels exactly as base.
        if s == .zero {
            composer.clear(source: Self.source)
            return
        }

        let h = bodyHeight

        // Abdomen scales around its own center; position untouched.
        composer.set(
            PetMotionOffset(
                xScale: 1 + profile.abdomenXAmplitude * CGFloat(s.abdomen),
                yScale: 1 + profile.abdomenYAmplitude * CGFloat(s.abdomen)
            ),
            for: .abdomen,
            from: Self.source
        )

        // Chest rises vertically only (delayed after abdomen); scale unchanged.
        composer.set(
            PetMotionOffset(position: CGVector(dx: 0, dy: profile.chestRise * h * CGFloat(s.chest))),
            for: .chest,
            from: Self.source
        )

        // Head follows vertically only; NO head scale change, rotation preserved.
        composer.set(
            PetMotionOffset(position: CGVector(dx: 0, dy: profile.headRise * h * CGFloat(s.head))),
            for: .head,
            from: Self.source
        )

        // Secondary (delayed fur/tail) motion — only when enabled.
        if profile.secondaryAmplitude > 0 {
            let secondary = profile.secondaryAmplitude
            composer.set(
                PetMotionOffset(position: CGVector(dx: 0, dy: secondary * h * 0.5 * CGFloat(s.secondary))),
                for: .chestTuft,
                from: Self.source
            )
            composer.set(
                PetMotionOffset(position: CGVector(dx: 0, dy: secondary * h * 0.3 * CGFloat(s.secondary))),
                for: .leftCheek,
                from: Self.source
            )
            composer.set(
                PetMotionOffset(position: CGVector(dx: 0, dy: secondary * h * 0.3 * CGFloat(s.secondary))),
                for: .rightCheek,
                from: Self.source
            )
            // Tail tip sway: ~1.7° at normal amplitude (0.03 rad scaled by ratio).
            let tailSway = CGFloat(0.03) * (secondary / 0.006) * CGFloat(s.secondary)
            composer.set(PetMotionOffset(zRotation: tailSway), for: .tail, from: Self.source)
        }
    }

    /// Builds a repeating breath action of 3–6 cycles whose durations vary by at
    /// most ±5% (deterministic in `variationSeed`); duration is constant within a
    /// cycle. Between cycles the breathing source is cleared and the composer
    /// re-applied, guaranteeing breathing's own contribution returns to identity
    /// at each cycle boundary without disturbing other sources.
    public func makeAction(variationSeed: UInt64 = 0) -> SKAction {
        var rng = SplitMix64(seed: variationSeed)

        // Choose N in 3...6.
        let cycleCount = 3 + Int(rng.next() % 4)

        let restore = SKAction.run { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.composer.clear(source: Self.source)
                self.composer.apply()
            }
        }

        var steps: [SKAction] = []
        for _ in 0..<cycleCount {
            // ±5% variation, deterministic per cycle.
            let unit = Double(rng.next() >> 11) / 9_007_199_254_740_992 // [0, 1)
            let factor = 0.95 + unit * 0.10 // [0.95, 1.05)
            let duration = profile.duration * factor
            steps.append(makeCycle(duration: duration))
            steps.append(restore)
        }

        return SKAction.repeatForever(SKAction.sequence(steps))
    }

    private func makeCycle(duration: TimeInterval) -> SKAction {
        // `MainActor.assumeIsolated` is sound here because `SKAction` custom
        // callbacks run on the same thread that drives the scene — the main
        // thread — which is the actor this class is isolated to.
        SKAction.customAction(withDuration: duration) { [weak self] _, elapsed in
            MainActor.assumeIsolated {
                guard let self else { return }
                let phase = duration > 0 ? Double(elapsed) / duration : 1.0
                self.apply(phase: phase)
                self.composer.apply()
            }
        }
    }

    /// Runs the breath action on `node` (the rig root) keyed by ``actionKey``.
    /// Custom actions never move the host node, only the rig's inner nodes.
    public func start(on node: SKNode, variationSeed: UInt64 = 0) {
        node.run(makeAction(variationSeed: variationSeed), withKey: Self.actionKey)
    }

    /// Removes the breath action, clears breathing's offsets, and re-applies the
    /// composer. Other sources' contributions are preserved.
    public func stop(on node: SKNode) {
        node.removeAction(forKey: Self.actionKey)
        composer.clear(source: Self.source)
        composer.apply()
    }

    /// Convenience: stop then start with a fresh action so a changed
    /// `profile.duration` takes effect immediately.
    public func restart(on node: SKNode, variationSeed: UInt64 = 0) {
        stop(on: node)
        start(on: node, variationSeed: variationSeed)
    }
}
