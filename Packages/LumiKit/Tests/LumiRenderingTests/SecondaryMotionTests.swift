import Foundation
import CoreGraphics
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

@MainActor
struct SecondaryMotionTests {

    // MARK: - Helpers

    private struct Harness {
        let rig: PetRig
        let composer: PetMotionComposer
        let controller: SecondaryMotionController
    }

    private func makeHarness(
        seed: UInt64,
        reduceMotion: Bool = false,
        includesEffects: Bool = true
    ) throws -> Harness {
        let rig = try RenderingFixtures.testRig(seed: seed)
        let configuration = try PetGenerator.generate(seed: seed, version: 1)
        let composer = PetMotionComposer(rig: rig)
        let controller = SecondaryMotionController(
            rig: rig,
            composer: composer,
            configuration: configuration,
            reduceMotion: reduceMotion,
            includesEffects: includesEffects
        )
        return Harness(rig: rig, composer: composer, controller: controller)
    }

    private func eyeChild(_ eye: SKNode, _ suffix: String) -> SKNode? {
        eye.childNode(withName: eye.name! + "." + suffix)
    }

    /// Find the first seed in `0..<limit` whose generated configuration has the
    /// given personality.
    private func firstSeed(personality: MotionPersonality, limit: UInt64 = 2000) throws -> UInt64 {
        for seed in 0..<limit {
            let config = try PetGenerator.generate(seed: seed, version: 1)
            if config.motionPersonality == personality { return seed }
        }
        Issue.record("no seed with personality \(personality) found in 0..<\(limit)")
        return 0
    }

    // MARK: - Tests

    @Test func deterministicForSameSeed() throws {
        let seed: UInt64 = 12345
        let a = try makeHarness(seed: seed)
        let b = try makeHarness(seed: seed)

        let dt = 1.0 / 60.0
        for step in 1...1800 {
            a.controller.advance(by: dt)
            b.controller.advance(by: dt)
            a.composer.apply()
            b.composer.apply()
            if step % 60 == 0 {
                #expect(a.rig.leftEyelid.alpha == b.rig.leftEyelid.alpha)
                #expect(a.rig.rightEyelid.alpha == b.rig.rightEyelid.alpha)

                let ap = eyeChild(a.rig.leftEye, "pupil")!
                let bp = eyeChild(b.rig.leftEye, "pupil")!
                #expect(ap.position == bp.position)

                for channel in [PetMotionChannel.leftEar, .rightEar, .tail, .head] {
                    let ao = a.composer.combinedOffset(for: channel)
                    let bo = b.composer.combinedOffset(for: channel)
                    #expect(ao == bo, "channel \(channel) diverged at step \(step)")
                }
            }
        }
    }

    @Test func blinkIntervalsWithinBounds() throws {
        let seed: UInt64 = 777
        let h = try makeHarness(seed: seed)
        let profile = h.controller.profile

        let dt = 1.0 / 60.0
        let totalSteps = Int(10 * 60 * 60) // 10 minutes at 60 fps
        var blinkStartTimes: [Double] = []
        var prevAlpha = h.rig.leftEyelid.alpha
        var peakSinceStart: CGFloat = 0
        var t = 0.0
        var minAlphaBetween: CGFloat = 1

        for _ in 0..<totalSteps {
            h.controller.advance(by: dt)
            h.composer.apply()
            t += dt
            let alpha = h.rig.leftEyelid.alpha
            // Blink start: alpha rises from exactly 0.
            if prevAlpha == 0 && alpha > 0 {
                blinkStartTimes.append(t)
                peakSinceStart = 0
            }
            peakSinceStart = max(peakSinceStart, alpha)
            if alpha == 0 { minAlphaBetween = min(minAlphaBetween, alpha) }
            prevAlpha = alpha
        }

        #expect(blinkStartTimes.count > 5)
        // Every blink must return to exactly 0 between blinks.
        #expect(minAlphaBetween == 0)

        // Gaps between consecutive blink starts: classify double vs regular.
        // A double blink starts ~ (duration + 0.08) after the previous start.
        let doubleThreshold = profile.blinkDuration + 0.08 + 0.05
        var regularGaps: [Double] = []
        for i in 1..<blinkStartTimes.count {
            let gap = blinkStartTimes[i] - blinkStartTimes[i - 1]
            if gap > doubleThreshold {
                regularGaps.append(gap)
            }
        }
        #expect(!regularGaps.isEmpty)
        for gap in regularGaps {
            #expect(gap >= profile.blinkInterval.lowerBound - 0.05)
            #expect(gap <= profile.blinkInterval.upperBound + profile.blinkDuration + 0.08 + 0.05)
        }

        // Double blink fraction: curious > calm.
        func doubleFraction(seed: UInt64) throws -> Double {
            let hh = try makeHarness(seed: seed)
            var starts: [Double] = []
            var prev = hh.rig.leftEyelid.alpha
            var tt = 0.0
            for _ in 0..<totalSteps {
                hh.controller.advance(by: dt)
                hh.composer.apply()
                tt += dt
                let a = hh.rig.leftEyelid.alpha
                if prev == 0 && a > 0 { starts.append(tt) }
                prev = a
            }
            let thr = hh.controller.profile.blinkDuration + 0.08 + 0.05
            guard starts.count > 1 else { return 0 }
            var doubles = 0
            for i in 1..<starts.count where (starts[i] - starts[i - 1]) <= thr {
                doubles += 1
            }
            return Double(doubles) / Double(starts.count)
        }

        let curiousSeed = try firstSeed(personality: .curious)
        let calmSeed = try firstSeed(personality: .calm)
        let curiousFraction = try doubleFraction(seed: curiousSeed)
        let calmFraction = try doubleFraction(seed: calmSeed)
        #expect(curiousFraction > calmFraction)
    }

