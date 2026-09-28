import Foundation
import CoreGraphics
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

// MARK: - Profile tests (no rig needed)

struct BreathingProfileTests {
    @Test func profileDurationsInAnimalRange() {
        let expected: [MotionPersonality: TimeInterval] = [
            .calm: 3.6, .curious: 3.1, .playful: 2.8, .lively: 2.4, .sleepy: 4.0,
        ]
        for personality in MotionPersonality.allCases {
            let profile = BreathingProfile(personality: personality, reduceMotion: false)
            #expect(profile.duration >= 2.4 && profile.duration <= 4.0)
            #expect(profile.duration == expected[personality])
        }
        let shareSum = BreathingProfile.inhaleShare
            + BreathingProfile.pauseShare
            + BreathingProfile.exhaleShare
            + BreathingProfile.restShare
        #expect(abs(shareSum - 1.0) < 1e-12)
    }

    @Test func reduceMotionScalesEveryAmplitudeToFortyPercent() {
        for personality in MotionPersonality.allCases {
            let normal = BreathingProfile(personality: personality, reduceMotion: false)
            let reduced = BreathingProfile(personality: personality, reduceMotion: true)
            #expect(abs(Double(reduced.abdomenXAmplitude - normal.abdomenXAmplitude * 0.4)) < 1e-12)
            #expect(abs(Double(reduced.abdomenYAmplitude - normal.abdomenYAmplitude * 0.4)) < 1e-12)
            #expect(abs(Double(reduced.chestRise - normal.chestRise * 0.4)) < 1e-12)
            #expect(abs(Double(reduced.headRise - normal.headRise * 0.4)) < 1e-12)
            #expect(abs(Double(reduced.secondaryAmplitude - normal.secondaryAmplitude * 0.4)) < 1e-12)
            // Duration is unchanged by reduce motion.
            #expect(reduced.duration == normal.duration)
        }
    }

    @Test func watchProfileDisablesSecondaryMotion() {
        let watch = BreathingProfile(personality: .calm, reduceMotion: false, includesSecondaryMotion: false)
        #expect(watch.secondaryAmplitude == 0)
        // Primary channels still present.
        #expect(watch.abdomenXAmplitude > 0)
        #expect(watch.chestRise > 0)
        #expect(watch.headRise > 0)
    }
}

// MARK: - Curve tests (pure)

struct BreathingCurveTests {
    @Test func curveIsZeroAtCycleBoundaries() {
        for p in [0.0, 1.0, 0.80, 0.9] {
            let s = BreathingCurve.sample(phase: p)
            #expect(s.abdomen == 0)
            #expect(s.chest == 0)
            #expect(s.head == 0)
            #expect(s.secondary == 0)
        }
        for p in [Double.nan, -1.0, 2.0] {
            let s = BreathingCurve.sample(phase: p)
            #expect(s.abdomen == 0)
            #expect(s.chest == 0)
            #expect(s.head == 0)
            #expect(s.secondary == 0)
        }
    }

    @Test func curvePhaseShape() {
        // Abdomen leads chest leads head at p = 0.16 (mid-inhale).
        let mid = BreathingCurve.sample(phase: 0.16)
        #expect(mid.abdomen > mid.chest)
        #expect(mid.chest > mid.head)

        // All fully expanded during the pause.
        let pause = BreathingCurve.sample(phase: 0.34)
        #expect(pause.abdomen == 1)
        #expect(pause.chest == 1)
        #expect(pause.head == 1)
        #expect(pause.secondary == 1)

        // Fur lags on exhale: secondary trails behind the body settling.
        let exhale = BreathingCurve.sample(phase: 0.5)
        #expect(exhale.secondary > exhale.chest)
    }

