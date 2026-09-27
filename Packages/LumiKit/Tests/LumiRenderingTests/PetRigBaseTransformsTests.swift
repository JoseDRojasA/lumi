import Foundation
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

@MainActor
struct PetRigBaseTransformsTests {
    @Test func restoreRevertsMutations() throws {
        let rig = try RenderingFixtures.testRig(seed: 101)

        let originalAbdomenScale = rig.abdomen.xScale
        let originalHeadPosition = rig.head.position
        let originalRootScale = rig.root.xScale

        // Mutate.
        rig.abdomen.setScale(2.5)
        rig.head.position = CGPoint(x: 999, y: -999)
        rig.root.setScale(0.3)

        // Sanity: mutations took effect.
        #expect(rig.abdomen.xScale != originalAbdomenScale)
        #expect(rig.head.position != originalHeadPosition)
        #expect(rig.root.xScale != originalRootScale)

        rig.restoreBaseTransforms()

        #expect(rig.abdomen.xScale == originalAbdomenScale)
        #expect(rig.abdomen.yScale == originalAbdomenScale)
        #expect(rig.head.position == originalHeadPosition)
        #expect(rig.root.xScale == originalRootScale)
    }
}
