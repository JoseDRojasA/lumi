import Foundation
import CoreGraphics
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

@MainActor
struct PetSceneTests {

    private func makeScene(
        seed: UInt64 = 101,
        policy: PetRenderPolicy = .phone,
        reduceMotion: Bool = false
    ) throws -> PetScene {
        let layout = try RenderingFixtures.realLayout()
        let catalog = try RenderingFixtures.testCatalog()
        let configuration = try PetGenerator.generate(seed: seed, version: 1)
        let presentation = PetPresentation(configuration: configuration)
        return try PetScene(
            presentation: presentation,
            catalog: catalog,
            layout: layout,
            policy: policy,
            reduceMotion: reduceMotion
        )
    }

    private func resize(_ scene: PetScene, _ size: CGSize) {
        let old = scene.size
        scene.size = size
        scene.didChangeSize(old)
    }

    @Test func buildsStageAndRig() throws {
        let scene = try makeScene()
        #expect(scene.stage.name == "pet.stage")
        #expect(scene.rig.root.parent === scene.stage)
        #expect(scene.stage.parent === scene)
        #expect(!scene.accessibilityDescription.isEmpty)
    }

    @Test func centersCharacterForEveryPolicy() throws {
        let cases: [(CGSize, PetRenderPolicy)] = [
            (CGSize(width: 390, height: 844), .phone),
            (CGSize(width: 844, height: 390), .phoneLandscape),
            (CGSize(width: 1024, height: 1366), .pad),
            (CGSize(width: 1200, height: 800), .mac),
            (CGSize(width: 198, height: 242), .watch),
        ]
        for (size, policy) in cases {
            let scene = try makeScene(policy: policy)
            resize(scene, size)
            let frame = scene.characterFrameInScene
            #expect(abs(frame.midX) <= 0.5, "policy \(policy) midX \(frame.midX)")
            #expect(abs(frame.midY) <= 0.5, "policy \(policy) midY \(frame.midY)")
            let shorter = min(size.width, size.height)
            let expected = shorter * policy.sizeFraction
            let actual = max(frame.width, frame.height)
            #expect(abs(actual - expected) <= expected * 0.01, "policy \(policy) size \(actual) vs \(expected)")
        }
    }

    @Test func resizeKeepsCentered() throws {
        let scene = try makeScene(policy: .phone)
        resize(scene, CGSize(width: 390, height: 844))
        resize(scene, CGSize(width: 500, height: 900))
        let frame = scene.characterFrameInScene
        #expect(abs(frame.midX) <= 0.5)
        #expect(abs(frame.midY) <= 0.5)
    }

    @Test func startAnimationRegistersBreathing() throws {
        let scene = try makeScene()
        resize(scene, CGSize(width: 390, height: 844))
        scene.startAnimation()
        #expect(scene.petRoot.action(forKey: "pet.breathing") != nil)
        #expect(scene.isAnimating)
    }

    @Test func updateDrivesSecondaryMotion() throws {
        let scene = try makeScene()
        resize(scene, CGSize(width: 390, height: 844))
        scene.startAnimation()

        let tailBase = scene.rig.base.tail.zRotation
        var sawLid = false
        var tailDiffers = false

        let dt = 1.0 / 60.0
        var t = 0.0
        let steps = Int(15.0 / dt)
        for _ in 0...steps {
            scene.update(t)
            scene.didEvaluateActions()
            if scene.rig.leftEyelid.alpha > 0 { sawLid = true }
            if abs(Double(scene.rig.tail.zRotation - tailBase)) > 1e-6 { tailDiffers = true }
            t += dt
        }
        #expect(sawLid || tailDiffers)
    }

    @Test func pauseDoesNotJump() throws {
        let scene = try makeScene()
        resize(scene, CGSize(width: 390, height: 844))
        scene.startAnimation()

        // Advance to t = 1.
        scene.update(0.0)
        scene.didEvaluateActions()
        scene.update(1.0)
        scene.didEvaluateActions()
        let elapsedBefore = scene.secondaryElapsedForTesting

        // Pause, huge time jump, resume.
        scene.setApplicationActive(false)
        scene.update(1000.0)
        scene.didEvaluateActions()
        scene.setApplicationActive(true)
        scene.update(1001.0)
        scene.didEvaluateActions()
        scene.update(1001.0 + 1.0 / 60.0)
        scene.didEvaluateActions()

        let elapsedAfter = scene.secondaryElapsedForTesting
        // Across the pause+resume, elapsed grows by at most 0.1 (one clamped dt)
        // plus one further frame.
        #expect(elapsedAfter - elapsedBefore <= 0.1 + 1.0 / 60.0 + 1e-9)
    }

    @Test func reduceMotionToggleUpdatesProfiles() throws {
        let scene = try makeScene(seed: 202)
        resize(scene, CGSize(width: 390, height: 844))
        scene.startAnimation()

        scene.setReduceMotion(true)
        #expect(scene.reduceMotion)

        let config = try PetGenerator.generate(seed: 202, version: 1)
        let normalBreathing = BreathingProfile(personality: config.motionPersonality, reduceMotion: false)
        let rmBreathing = scene.breathingProfileForTesting
        #expect(abs(Double(rmBreathing.abdomenXAmplitude - normalBreathing.abdomenXAmplitude * 0.4)) < 1e-12)

        let normalSecondary = SecondaryMotionProfile(configuration: config, reduceMotion: false, includesEffects: true)
        let rmSecondary = scene.secondaryProfileForTesting
        #expect(abs(rmSecondary.earAmplitude - normalSecondary.earAmplitude * 0.25) < 1e-12)
    }