    @Test func curveIsAsymmetric() {
        // Inhale: abdomen goes 0 -> 0.5. Exhale: abdomen goes 1 -> 0.5.
        // Find the phase at which abdomen crosses 0.5 on the way up.
        func firstPhase(where predicate: (Double) -> Bool, in range: ClosedRange<Double>) -> Double {
            let steps = 100_000
            for i in 0...steps {
                let p = range.lowerBound + (range.upperBound - range.lowerBound) * Double(i) / Double(steps)
                if predicate(BreathingCurve.sample(phase: p).abdomen) { return p }
            }
            return range.upperBound
        }
        // Inhale spans [0, 0.32]; find where abdomen first >= 0.5.
        let inhaleCross = firstPhase(where: { $0 >= 0.5 }, in: 0.0...0.32)
        let inhaleHalfTime = inhaleCross - 0.0
        // Exhale spans [0.36, 0.80]; find where abdomen first <= 0.5.
        let exhaleCross = firstPhase(where: { $0 <= 0.5 }, in: 0.36...0.80)
        let exhaleHalfTime = exhaleCross - 0.36
        #expect(inhaleHalfTime < exhaleHalfTime)
    }
}

// MARK: - Controller tests (rig needed)

@MainActor
struct BreathingControllerTests {
    /// Snapshot of every node's transform, keyed by node identity.
    private func snapshot(_ root: SKNode) -> [ObjectIdentifier: PetNodeTransform] {
        var map: [ObjectIdentifier: PetNodeTransform] = [:]
        func walk(_ node: SKNode) {
            map[ObjectIdentifier(node)] = PetNodeTransform(capturing: node)
            for child in node.children { walk(child) }
        }
        walk(root)
        return map
    }

    private func bodyHeight(of rig: PetRig) -> CGFloat {
        (rig.body.childNode(withName: "pet.body.base") as? SKSpriteNode)?.size.height ?? 380
    }

    @Test func applyAtPeakChangesOnlyAllowedNodes() throws {
        let allowedNames: Set<String> = [
            "pet.abdomen", "pet.chest", "pet.head",
            "pet.chest.tuft", "pet.cheek.left", "pet.cheek.right", "pet.tail",
        ]
        for seed in Array(RenderingFixtures.referenceSeeds.prefix(5)) {
            let rig = try RenderingFixtures.testRig(seed: seed)
            let composer = PetMotionComposer(rig: rig)
            let profile = BreathingProfile(personality: .calm, reduceMotion: false)
            let controller = BreathingController(rig: rig, composer: composer, profile: profile)

            let before = snapshot(rig.root)
            controller.apply(phase: 0.34)
            composer.apply()
            let after = snapshot(rig.root)

            func node(_ id: ObjectIdentifier) -> SKNode? {
                var result: SKNode?
                func walk(_ n: SKNode) {
                    if ObjectIdentifier(n) == id { result = n }
                    for c in n.children { walk(c) }
                }
                walk(rig.root)
                return result
            }

            for (id, beforeT) in before {
                let afterT = after[id]!
                if beforeT != afterT {
                    let name = node(id)?.name ?? "<unnamed>"
                    #expect(allowedNames.contains(name), "unexpected node changed: \(name)")
                }
            }

            // Explicitly-still nodes never change.
            #expect(PetNodeTransform(capturing: rig.paws) == before[ObjectIdentifier(rig.paws)])
            #expect(PetNodeTransform(capturing: rig.shadow) == before[ObjectIdentifier(rig.shadow)])
            #expect(PetNodeTransform(capturing: rig.root) == before[ObjectIdentifier(rig.root)])
            #expect(PetNodeTransform(capturing: rig.leftEye) == before[ObjectIdentifier(rig.leftEye)])
            #expect(PetNodeTransform(capturing: rig.rightEye) == before[ObjectIdentifier(rig.rightEye)])
            #expect(PetNodeTransform(capturing: rig.nose) == before[ObjectIdentifier(rig.nose)])
            #expect(PetNodeTransform(capturing: rig.muzzle) == before[ObjectIdentifier(rig.muzzle)])
            #expect(PetNodeTransform(capturing: rig.leftEyelid) == before[ObjectIdentifier(rig.leftEyelid)])
            #expect(PetNodeTransform(capturing: rig.rightEyelid) == before[ObjectIdentifier(rig.rightEyelid)])

            // Head scale never changes.
            #expect(rig.head.xScale == before[ObjectIdentifier(rig.head)]!.xScale)
            #expect(rig.head.yScale == before[ObjectIdentifier(rig.head)]!.yScale)
        }
    }

