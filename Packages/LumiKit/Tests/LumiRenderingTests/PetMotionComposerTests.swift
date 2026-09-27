import Foundation
import CoreGraphics
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

@MainActor
struct PetMotionComposerTests {
    /// Maps a channel to its live rig node (optional channels may be nil).
    private func node(_ channel: PetMotionChannel, in rig: PetRig) -> SKNode? {
        switch channel {
        case .root: return rig.root
        case .abdomen: return rig.abdomen
        case .chest: return rig.chest
        case .head: return rig.head
        case .paws: return rig.paws
        case .leftEar: return rig.leftEar
        case .rightEar: return rig.rightEar
        case .tail: return rig.tail
        case .chestTuft: return rig.chestTuft
        case .leftCheek: return rig.leftCheek
        case .rightCheek: return rig.rightCheek
        }
    }

    @Test func noOffsetsWritesExactBase() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)

        // Mutate every node arbitrarily.
        for channel in PetMotionChannel.allCases {
            guard let n = node(channel, in: rig) else { continue }
            n.position = CGPoint(x: 123, y: -456)
            n.xScale = 7
            n.yScale = -3
            n.zRotation = 1.234
        }

        composer.apply()

        // Every present channel matches base exactly.
        let base = rig.base
        #expect(PetNodeTransform(capturing: rig.root) == base.root)
        #expect(PetNodeTransform(capturing: rig.abdomen) == base.abdomen)
        #expect(PetNodeTransform(capturing: rig.chest) == base.chest)
        #expect(PetNodeTransform(capturing: rig.head) == base.head)
        #expect(PetNodeTransform(capturing: rig.paws) == base.paws)
        #expect(PetNodeTransform(capturing: rig.leftEar) == base.leftEar)
        #expect(PetNodeTransform(capturing: rig.rightEar) == base.rightEar)
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

    @Test func offsetsFromTwoSourcesAdd() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let base = rig.base

        // Tail zRotation +0.1 from "a" and +0.05 from "b" -> base + 0.15.
        composer.set(PetMotionOffset(zRotation: 0.1), for: .tail, from: "a")
        composer.set(PetMotionOffset(zRotation: 0.05), for: .tail, from: "b")

        // Head dy 3 from "a" and dy 2 from "b" -> base.y + 5.
        composer.set(PetMotionOffset(position: CGVector(dx: 0, dy: 3)), for: .head, from: "a")
        composer.set(PetMotionOffset(position: CGVector(dx: 0, dy: 2)), for: .head, from: "b")

        // Abdomen xScale 1.1 and 1.2 -> base × 1.32.
        composer.set(PetMotionOffset(xScale: 1.1), for: .abdomen, from: "a")
        composer.set(PetMotionOffset(xScale: 1.2), for: .abdomen, from: "b")

        // The pure combination math is exact to double precision (1e-12).
        #expect(abs(Double(composer.combinedOffset(for: .tail).zRotation - 0.15)) < 1e-12)
        #expect(abs(Double(composer.combinedOffset(for: .head).position.dy - 5)) < 1e-12)
        #expect(abs(Double(composer.combinedOffset(for: .abdomen).xScale - 1.32)) < 1e-12)

        composer.apply()

        // SKNode transforms are stored as 32-bit floats, so the round-trip
        // through a node is only accurate to ~1e-6.
        #expect(abs(Double(rig.tail.zRotation - (base.tail.zRotation + 0.15))) < 1e-6)
        #expect(abs(Double(rig.head.position.y - (base.head.position.y + 5))) < 1e-6)
        #expect(abs(Double(rig.abdomen.xScale - base.abdomen.xScale * 1.32)) < 1e-6)
    }

    @Test func clearingOneSourceKeepsTheOther() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        let base = rig.base

        composer.set(PetMotionOffset(zRotation: 0.1), for: .tail, from: "a")
        composer.set(PetMotionOffset(zRotation: 0.05), for: .tail, from: "b")
        composer.clear(source: "a")

        // Exact in double precision: only "b" remains.
        #expect(abs(Double(composer.combinedOffset(for: .tail).zRotation - 0.05)) < 1e-12)

        composer.apply()
        #expect(abs(Double(rig.tail.zRotation - (base.tail.zRotation + 0.05))) < 1e-6)
    }

    @Test func rightEarMirrorPreserved() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)
        let composer = PetMotionComposer(rig: rig)
        // Right ear base xScale is -1; a 1.1 multiplier must keep the mirror.
        #expect(rig.base.rightEar.xScale == -1)

        composer.set(PetMotionOffset(xScale: 1.1), for: .rightEar, from: "a")
        // Combination is exact in double precision: -1 × 1.1 = -1.1.
        #expect(abs(Double(rig.base.rightEar.xScale * composer.combinedOffset(for: .rightEar).xScale - (-1.1))) < 1e-12)

        composer.apply()
        // SKNode read-back is float32-accurate; the sign (mirror) is preserved.
        #expect(rig.rightEar.xScale < 0)
        #expect(abs(Double(rig.rightEar.xScale - (-1.1))) < 1e-6)
    }

    @Test func optionalChannelsSkippedWhenAbsent() throws {
        // Seed 1 has chestTuftStyle == .none, so no chest tuft node/base.
        let rig = try RenderingFixtures.testRig(seed: 1)
        #expect(rig.chestTuft == nil)
        let composer = PetMotionComposer(rig: rig)

        // Must not crash even though the channel node is absent.
        composer.set(PetMotionOffset(position: CGVector(dx: 0, dy: 5)), for: .chestTuft, from: "a")
        composer.apply()
    }

    @Test func sumOrderIsDeterministic() throws {
        let rigA = try RenderingFixtures.testRig(seed: 101)
        let composerA = PetMotionComposer(rig: rigA)
        composerA.set(PetMotionOffset(position: CGVector(dx: 0, dy: 0.1), zRotation: 0.01), for: .tail, from: "zzz")
        composerA.set(PetMotionOffset(position: CGVector(dx: 0, dy: 0.2), zRotation: 0.02), for: .tail, from: "aaa")
        composerA.set(PetMotionOffset(position: CGVector(dx: 0, dy: 0.3), zRotation: 0.03), for: .tail, from: "mmm")
        composerA.apply()

        let rigB = try RenderingFixtures.testRig(seed: 101)
        let composerB = PetMotionComposer(rig: rigB)
        // Different insertion order.
        composerB.set(PetMotionOffset(position: CGVector(dx: 0, dy: 0.3), zRotation: 0.03), for: .tail, from: "mmm")
        composerB.set(PetMotionOffset(position: CGVector(dx: 0, dy: 0.1), zRotation: 0.01), for: .tail, from: "zzz")
        composerB.set(PetMotionOffset(position: CGVector(dx: 0, dy: 0.2), zRotation: 0.02), for: .tail, from: "aaa")
        composerB.apply()

        #expect(rigA.tail.position.y == rigB.tail.position.y)
        #expect(rigA.tail.zRotation == rigB.tail.zRotation)
    }
}
