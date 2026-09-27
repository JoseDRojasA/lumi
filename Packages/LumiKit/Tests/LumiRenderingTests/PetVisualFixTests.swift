import Foundation
import CoreGraphics
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

/// Tests driving the visual-defect fixes found in the 24-seed review:
///  1. Magic glow renders as a soft aura BEHIND the pet (not a front bubble).
///  2. Magic is not drawn under a policy without effects (.watch).
///  3. Tails always tuck into the body silhouette (single connected component)
///     and pivot at their root.
@MainActor
struct PetVisualFixTests {

    private func rig(seed: UInt64) throws -> (PetRig, PetConfiguration) {
        let layout = try RenderingFixtures.realLayout()
        let catalog = try RenderingFixtures.testCatalog()
        let config = try PetGenerator.generate(seed: seed, version: 1)
        let presentation = PetPresentation(configuration: config)
        let factory = PetNodeFactory(catalog: catalog, layout: layout)
        return (try factory.makeRig(presentation: presentation), config)
    }

    private func makeScene(
        seed: UInt64,
        policy: PetRenderPolicy
    ) throws -> PetScene {
        let layout = try RenderingFixtures.realLayout()
        let catalog = try RenderingFixtures.testCatalog()
        let config = try PetGenerator.generate(seed: seed, version: 1)
        let presentation = PetPresentation(configuration: config)
        return try PetScene(
            presentation: presentation,
            catalog: catalog,
            layout: layout,
            policy: policy,
            reduceMotion: false
        )
    }

    /// The first reference seed whose configuration has a given magical feature.
    private func firstSeed(feature: MagicalFeature) throws -> UInt64 {
        for seed in RenderingFixtures.referenceSeeds {
            let c = try PetGenerator.generate(seed: seed, version: 1)
            if c.details.magicalFeature == feature { return seed }
        }
        Issue.record("no reference seed with feature \(feature)")
        return 0
    }

    // MARK: - Defect 1: glow is a soft aura behind the pet

    @Test func glowMagicSitsBehindBodyAndTailWithAdditiveBlend() throws {
        let seed = try firstSeed(feature: .glow)
        let (rig, _) = try self.rig(seed: seed)
        let magic = try #require(rig.magic as? SKSpriteNode)

        // Behind the tail (-10) and body (0), above the shadow (-20).
        #expect(magic.zPosition < rig.tail.zPosition, "glow z \(magic.zPosition) not below tail \(rig.tail.zPosition)")
        #expect(magic.zPosition < 0, "glow z \(magic.zPosition) not below body")
        #expect(magic.zPosition > rig.shadow.zPosition, "glow z \(magic.zPosition) not above shadow \(rig.shadow.zPosition)")

        // Additive blend so it reads as light, not a translucent disc.
        #expect(magic.blendMode == .add)
    }

    @Test func glowAlphaMappedFromIntensityIntoSoftRange() throws {
        // Build two configs differing only in magical intensity (0 and 1) and
        // confirm the resulting base alpha lands in the ~0.18...0.45 range.
        let base = try firstSeed(feature: .glow)
        let layout = try RenderingFixtures.realLayout()
        let catalog = try RenderingFixtures.testCatalog()

        func alpha(intensity: Double) throws -> CGFloat {
            var config = try PetGenerator.generate(seed: base, version: 1)
            config.details.magicalIntensity = intensity
            let factory = PetNodeFactory(catalog: catalog, layout: layout)
            let rig = try factory.makeRig(presentation: PetPresentation(configuration: config))
            return (rig.magic as? SKSpriteNode)?.alpha ?? -1
        }

        let a0 = try alpha(intensity: 0)
        let a1 = try alpha(intensity: 1)
        // Endpoints match the intended soft range.
        #expect(abs(a0 - 0.18) < 0.02, "intensity 0 alpha \(a0)")
        #expect(abs(a1 - 0.45) < 0.02, "intensity 1 alpha \(a1)")
        // Monotonic + inside band.
        #expect(a1 > a0)
        #expect(a0 >= 0.18 && a1 <= 0.45)
    }

