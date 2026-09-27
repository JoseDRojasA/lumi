import Foundation
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
struct PetNodeFactoryTests {
    // Walk the whole tree collecting node names.
    private func allNodes(_ node: SKNode) -> [SKNode] {
        var result = [node]
        for child in node.children {
            result.append(contentsOf: allNodes(child))
        }
        return result
    }

    private func rig(seed: UInt64) throws -> (PetRig, PetConfiguration) {
        let layout = try RenderingFixtures.realLayout()
        let catalog = try RenderingFixtures.testCatalog()
        let config = try PetGenerator.generate(seed: seed, version: 1)
        let presentation = PetPresentation(configuration: config)
        let factory = PetNodeFactory(catalog: catalog, layout: layout)
        return (try factory.makeRig(presentation: presentation), config)
    }

    @Test func buildsForEveryReferenceSeed() throws {
        let expectedRequired: Set<String> = [
            "pet.root", "pet.body", "pet.abdomen", "pet.chest", "pet.head",
            "pet.eye.left", "pet.eye.right", "pet.ear.left", "pet.ear.right",
            "pet.tail", "pet.paws", "pet.shadow"
        ]
        for seed in RenderingFixtures.referenceSeeds {
            let (rig, config) = try self.rig(seed: seed)

            // Required nodes present exactly once, names match.
            let requiredNames = rig.requiredNodes.compactMap(\.name)
            #expect(Set(requiredNames) == expectedRequired)
            #expect(requiredNames.count == expectedRequired.count)

            // Every named node in the tree is unique.
            let names = allNodes(rig.root).compactMap(\.name)
            #expect(Set(names).count == names.count, "duplicate node name for seed \(seed): \(names)")

            // Optional nodes present iff the trait says so.
            #expect((rig.headTuft != nil) == (config.details.headTuftStyle != .none))
            #expect((rig.chestTuft != nil) == (config.details.chestTuftStyle != .none))
            let cheeksExpected = config.face.cheekStyle != .none
            #expect((rig.leftCheek != nil) == cheeksExpected)
            #expect((rig.rightCheek != nil) == cheeksExpected)
            #expect((rig.magic != nil) == (config.details.magicalFeature != .none))

            let bodyPatternExpected: Bool = {
                switch config.body.patternStyle {
                case .spots, .stripes, .gradient: return true
                default: return false
                }
            }()
            #expect((rig.bodyPattern != nil) == bodyPatternExpected)
            #expect((rig.facePattern != nil) == (config.body.patternStyle == .mask))
            let pawsPattern = rig.paws.childNode(withName: "pet.paws.pattern")
            #expect((pawsPattern != nil) == (config.body.patternStyle == .socks))
        }
    }

    @Test func headBaseUsesFurVariantTexture() throws {
        final class Recorder: @unchecked Sendable { var requested: [String] = [] }
        let recorder = Recorder()
        let layout = try RenderingFixtures.realLayout()
        let catalog = try PetTextureCatalog(
            availableNames: Set(PetTextureCatalog.requiredTextureNames),
            textureLoader: { name in
                recorder.requested.append(name)
                return RenderingFixtures.solidTexture()
            }
        )
        let config = try PetGenerator.generate(seed: 8, version: 1)
        let presentation = PetPresentation(configuration: config)
        let factory = PetNodeFactory(catalog: catalog, layout: layout)
        _ = try factory.makeRig(presentation: presentation)
        let expectedName = layout.headVariant(for: config.body.furStyle)
        #expect(expectedName != nil)
        #expect(recorder.requested.contains(expectedName!))
    }

    @Test func earsMirrored() throws {
        let (rig, _) = try self.rig(seed: 3)
        #expect(rig.leftEar.xScale == 1)
        #expect(rig.rightEar.xScale == -1)
    }

