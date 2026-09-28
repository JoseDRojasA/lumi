import Foundation
import CoreGraphics
import Testing
@testable import LumiRendering

struct PetActivityTests {

    // MARK: Easing

    @Test func easingBoundariesAndMonotonic() {
        for easing in [ActivityEasing.linear, .easeIn, .easeOut, .easeInOut] {
            #expect(abs(easing.apply(0)) < 1e-12)
            #expect(abs(easing.apply(1) - 1) < 1e-12)
            // Clamped outside [0, 1].
            #expect(easing.apply(-1) == 0)
            #expect(easing.apply(2) == 1)
            // Midpoint strictly inside (0, 1).
            let mid = easing.apply(0.5)
            #expect(mid > 0 && mid < 1)
        }
    }

    // MARK: Track sampling

    @Test func trackNeutralOutsideDefinedComponents() {
        // A track defining only dy leaves scale neutral (1) and rotation neutral (0).
        let track = ActivityTrack([
            .init(time: 0, dy: 0),
            .init(time: 1, dy: 100, easing: .linear)
        ])
        let mid = track.sample(at: 0.5)
        #expect(abs(mid.position.dy - 50) < 1e-9)
        #expect(mid.xScale == 1)
        #expect(mid.yScale == 1)
        #expect(mid.zRotation == 0)
    }

    @Test func trackClampsBeyondEnds() {
        let track = ActivityTrack([
            .init(time: 0.2, dx: 10),
            .init(time: 0.8, dx: 20, easing: .linear)
        ])
        #expect(track.sample(at: 0.0).position.dx == 10)   // before first
        #expect(track.sample(at: 1.0).position.dx == 20)   // after last
    }

    @Test func scaleInterpolatesAroundOne() {
        let track = ActivityTrack([
            .init(time: 0, yScale: 1),
            .init(time: 1, yScale: 1.2, easing: .linear)
        ])
        #expect(abs(track.sample(at: 0.5).yScale - 1.1) < 1e-9)
    }

    // MARK: Activity sampling

    @Test func amplitudeZeroCollapsesToIdentity() {
        for activity in PetActivity.allBuiltIn {
            for p in stride(from: 0.0, through: 1.0, by: 0.1) {
                let offsets = activity.sample(atProgress: p, amplitudeScale: 0)
                for (_, o) in offsets {
                    #expect(o == .identity, "\(activity.id) @\(p) should be identity at amplitude 0")
                }
            }
        }
    }

    @Test func amplitudeScalesDeltas() {
        let full = PetActivity.jump.sample(atProgress: 0.5, amplitudeScale: 1.0)
        let half = PetActivity.jump.sample(atProgress: 0.5, amplitudeScale: 0.5)
        let fullRoot = full[.root]!
        let halfRoot = half[.root]!
        #expect(abs(halfRoot.position.dy - fullRoot.position.dy * 0.5) < 1e-9)
        // Scale delta halves too: (s - 1) * 0.5.
        let fullChest = full[.chest]!
        let halfChest = half[.chest]!
        #expect(abs((halfChest.yScale - 1) - (fullChest.yScale - 1) * 0.5) < 1e-9)
    }

    @Test func jumpArcIsZeroAtEndsAndPositiveAtApex() {
        let start = PetActivity.jump.sample(atProgress: 0.0, amplitudeScale: 1)[.root]!
        let apex = PetActivity.jump.sample(atProgress: 0.5, amplitudeScale: 1)[.root]!
        let end = PetActivity.jump.sample(atProgress: 1.0, amplitudeScale: 1)[.root]!
        #expect(abs(start.position.dy) < 1e-9)
        #expect(abs(end.position.dy) < 1e-9)
        #expect(apex.position.dy > 50)
    }

    @Test func jumpRightEarRotationIsExactNegationOfLeft() {
        // Jump's ear follow-through is symmetric: the mirrored right ear (node
        // xScale -1) rotates exactly opposite the left at every progress.
        for p in stride(from: 0.0, through: 1.0, by: 0.1) {
            let offsets = PetActivity.jump.sample(atProgress: p, amplitudeScale: 1)
            guard let left = offsets[.leftEar], let right = offsets[.rightEar] else { continue }
            #expect(abs(left.zRotation + right.zRotation) < 1e-9,
                    "jump @\(p): ears should be exact opposites")
        }
    }

    @Test func danceEarsAlternate() {
        // Dance intentionally phase-swaps the ears (livelier alternating bop),
        // so at the first quarter the ears lean in opposite directions.
        let q = PetActivity.dance.sample(atProgress: 0.25, amplitudeScale: 1)
        let left = q[.leftEar]!.zRotation
        let right = q[.rightEar]!.zRotation
        #expect(left > 0 && right < 0, "dance ears should alternate at the quarter beat")
    }

    @Test func builtInLookupAndFlags() {
        #expect(PetActivity.builtIn(id: "jump")?.id == "jump")
        #expect(PetActivity.builtIn(id: "nope") == nil)
        #expect(PetActivity.jump.loops == false)
        #expect(PetActivity.dance.loops == true)
        #expect(PetActivity.idleActivities.allSatisfy { !$0.loops })
    }
}