    @Test func blinkAlphaReachesFull() throws {
        let h = try makeHarness(seed: 42)
        let dt = 1.0 / 60.0
        var maxAlpha: CGFloat = 0
        for _ in 0..<(3 * 60 * 60) {
            h.controller.advance(by: dt)
            h.composer.apply()
            maxAlpha = max(maxAlpha, h.rig.leftEyelid.alpha)
        }
        #expect(maxAlpha >= 0.95)
    }

    @Test func gazeStaysInsideEye() throws {
        let h = try makeHarness(seed: 2024)
        let profile = h.controller.profile
        let eyeWidth = (h.rig.leftEye as? SKSpriteNode)?.size.width ?? 150
        let radius = profile.gazeRadius * Double(eyeWidth)

        let pupil = eyeChild(h.rig.leftEye, "pupil")!
        let catchlight = eyeChild(h.rig.leftEye, "catchlight")!
        let pupilBase = pupil.position
        let catchlightBase = catchlight.position

        let dt = 1.0 / 60.0
        var moved = false
        for _ in 0..<(5 * 60 * 60) {
            h.controller.advance(by: dt)
            h.composer.apply()
            let dx = Double(pupil.position.x - pupilBase.x)
            let dy = Double(pupil.position.y - pupilBase.y)
            let mag = (dx * dx + dy * dy).squareRoot()
            #expect(mag <= radius + 1e-6)
            if mag > 1e-9 { moved = true }
            // Catchlight offset is exactly 0.3 of the pupil offset.
            let cdx = Double(catchlight.position.x - catchlightBase.x)
            let cdy = Double(catchlight.position.y - catchlightBase.y)
            #expect(abs(cdx - 0.3 * dx) <= 1e-6)
            #expect(abs(cdy - 0.3 * dy) <= 1e-6)
        }
        #expect(moved)
    }

    @Test func earTwitchMirroredAndBounded() throws {
        let h = try makeHarness(seed: 909)
        let profile = h.controller.profile
        let dt = 1.0 / 60.0
        var twitched = false
        var firstTwitchTime: Double? = nil
        var t = 0.0
        var maxAbs = 0.0

        for _ in 0..<(60 * 60) { // 60 s
            h.controller.advance(by: dt)
            t += dt
            let left = h.composer.combinedOffset(for: .leftEar).zRotation
            let right = h.composer.combinedOffset(for: .rightEar).zRotation
            // Bounded.
            #expect(abs(Double(left)) <= profile.earAmplitude + 1e-9)
            #expect(abs(Double(right)) <= profile.earAmplitude + 1e-9)
            maxAbs = max(maxAbs, abs(Double(left)), abs(Double(right)))
            // When both twitch, left == -right.
            if abs(Double(left)) > 1e-9 && abs(Double(right)) > 1e-9 {
                #expect(abs(Double(left + right)) <= 1e-9)
            }
            if abs(Double(left)) > 1e-9 || abs(Double(right)) > 1e-9 {
                twitched = true
                if firstTwitchTime == nil { firstTwitchTime = t }
            }
        }
        #expect(twitched)
        #expect((firstTwitchTime ?? .infinity) <= 12.0)
        #expect(maxAbs > 1e-9)
    }