    @Test func glowIsLargerThanCharacterAndCentredOnIt() throws {
        let seed = try firstSeed(feature: .glow)
        let (rig, _) = try self.rig(seed: seed)
        let magic = try #require(rig.magic as? SKSpriteNode)

        // Per the art direction the aura is centred on the character body+head
        // mass and slightly larger than it. Use the union of the body and head
        // frames (in root space) as the reference — ears/tail spikes are not the
        // reference the aura wraps.
        let bodyFrame = rig.body.calculateAccumulatedFrame()
        let headFrame = rig.head.calculateAccumulatedFrame()
        let mass = bodyFrame.union(headFrame)

        let magicFrame = magic.calculateAccumulatedFrame()
        // Larger than the body+head mass in both dimensions.
        #expect(magicFrame.width >= mass.width, "glow width \(magicFrame.width) < mass \(mass.width)")
        #expect(magicFrame.height >= mass.height * 0.9, "glow height \(magicFrame.height) too small vs \(mass.height)")
        // Roughly centred on the mass (within 15% of the mass's larger extent).
        let tol = max(mass.width, mass.height) * 0.15
        #expect(abs(magicFrame.midX - mass.midX) <= tol, "glow midX \(magicFrame.midX) vs mass \(mass.midX)")
        #expect(abs(magicFrame.midY - mass.midY) <= tol, "glow midY \(magicFrame.midY) vs mass \(mass.midY)")
    }

    @Test func sparklesAndOrbitingStayInFrontButAdditive() throws {
        for feature in [MagicalFeature.sparkles, .orbitingLight] {
            let seed = try firstSeed(feature: feature)
            let (rig, _) = try self.rig(seed: seed)
            let magic = try #require(rig.magic as? SKSpriteNode, "no magic for \(feature)")
            #expect(magic.zPosition == 20, "\(feature) z \(magic.zPosition)")
            #expect(magic.blendMode == .add, "\(feature) blend \(magic.blendMode)")
        }
    }

    // MARK: - Defect 2: no magic under a no-effects policy (watch)

    @Test func magicHiddenOnWatchAndVisibleOnPhone() throws {
        let seed = try firstSeed(feature: .glow)
        let watchScene = try makeScene(seed: seed, policy: .watch)
        #expect(watchScene.rig.magic != nil)
        #expect(watchScene.rig.magic?.isHidden == true, "magic drawn on watch")

        // Switching to an effects policy reveals it.
        watchScene.setPolicy(.phone)
        #expect(watchScene.rig.magic?.isHidden == false, "magic still hidden after setPolicy(.phone)")

        // A phone scene shows magic from the start.
        let phoneScene = try makeScene(seed: seed, policy: .phone)
        #expect(phoneScene.rig.magic?.isHidden == false)

        // And switching back to watch hides it again.
        phoneScene.setPolicy(.watch)
        #expect(phoneScene.rig.magic?.isHidden == true)
    }

    // MARK: - Defect 3: tails tuck into the body silhouette

    /// The body.base silhouette frame in root-local coordinates.
    private func bodyBaseFrame(_ rig: PetRig) -> CGRect {
        let bodyBase = rig.body.childNode(withName: "pet.body.base")!
        // body.base is at .zero within the body container, so its accumulated
        // frame in body space offset by the container position gives root space.
        let localFrame = bodyBase.calculateAccumulatedFrame()
        return localFrame.offsetBy(dx: rig.body.position.x, dy: rig.body.position.y)
    }

    /// The tail's ROOT point (its anchorPoint mapped into root-local space). This
    /// is where the visible tail base sits and where sway rotation pivots. With a
    /// centre anchor and an off-centre spine this point floats outside the body;
    /// the fix places it inside the body silhouette.
    private func tailRootInRootSpace(_ rig: PetRig) -> CGPoint {
        let tail = rig.tail as! SKSpriteNode
        // anchorPoint (0..1, y-up) maps to the sprite-local offset from centre:
        // (anchor - 0.5) * size, scaled by the node's scale. The anchorPoint is,
        // by SpriteKit's definition, the point that lands at `tail.position`.
        // So the tail root in the tail's parent (root) space IS tail.position.
        return tail.position
    }

