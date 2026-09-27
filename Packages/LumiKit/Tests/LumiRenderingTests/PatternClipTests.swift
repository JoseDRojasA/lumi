import Foundation
import CoreGraphics
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

/// Tests driving the pattern-clip fix: every pattern overlay (body spots/
/// stripes/gradient, face mask, paw socks) must be clipped to the silhouette of
/// the part it decorates via an `SKCropNode` whose mask uses the SAME texture as
/// the underlying base sprite, and its accumulated frame must never spill
/// outside that base sprite's accumulated frame.
@MainActor
struct PatternClipTests {

    private func rig(seed: UInt64) throws -> (PetRig, PetConfiguration) {
        let layout = try RenderingFixtures.realLayout()
        let catalog = try RenderingFixtures.testCatalog()
        let config = try PetGenerator.generate(seed: seed, version: 1)
        let presentation = PetPresentation(configuration: config)
        let factory = PetNodeFactory(catalog: catalog, layout: layout)
        return (try factory.makeRig(presentation: presentation), config)
    }

    /// A rect fully contains another within a small tolerance on every edge.
    private func contains(_ outer: CGRect, _ inner: CGRect, tol: CGFloat = 1.0) -> Bool {
        inner.minX >= outer.minX - tol &&
        inner.minY >= outer.minY - tol &&
        inner.maxX <= outer.maxX + tol &&
        inner.maxY <= outer.maxY + tol
    }

    private func bodyPatternSeeds() -> [UInt64] {
        RenderingFixtures.referenceSeeds.filter { seed in
            let c = try! PetGenerator.generate(seed: seed, version: 1)
            switch c.body.patternStyle {
            case .spots, .stripes, .gradient: return true
            default: return false
            }
        }
    }

    private func maskSeeds() -> [UInt64] {
        RenderingFixtures.referenceSeeds.filter {
            (try? PetGenerator.generate(seed: $0, version: 1))?.body.patternStyle == .mask
        }
    }

    private func socksSeeds() -> [UInt64] {
        RenderingFixtures.referenceSeeds.filter {
            (try? PetGenerator.generate(seed: $0, version: 1))?.body.patternStyle == .socks
        }
    }

    // MARK: - Body pattern clipped to body silhouette