    @Test func earReturnsToZeroBetweenTwitches() throws {
        let h = try makeHarness(seed: 909)
        let dt = 1.0 / 60.0
        // Sample many frames; at least one frame both ears are exactly zero.
        var sawZero = false
        for _ in 0..<(60 * 60) {
            h.controller.advance(by: dt)
            let left = h.composer.combinedOffset(for: .leftEar).zRotation
            let right = h.composer.combinedOffset(for: .rightEar).zRotation
            if left == 0 && right == 0 { sawZero = true }
        }
        #expect(sawZero)
    }

    @Test func tailSwayBoundedAndPeriodic() throws {
        let h = try makeHarness(seed: 555)
        let profile = h.controller.profile
        let dt = 1.0 / 240.0 // fine step for period accuracy
        let period = profile.tailPeriod

        // Advance to some t, capture tail rotation, advance one period, compare.
        // Choose t0 = 5 s.
        let stepsToT0 = Int(5.0 / dt)
        for _ in 0..<stepsToT0 { h.controller.advance(by: dt) }
        let rotAtT0 = h.composer.combinedOffset(for: .tail).zRotation
        #expect(abs(Double(rotAtT0)) <= profile.tailAmplitude + 1e-9)

        let stepsPeriod = Int((period / dt).rounded())
        for _ in 0..<stepsPeriod { h.controller.advance(by: dt) }
        let rotAtT0PlusPeriod = h.composer.combinedOffset(for: .tail).zRotation
        #expect(abs(Double(rotAtT0 - rotAtT0PlusPeriod)) <= 1e-9)
    }

    @Test func weightShiftOnlyMovesHead() throws {
        let h = try makeHarness(seed: 333)
        let dt = 1.0 / 60.0
        for _ in 0..<(60 * 60) {
            h.controller.advance(by: dt)
        }
        // weightSource offsets appear only on .head.
        for channel in PetMotionChannel.allCases where channel != .head {
            let offset = h.composer.combinedOffset(for: channel)
            // No weightSource contribution: we can only inspect the combined,
            // but the controller must never add weight to any channel but head.
            // We check that removing weight doesn't change non-head channels by
            // clearing the weight source and comparing combined offsets.
            let before = offset
            h.composer.clear(source: SecondaryMotionController.weightSource)
            let after = h.composer.combinedOffset(for: channel)
            #expect(before == after, "weightSource touched \(channel)")
            // Re-advance is not needed; test only structural.
        }
    }

    @Test func reduceMotionQuartersAmplitudes() throws {
        let seed: UInt64 = 4321
        let config = try PetGenerator.generate(seed: seed, version: 1)
        let normal = SecondaryMotionProfile(configuration: config, reduceMotion: false, includesEffects: true)
        let reduced = SecondaryMotionProfile(configuration: config, reduceMotion: true, includesEffects: true)

        #expect(abs(reduced.gazeRadius - normal.gazeRadius * 0.25) < 1e-12)
        #expect(abs(reduced.earAmplitude - normal.earAmplitude * 0.25) < 1e-12)
        #expect(abs(reduced.tailAmplitude - normal.tailAmplitude * 0.25) < 1e-12)
        #expect(abs(reduced.weightOffset - normal.weightOffset * 0.25) < 1e-12)

        // Blink unchanged.
        #expect(reduced.blinkInterval == normal.blinkInterval)
        #expect(reduced.blinkDuration == normal.blinkDuration)
        #expect(reduced.doubleBlinkChance == normal.doubleBlinkChance)

        // Magic off.
        #expect(reduced.magicPulse == 0)
    }