    @Test func applyAtPeakAmplitudesInSpecRange() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let profile = BreathingProfile(personality: .calm, reduceMotion: false)
        let controller = BreathingController(rig: rig, composer: composer, profile: profile)
        let h = bodyHeight(of: rig)

        controller.apply(phase: 0.34)
        composer.apply()

        let xRatio = rig.abdomen.xScale / rig.base.abdomen.xScale
        let yRatio = rig.abdomen.yScale / rig.base.abdomen.yScale
        #expect(xRatio >= 1.035 && xRatio <= 1.060)
        #expect(yRatio >= 1.026 && yRatio <= 1.045)

        let chestRise = (rig.chest.position.y - rig.base.chest.position.y) / h
        #expect(chestRise >= 0.022 && chestRise <= 0.036)

        let headRise = (rig.head.position.y - rig.base.head.position.y) / h
        #expect(headRise >= 0.014 && headRise <= 0.024)
    }

    @Test func completedCycleRestoresExactBase() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let profile = BreathingProfile(personality: .calm, reduceMotion: false)
        let controller = BreathingController(rig: rig, composer: composer, profile: profile)
        let base = rig.base

        controller.apply(phase: 0.34)
        composer.apply()
        controller.apply(phase: 1.0)
        composer.apply()

        #expect(PetNodeTransform(capturing: rig.abdomen) == base.abdomen)
        #expect(PetNodeTransform(capturing: rig.chest) == base.chest)
        #expect(PetNodeTransform(capturing: rig.head) == base.head)
        #expect(PetNodeTransform(capturing: rig.tail) == base.tail)
        if let t = base.chestTuft, let n = rig.chestTuft {
            #expect(PetNodeTransform(capturing: n) == t)
        }
        if let t = base.leftCheek, let n = rig.leftCheek {
            #expect(PetNodeTransform(capturing: n) == t)
        }
        if let t = base.rightCheek, let n = rig.rightCheek {
            #expect(PetNodeTransform(capturing: n) == t)
        }
    }

    @Test func noDriftOverThirtyThousandSamples() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let profile = BreathingProfile(personality: .calm, reduceMotion: false)
        let controller = BreathingController(rig: rig, composer: composer, profile: profile)
        let base = rig.base

        for i in 0..<30_000 {
            controller.apply(phase: Double(i % 1000) / 1000.0)
            composer.apply()
            if i % 1000 == 0 { controller.apply(phase: 1.0); composer.apply() }
        }
        controller.apply(phase: 1.0)
        composer.apply()

        #expect(PetNodeTransform(capturing: rig.abdomen) == base.abdomen)
        #expect(PetNodeTransform(capturing: rig.chest) == base.chest)
        #expect(PetNodeTransform(capturing: rig.head) == base.head)
        #expect(PetNodeTransform(capturing: rig.tail) == base.tail)
    }

    @Test func watchProfileLeavesSecondaryNodesStill() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let profile = BreathingProfile(personality: .calm, reduceMotion: false, includesSecondaryMotion: false)
        let controller = BreathingController(rig: rig, composer: composer, profile: profile)

        let tailBefore = PetNodeTransform(capturing: rig.tail)
        let tuftBefore = rig.chestTuft.map(PetNodeTransform.init(capturing:))
        let leftCheekBefore = rig.leftCheek.map(PetNodeTransform.init(capturing:))
        let rightCheekBefore = rig.rightCheek.map(PetNodeTransform.init(capturing:))

        controller.apply(phase: 0.5)
        composer.apply()

        #expect(PetNodeTransform(capturing: rig.tail) == tailBefore)
        if let before = tuftBefore, let n = rig.chestTuft {
            #expect(PetNodeTransform(capturing: n) == before)
        }
        if let before = leftCheekBefore, let n = rig.leftCheek {
            #expect(PetNodeTransform(capturing: n) == before)
        }
        if let before = rightCheekBefore, let n = rig.rightCheek {
            #expect(PetNodeTransform(capturing: n) == before)
        }
    }

    @Test func actionIsKeyedAndRepeats() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let profile = BreathingProfile(personality: .calm, reduceMotion: false)
        let controller = BreathingController(rig: rig, composer: composer, profile: profile)
        let base = rig.base

        controller.start(on: rig.root)
        #expect(rig.root.action(forKey: BreathingController.actionKey) != nil)

        controller.stop(on: rig.root)
        #expect(rig.root.action(forKey: BreathingController.actionKey) == nil)
        #expect(PetNodeTransform(capturing: rig.abdomen) == base.abdomen)
        #expect(PetNodeTransform(capturing: rig.chest) == base.chest)
        #expect(PetNodeTransform(capturing: rig.head) == base.head)
    }

    // MARK: - Co-tenancy regression tests

    /// Breathing must never overwrite another source's contribution on shared
    /// channels; at rest its own contribution is exactly zero.
    @Test func breathingDoesNotStompOtherSources() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let profile = BreathingProfile(personality: .calm, reduceMotion: false)
        let controller = BreathingController(rig: rig, composer: composer, profile: profile)
        let base = rig.base

        // Another source contributes to the tail and to the left ear.
        composer.set(PetMotionOffset(zRotation: 0.2), for: .tail, from: "tailSway")
        composer.set(PetMotionOffset(zRotation: 0.15), for: .leftEar, from: "earTwitch")

        // Rest phase: breathing contributes zero to everything.
        controller.apply(phase: 0.9)
        composer.apply()
        // Node transforms are float32; breathing's own contribution is exactly
        // zero at rest (it clears its source), so only the co-tenant remains.
        #expect(composer.combinedOffset(for: .tail) == PetMotionOffset(zRotation: 0.2))
        #expect(composer.combinedOffset(for: .leftEar) == PetMotionOffset(zRotation: 0.15))
        #expect(abs(Double(rig.tail.zRotation - (base.tail.zRotation + 0.2))) < 1e-6)
        #expect(abs(Double(rig.leftEar.zRotation - (base.leftEar.zRotation + 0.15))) < 1e-6)

        // Active phase: tail gets breathing's tail offset ADDED on top of tailSway.
        controller.apply(phase: 0.5)
        composer.apply()
        // Expected breathing tail contribution, computed the same way the controller does.
        let s = BreathingCurve.sample(phase: 0.5)
        let breathingTail = CGFloat(0.03) * (profile.secondaryAmplitude / 0.006) * CGFloat(s.secondary)
        // Composer combines to double precision.
        #expect(abs(Double(composer.combinedOffset(for: .tail).zRotation - Double(0.2 + breathingTail))) < 1e-9)
        #expect(abs(Double(rig.tail.zRotation - (base.tail.zRotation + 0.2 + breathingTail))) < 1e-6)
        // Breathing never touches the ear at any phase.
        #expect(composer.combinedOffset(for: .leftEar) == PetMotionOffset(zRotation: 0.15))
        #expect(abs(Double(rig.leftEar.zRotation - (base.leftEar.zRotation + 0.15))) < 1e-6)
    }

    /// Stopping breathing clears only its own source; co-tenants survive.
    @Test func breathingStopKeepsOtherSources() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let profile = BreathingProfile(personality: .calm, reduceMotion: false)
        let controller = BreathingController(rig: rig, composer: composer, profile: profile)
        let base = rig.base

        controller.start(on: rig.root)
        composer.set(PetMotionOffset(zRotation: 0.15), for: .leftEar, from: "earTwitch")
        controller.stop(on: rig.root)

        // Ear offset from the other source survives.
        #expect(composer.combinedOffset(for: .leftEar) == PetMotionOffset(zRotation: 0.15))
        #expect(abs(Double(rig.leftEar.zRotation - (base.leftEar.zRotation + 0.15))) < 1e-6)
        // Breathing's own contribution is gone: abdomen/chest/head are at base.
        #expect(PetNodeTransform(capturing: rig.abdomen) == base.abdomen)
        #expect(PetNodeTransform(capturing: rig.chest) == base.chest)
        #expect(PetNodeTransform(capturing: rig.head) == base.head)
        #expect(composer.combinedOffset(for: .abdomen) == .identity)
    }
}