    @Test func everyReferenceSeedTailRootInsideBody() throws {
        for seed in RenderingFixtures.referenceSeeds {
            let (rig, config) = try self.rig(seed: seed)
            let body = bodyBaseFrame(rig)
            let root = tailRootInRootSpace(rig)
            // The tail root must sit inside the body silhouette (with a small
            // inset margin) so the base is tucked behind the body.
            let inset = body.insetBy(dx: body.width * 0.04, dy: body.height * 0.04)
            #expect(
                inset.contains(root),
                "seed \(seed) tail=\(config.tail.tailStyle.rawValue) root \(root) outside body \(body)"
            )
        }
    }

    @Test func everyReferenceSeedTailOverlapsBody() throws {
        // With the root tucked inside the body, the tail sprite frame overlaps
        // the body.base frame by a meaningful margin (≥ 8% of tail width).
        for seed in RenderingFixtures.referenceSeeds {
            let (rig, config) = try self.rig(seed: seed)
            let tailFrame = rig.tail.calculateAccumulatedFrame()
            let body = bodyBaseFrame(rig)
            let left = max(tailFrame.minX, body.minX)
            let right = min(tailFrame.maxX, body.maxX)
            let overlap = max(0, right - left)
            let minOverlap = tailFrame.width * 0.08
            #expect(
                overlap >= minOverlap,
                "seed \(seed) tail=\(config.tail.tailStyle.rawValue) overlap \(overlap) < \(minOverlap) (tailW \(tailFrame.width))"
            )
        }
    }

    @Test func tailAnchorPointIsAtRootNotCentre() throws {
        // The tail sprite must pivot at its root, so its anchorPoint is NOT the
        // default centre (0.5, 0.5).
        for style in TailStyle.allCases {
            var config = try PetGenerator.generate(seed: 1, version: 1)
            config.tail.tailStyle = style
            let layout = try RenderingFixtures.realLayout()
            let catalog = try RenderingFixtures.testCatalog()
            let factory = PetNodeFactory(catalog: catalog, layout: layout)
            let rig = try factory.makeRig(presentation: PetPresentation(configuration: config))
            let tail = try #require(rig.tail as? SKSpriteNode)
            #expect(
                tail.anchorPoint != CGPoint(x: 0.5, y: 0.5),
                "tail \(style) anchorPoint still centred: \(tail.anchorPoint)"
            )
        }
    }

    @Test func everyReferenceSeedPawsOverlapBody() throws {
        // The paws must stay tucked into the body silhouette for every seed
        // (including the smallest bodies) so the rendered pet is one connected
        // blob. Assert the paws frame overlaps the body.base frame vertically.
        for seed in RenderingFixtures.referenceSeeds {
            let (rig, config) = try self.rig(seed: seed)
            let paws = rig.paws.calculateAccumulatedFrame()
            let body = bodyBaseFrame(rig)
            let top = min(paws.maxY, body.maxY)
            let bottom = max(paws.minY, body.minY)
            let overlap = max(0, top - bottom)
            #expect(
                overlap > 0,
                "seed \(seed) shape=\(config.body.bodyShape.rawValue) paws \(paws) not overlapping body \(body)"
            )
        }
    }

    @Test func tailSwayPivotsAtRootKeepingRootFixed() throws {
        // Applying a tail sway rotation must keep the root socket fixed (rotation
        // pivots at the anchorPoint = root), so the root stays inside the body.
        let (rig, _) = try self.rig(seed: 4181) // long, thick, previously floating
        let rootBefore = tailRootInRootSpace(rig)
        let composer = PetMotionComposer(rig: rig)
        composer.set(PetMotionOffset(zRotation: 0.15), for: .tail, from: "tailSway")
        composer.apply()
        let rootAfter = tailRootInRootSpace(rig)
        #expect(rootBefore == rootAfter, "tail root moved under sway: \(rootBefore) -> \(rootAfter)")
        let body = bodyBaseFrame(rig)
        #expect(body.contains(rootAfter), "tail root outside body after sway")
    }
}