    @Test func stopAnimationRestoresBase() throws {
        let scene = try makeScene()
        resize(scene, CGSize(width: 390, height: 844))
        scene.startAnimation()

        let dt = 1.0 / 60.0
        var t = 0.0
        for _ in 0..<Int(5.0 / dt) {
            scene.update(t)
            scene.didEvaluateActions()
            t += dt
        }

        scene.stopAnimation()
        #expect(scene.petRoot.action(forKey: "pet.breathing") == nil)

        let base = scene.rig.base
        #expect(PetNodeTransform(capturing: scene.rig.head) == base.head)
        #expect(PetNodeTransform(capturing: scene.rig.abdomen) == base.abdomen)
        #expect(PetNodeTransform(capturing: scene.rig.chest) == base.chest)
        #expect(PetNodeTransform(capturing: scene.rig.tail) == base.tail)
        #expect(PetNodeTransform(capturing: scene.rig.leftEar) == base.leftEar)
        #expect(PetNodeTransform(capturing: scene.rig.rightEar) == base.rightEar)
        #expect(scene.rig.leftEyelid.alpha == 0)
        #expect(scene.rig.rightEyelid.alpha == 0)
    }

    @Test func sceneRectConvertsToViewRectFlippingY() {
        // Scene: anchorPoint (0.5,0.5), y-up. View: origin top-left, y-down.
        // A scene rect centered at origin maps to the view's centre.
        let sceneSize = CGSize(width: 200, height: 400)
        let sceneRect = CGRect(x: -30, y: -40, width: 60, height: 80)
        let viewRect = PetScene.viewRect(fromSceneRect: sceneRect, sceneSize: sceneSize)
        // width/height preserved.
        #expect(viewRect.width == 60)
        #expect(viewRect.height == 80)
        // Centre maps to the view centre (100, 200).
        #expect(abs(viewRect.midX - 100) < 1e-9)
        #expect(abs(viewRect.midY - 200) < 1e-9)
    }

    @Test func sceneRectAboveCentreMapsHigherInView() {
        // A rect above scene origin (positive y) should sit ABOVE the view
        // centre, i.e. a smaller view-y (origin top-left).
        let sceneSize = CGSize(width: 200, height: 400)
        let sceneRect = CGRect(x: -10, y: 50, width: 20, height: 20) // midY = 60 (scene, up)
        let viewRect = PetScene.viewRect(fromSceneRect: sceneRect, sceneSize: sceneSize)
        // view midY = sceneSize.height/2 - sceneMidY = 200 - 60 = 140.
        #expect(abs(viewRect.midY - 140) < 1e-9)
        // view minY = height/2 - sceneMaxY = 200 - 70 = 130.
        #expect(abs(viewRect.minY - 130) < 1e-9)
    }

    @Test func characterFrameInViewIsCentredForEveryPolicy() throws {
        let cases: [(CGSize, PetRenderPolicy)] = [
            (CGSize(width: 390, height: 844), .phone),
            (CGSize(width: 844, height: 390), .phoneLandscape),
            (CGSize(width: 1024, height: 1366), .pad),
            (CGSize(width: 1200, height: 800), .mac),
            (CGSize(width: 198, height: 242), .watch),
        ]
        for (size, policy) in cases {
            let scene = try makeScene(policy: policy)
            resize(scene, size)
            let viewRect = PetScene.viewRect(fromSceneRect: scene.characterFrameInScene, sceneSize: size)
            #expect(abs(viewRect.midX - size.width / 2) <= 0.5, "policy \(policy) viewMidX \(viewRect.midX)")
            #expect(abs(viewRect.midY - size.height / 2) <= 0.5, "policy \(policy) viewMidY \(viewRect.midY)")
        }
    }

    @Test func watchPolicyDisablesEffects() throws {
        // Use a seed whose configuration has a magical feature so magicPulse
        // would be non-zero were effects enabled.
        var seed: UInt64 = 0
        for candidate in 0..<UInt64(2000) {
            let config = try PetGenerator.generate(seed: candidate, version: 1)
            if config.details.magicalFeature != .none {
                seed = candidate
                break
            }
        }
        let scene = try makeScene(seed: seed, policy: .watch)
        resize(scene, CGSize(width: 198, height: 242))
        #expect(scene.secondaryProfileForTesting.magicPulse == 0)
        // The watch keeps the secondary breathing tier and boosts amplitude so
        // the tiny pet still reads as alive.
        #expect(scene.breathingProfileForTesting.secondaryAmplitude > 0)
        let personality = try PetGenerator.generate(seed: seed, version: 1).motionPersonality
        let phone = BreathingProfile(personality: personality, reduceMotion: false)
        #expect(scene.breathingProfileForTesting.abdomenXAmplitude > phone.abdomenXAmplitude)
    }
}
