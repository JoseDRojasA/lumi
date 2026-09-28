import Foundation
import CoreGraphics
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

@MainActor
struct ActivityControllerTests {

    private struct Harness {
        let rig: PetRig
        let composer: PetMotionComposer
        let controller: ActivityController
    }

    private func makeHarness(
        seed: UInt64 = 101,
        reduceMotion: Bool = false,
        isEnabled: Bool = true
    ) throws -> Harness {
        let rig = try RenderingFixtures.testRig(seed: seed)
        let configuration = try PetGenerator.generate(seed: seed, version: 1)
        let composer = PetMotionComposer(rig: rig)
        let controller = ActivityController(
            composer: composer,
            configuration: configuration,
            reduceMotion: reduceMotion,
            isEnabled: isEnabled
        )
        return Harness(rig: rig, composer: composer, controller: controller)
    }

    /// Steps the controller by `dt` a fixed number of times.
    private func step(_ controller: ActivityController, dt: TimeInterval, times: Int) {
        for _ in 0..<times { controller.advance(by: dt) }
    }

    // MARK: - Playing

    @Test func playSetsCurrentAndDrivesRoot() throws {
        let h = try makeHarness()
        h.controller.play(.jump)
        #expect(h.controller.current?.id == "jump")

        // Advance to roughly the apex (~0.45 s into a 0.9 s jump).
        step(h.controller, dt: 1.0 / 60, times: 27)
        let rootOffset = h.composer.combinedOffset(for: .root)
        #expect(rootOffset.position.dy > 0, "root should be lifted mid-jump")
    }

    @Test func nonLoopingActivityFinishesAndClears() throws {
        let h = try makeHarness()
        h.controller.play(.jump)
        // Advance well past the 0.9 s duration.
        step(h.controller, dt: 1.0 / 60, times: 90)
        #expect(h.controller.current == nil, "jump should have finished")
        let rootOffset = h.composer.combinedOffset(for: .root)
        #expect(rootOffset == .identity, "root offset should be cleared after jump")
    }

    @Test func loopingActivityKeepsPlaying() throws {
        let h = try makeHarness()
        h.controller.play(.dance)
        step(h.controller, dt: 1.0 / 60, times: 200)  // > one 2 s loop
        #expect(h.controller.current?.id == "dance", "dance loops and stays current")
    }

    // MARK: - Determinism

    @Test func deterministicIdleSchedulingForSameSeed() throws {
        func run() throws -> [String] {
            let h = try makeHarness(seed: 7)
            var started: [String] = []
            // 60 s at 1/30 s steps; capture each activity as it begins.
            for _ in 0..<1800 {
                h.controller.advance(by: 1.0 / 30)
                if let id = h.controller.current?.id, started.last != id {
                    started.append(id)
                }
            }
            return started
        }
        let a = try run()
        let b = try run()
        #expect(a == b, "idle scheduling must be deterministic for the same seed")
        #expect(!a.isEmpty, "director should schedule at least one idle in 60 s")
    }

    // MARK: - No drift

    @Test func clearingActivityRestoresBaseExactly() throws {
        let h = try makeHarness()
        // Capture base transforms.
        let baseRoot = PetNodeTransform(capturing: h.rig.root)
        let baseHead = PetNodeTransform(capturing: h.rig.head)

        h.controller.play(.jump)
        step(h.controller, dt: 1.0 / 60, times: 30)
        h.composer.apply()  // mutate the rig mid-activity
        // Ensure it actually moved.
        #expect(h.rig.root.position != baseRoot.position || h.rig.head.zRotation != baseHead.zRotation)

        h.controller.stopActivity()
        h.composer.apply()
        #expect(h.rig.root.position == baseRoot.position, "root must return to base")
        #expect(h.rig.head.position == baseHead.position, "head must return to base")
        #expect(h.rig.head.zRotation == baseHead.zRotation)
    }

    // MARK: - Reduce Motion

    @Test func reduceMotionShrinksAmplitude() throws {
        let full = try makeHarness(reduceMotion: false)
        let reduced = try makeHarness(reduceMotion: true)
        full.controller.play(.jump)
        reduced.controller.play(.jump)
        step(full.controller, dt: 1.0 / 60, times: 27)
        step(reduced.controller, dt: 1.0 / 60, times: 27)
        let fullDy = full.composer.combinedOffset(for: .root).position.dy
        let reducedDy = reduced.composer.combinedOffset(for: .root).position.dy
        #expect(reducedDy < fullDy)
        #expect(abs(reducedDy - fullDy * 0.25) < 1e-6)
    }

    // MARK: - Gating

    @Test func disabledControllerNeverMovesOrSchedules() throws {
        let h = try makeHarness(isEnabled: false)
        h.controller.play(.jump)  // no-op when disabled
        #expect(h.controller.current == nil)
        step(h.controller, dt: 1.0 / 30, times: 3000)  // 100 s
        #expect(h.controller.current == nil)
        for channel in PetMotionChannel.allCases {
            #expect(h.composer.combinedOffset(for: channel) == .identity)
        }
    }

    // MARK: - Interrupt / override

    @Test func explicitPlayInterruptsCurrent() throws {
        let h = try makeHarness()
        h.controller.play(.dance)
        step(h.controller, dt: 1.0 / 60, times: 10)
        #expect(h.controller.current?.id == "dance")
        h.controller.play(.jump)
        #expect(h.controller.current?.id == "jump", "explicit play should interrupt")
    }

    // MARK: - Reset

    @Test func resetClearsSourceAndCurrent() throws {
        let h = try makeHarness()
        h.controller.play(.jump)
        step(h.controller, dt: 1.0 / 60, times: 20)
        h.controller.reset()
        #expect(h.controller.current == nil)
        for channel in PetMotionChannel.allCases {
            #expect(h.composer.combinedOffset(for: channel) == .identity)
        }
    }
}