    @Test func bodyPatternIsCropNodeMaskedByBodyBase() throws {
        let seeds = bodyPatternSeeds()
        #expect(!seeds.isEmpty, "expected at least one body-pattern reference seed")
        for seed in seeds {
            let (rig, config) = try self.rig(seed: seed)

            // pet.body.pattern is an SKCropNode.
            let crop = try #require(rig.bodyPattern as? SKCropNode,
                                    "seed \(seed) style=\(config.body.patternStyle.rawValue) bodyPattern is not an SKCropNode")
            #expect(crop.name == "pet.body.pattern")

            // Its mask must be an SKSpriteNode using the body base texture.
            let mask = try #require(crop.maskNode as? SKSpriteNode,
                                    "seed \(seed) crop has no SKSpriteNode maskNode")
            let bodyBase = try #require(rig.body.childNode(withName: "pet.body.base") as? SKSpriteNode)
            #expect(mask.texture === bodyBase.texture,
                    "seed \(seed) mask texture does not match body base texture")
            #expect(mask.size == bodyBase.size,
                    "seed \(seed) mask size \(mask.size) != body base size \(bodyBase.size)")
            #expect(mask.position == bodyBase.position,
                    "seed \(seed) mask pos \(mask.position) != body base pos \(bodyBase.position)")

            // The inner pattern sprite is present under a stable name.
            #expect(crop.childNode(withName: "pet.body.pattern.sprite") != nil,
                    "seed \(seed) missing inner pattern sprite")

            // The crop node's accumulated frame must lie within body.base's
            // accumulated frame (tolerance 1pt) — no spill outside the body.
            let cropFrame = crop.calculateAccumulatedFrame()
            let baseFrame = bodyBase.calculateAccumulatedFrame()
            #expect(contains(baseFrame, cropFrame),
                    "seed \(seed) body pattern frame \(cropFrame) spills outside body base \(baseFrame)")
        }
    }

    // MARK: - Face pattern clipped to head silhouette

    @Test func facePatternIsCropNodeMaskedByHeadBase() throws {
        let seeds = maskSeeds()
        #expect(!seeds.isEmpty, "expected at least one mask reference seed")
        for seed in seeds {
            let (rig, _) = try self.rig(seed: seed)

            let crop = try #require(rig.facePattern as? SKCropNode,
                                    "seed \(seed) facePattern is not an SKCropNode")
            #expect(crop.name == "pet.facePattern")

            let mask = try #require(crop.maskNode as? SKSpriteNode,
                                    "seed \(seed) facePattern crop has no SKSpriteNode maskNode")
            let headBase = try #require(rig.head.childNode(withName: "pet.head.base") as? SKSpriteNode)
            #expect(mask.texture === headBase.texture,
                    "seed \(seed) face mask texture does not match head base texture")
            #expect(mask.size == headBase.size)
            #expect(mask.position == headBase.position)

            #expect(crop.childNode(withName: "pet.facePattern.sprite") != nil)

            let cropFrame = crop.calculateAccumulatedFrame()
            let baseFrame = headBase.calculateAccumulatedFrame()
            #expect(contains(baseFrame, cropFrame),
                    "seed \(seed) face pattern frame \(cropFrame) spills outside head base \(baseFrame)")
        }
    }

    // MARK: - Socks clipped to paws silhouette

    @Test func pawsPatternIsCropNodeMaskedByPaws() throws {
        let seeds = socksSeeds()
        #expect(!seeds.isEmpty, "expected at least one socks reference seed")
        for seed in seeds {
            let (rig, _) = try self.rig(seed: seed)

            let crop = try #require(rig.paws.childNode(withName: "pet.paws.pattern") as? SKCropNode,
                                    "seed \(seed) pet.paws.pattern is not an SKCropNode")

            let mask = try #require(crop.maskNode as? SKSpriteNode,
                                    "seed \(seed) paws pattern crop has no SKSpriteNode maskNode")
            let pawsSprite = try #require(rig.paws as? SKSpriteNode)
            #expect(mask.texture === pawsSprite.texture,
                    "seed \(seed) socks mask texture does not match paws texture")
            #expect(mask.size == pawsSprite.size)

            #expect(crop.childNode(withName: "pet.paws.pattern.sprite") != nil)

            // The socks crop frame must lie within the paws sprite frame. The
            // paws sprite is centred at .zero in its own space with its own
            // accumulated frame; the crop is a child at .zero, so compare in
            // the paws' local space.
            let cropFrame = crop.calculateAccumulatedFrame()
            let pawsLocalFrame = CGRect(
                x: -pawsSprite.size.width / 2,
                y: -pawsSprite.size.height / 2,
                width: pawsSprite.size.width,
                height: pawsSprite.size.height
            )
            #expect(contains(pawsLocalFrame, cropFrame),
                    "seed \(seed) socks frame \(cropFrame) spills outside paws \(pawsLocalFrame)")
        }
    }

    // MARK: - Character bounds unchanged for pattern-free seeds

    @Test func characterBoundsUnaffectedByClipForPatternlessSeeds() throws {
        // Seeds with patternStyle == .none must have identical body/head/paws
        // silhouettes with or without the fix (no pattern node at all).
        for seed in RenderingFixtures.referenceSeeds {
            let (rig, config) = try self.rig(seed: seed)
            if config.body.patternStyle == .none {
                #expect(rig.bodyPattern == nil, "seed \(seed) has a body pattern despite .none")
                #expect(rig.facePattern == nil)
                #expect(rig.paws.childNode(withName: "pet.paws.pattern") == nil)
            }
        }
    }
}