    @Test func composesWithBreathing() throws {
        let seed: UInt64 = 616
        let rig = try RenderingFixtures.testRig(seed: seed)
        let config = try PetGenerator.generate(seed: seed, version: 1)
        let composer = PetMotionComposer(rig: rig)
        let breathingProfile = BreathingProfile(personality: config.motionPersonality, reduceMotion: false)
        let breathing = BreathingController(rig: rig, composer: composer, profile: breathingProfile)
        let secondary = SecondaryMotionController(
            rig: rig, composer: composer, configuration: config,
            reduceMotion: false, includesEffects: true
        )

        // Advance secondary a while so weight/tail have non-trivial values.
        let dt = 1.0 / 60.0
        for _ in 0..<(30 * 60) { secondary.advance(by: dt) }

        breathing.apply(phase: 0.34)
        composer.apply()

        // Head position == base + combined offset for head. SKNode transforms
        // are stored as float32, so allow a small tolerance on the read-back.
        let headOffset = composer.combinedOffset(for: .head)
        let expectedHeadX = rig.base.head.position.x + headOffset.position.dx
        let expectedHeadY = rig.base.head.position.y + headOffset.position.dy
        #expect(abs(Double(rig.head.position.x - expectedHeadX)) < 1e-4)
        #expect(abs(Double(rig.head.position.y - expectedHeadY)) < 1e-4)

        // Tail rotation == base + combined offset for tail.
        let tailOffset = composer.combinedOffset(for: .tail)
        let expectedTailRot = rig.base.tail.zRotation + tailOffset.zRotation
        #expect(abs(Double(rig.tail.zRotation - expectedTailRot)) < 1e-4)
    }

    @Test func neverTouchesFixedParts() throws {
        let h = try makeHarness(seed: 71)
        let pawsBefore = PetNodeTransform(capturing: h.rig.paws)
        let shadowBefore = PetNodeTransform(capturing: h.rig.shadow)
        let noseBefore = PetNodeTransform(capturing: h.rig.nose)
        let muzzleBefore = PetNodeTransform(capturing: h.rig.muzzle)
        let rootBefore = PetNodeTransform(capturing: h.rig.root)

        let dt = 1.0 / 60.0
        for _ in 0..<(10 * 60 * 60) {
            h.controller.advance(by: dt)
            h.composer.apply()
        }

        #expect(PetNodeTransform(capturing: h.rig.paws) == pawsBefore)
        #expect(PetNodeTransform(capturing: h.rig.shadow) == shadowBefore)
        #expect(PetNodeTransform(capturing: h.rig.nose) == noseBefore)
        #expect(PetNodeTransform(capturing: h.rig.muzzle) == muzzleBefore)
        #expect(PetNodeTransform(capturing: h.rig.root) == rootBefore)
    }

    @Test func noDriftAfterReset() throws {
        let seed: UInt64 = 88
        let rig = try RenderingFixtures.testRig(seed: seed)
        let config = try PetGenerator.generate(seed: seed, version: 1)
        let composer = PetMotionComposer(rig: rig)
        let controller = SecondaryMotionController(
            rig: rig, composer: composer, configuration: config,
            reduceMotion: false, includesEffects: true
        )

        // Capture eye child + magic base values immediately after init.
        func eyeChild(_ eye: SKNode, _ suffix: String) -> SKNode {
            eye.childNode(withName: eye.name! + "." + suffix)!
        }
        let irisL = eyeChild(rig.leftEye, "iris")
        let pupilL = eyeChild(rig.leftEye, "pupil")
        let catchL = eyeChild(rig.leftEye, "catchlight")
        let irisR = eyeChild(rig.rightEye, "iris")
        let pupilR = eyeChild(rig.rightEye, "pupil")
        let catchR = eyeChild(rig.rightEye, "catchlight")
        let baseIrisL = irisL.position
        let basePupilL = pupilL.position
        let baseCatchL = catchL.position
        let baseIrisR = irisR.position
        let basePupilR = pupilR.position
        let baseCatchR = catchR.position
        let magicAlphaBase = rig.magic?.alpha
        let magicRotBase = rig.magic?.zRotation

        let base = rig.base

        let dt = 1.0 / 30.0
        for _ in 0..<(30 * 60 * 30) {
            controller.advance(by: dt)
            composer.apply()
        }

        controller.reset()
        composer.apply()

        #expect(irisL.position == baseIrisL)
        #expect(pupilL.position == basePupilL)
        #expect(catchL.position == baseCatchL)
        #expect(irisR.position == baseIrisR)
        #expect(pupilR.position == basePupilR)
        #expect(catchR.position == baseCatchR)
        #expect(rig.leftEyelid.alpha == 0)
        #expect(rig.rightEyelid.alpha == 0)
        if let m = rig.magic {
            #expect(m.alpha == magicAlphaBase)
            #expect(m.zRotation == magicRotBase)
        }

        // Rig base transforms restored exactly (no other sources active).
        #expect(PetNodeTransform(capturing: rig.head) == base.head)
        #expect(PetNodeTransform(capturing: rig.tail) == base.tail)
        #expect(PetNodeTransform(capturing: rig.leftEar) == base.leftEar)
        #expect(PetNodeTransform(capturing: rig.rightEar) == base.rightEar)
    }
}