    @Test func tintAndBlendFactors() throws {
        let (rig, config) = try self.rig(seed: 13)

        // body.base tinted with baseColor, blend 1.
        let bodyBase = rig.body.childNode(withName: "pet.body.base") as? SKSpriteNode
        #expect(bodyBase?.colorBlendFactor == 1)
        assertColor(bodyBase?.color, matches: config.palette.baseColor)

        // abdomen tinted with secondaryColor.
        let abdomen = rig.abdomen as? SKSpriteNode
        #expect(abdomen?.colorBlendFactor == 1)
        assertColor(abdomen?.color, matches: config.palette.secondaryColor)

        // nose tinted with noseColor.
        let nose = rig.nose as? SKSpriteNode
        #expect(nose?.colorBlendFactor == 1)
        assertColor(nose?.color, matches: config.face.noseColor)

        // iris tinted with irisColor.
        let iris = rig.leftEye.childNode(withName: "pet.eye.left.iris") as? SKSpriteNode
        #expect(iris?.colorBlendFactor == 1)
        assertColor(iris?.color, matches: config.face.irisColor)

        // eye base untinted.
        let eyeBase = rig.leftEye as? SKSpriteNode
        #expect(eyeBase?.colorBlendFactor == 0)

        // shadow untinted.
        let shadow = rig.shadow as? SKSpriteNode
        #expect(shadow?.colorBlendFactor == 0)
    }

    @Test func pawsParentIsRoot() throws {
        let (rig, _) = try self.rig(seed: 21)
        #expect(rig.paws.parent === rig.root)
    }

    @Test func eyeChildZOrder() throws {
        let (rig, _) = try self.rig(seed: 34)
        let eye = rig.leftEye
        let base = eye.zPosition
        let iris = eye.childNode(withName: "pet.eye.left.iris")?.zPosition ?? -1
        let pupil = eye.childNode(withName: "pet.eye.left.pupil")?.zPosition ?? -1
        let catchlight = eye.childNode(withName: "pet.eye.left.catchlight")?.zPosition ?? -1
        let lid = eye.childNode(withName: "pet.eye.left.lid")?.zPosition ?? -1
        _ = base
        #expect(iris < pupil)
        #expect(pupil < catchlight)
        #expect(catchlight < lid)
    }

    @Test func lidsStartOpen() throws {
        let (rig, _) = try self.rig(seed: 55)
        #expect(rig.leftEyelid.alpha == 0)
        #expect(rig.rightEyelid.alpha == 0)
    }

    @Test func eyeAndIrisSizes() throws {
        let layout = try RenderingFixtures.realLayout()
        let (rig, config) = try self.rig(seed: 89)
        let eyeDesign = try layout.designSize(of: "eye_\(config.face.eyeShape.rawValue)")
        let eye = rig.leftEye as? SKSpriteNode
        let expectedEye = CGSize(
            width: eyeDesign.width * CGFloat(config.face.eyeScale),
            height: eyeDesign.height * CGFloat(config.face.eyeScale)
        )
        #expect(approxEqual(eye?.size.width, expectedEye.width))
        #expect(approxEqual(eye?.size.height, expectedEye.height))

        let iris = rig.leftEye.childNode(withName: "pet.eye.left.iris") as? SKSpriteNode
        let expectedIrisSide = expectedEye.width * CGFloat(layout.relativeSizes.iris)
        #expect(approxEqual(iris?.size.width, expectedIrisSide))
        #expect(approxEqual(iris?.size.height, expectedIrisSide))
    }

    // MARK: - Helpers

    private func approxEqual(_ a: CGFloat?, _ b: CGFloat, tol: CGFloat = 1e-3) -> Bool {
        guard let a else { return false }
        return abs(a - b) < tol
    }

    private func assertColor(_ color: SKColor?, matches rgba: RGBAColor, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let color else {
            Issue.record("color was nil", sourceLocation: sourceLocation)
            return
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        let converted = color.usingColorSpace(.sRGB) ?? color
        converted.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        #expect(abs(r - CGFloat(rgba.red)) < 0.02, sourceLocation: sourceLocation)
        #expect(abs(g - CGFloat(rgba.green)) < 0.02, sourceLocation: sourceLocation)
        #expect(abs(b - CGFloat(rgba.blue)) < 0.02, sourceLocation: sourceLocation)
    }
}
