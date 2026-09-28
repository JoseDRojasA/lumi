import Foundation
import CoreGraphics
import SpriteKit
import Testing
@testable import LumiCore
@testable import LumiRendering

@MainActor
struct KittenRigTests {

    // MARK: Fixtures

    private static var layoutURL: URL {
        RenderingFixtures.repoRoot.appendingPathComponent("app").appendingPathComponent("KittenRig.json")
    }

    private func realLayout() throws -> KittenRigLayout {
        try KittenRigLayout.decode(Data(contentsOf: Self.layoutURL))
    }

    private func makeRig(missing: Set<String> = []) throws -> PetRig {
        let factory = KittenNodeFactory(layout: try realLayout()) { name in
            missing.contains(name) ? nil : RenderingFixtures.solidTexture()
        }
        let configuration = try PetGenerator.generate(seed: 7, version: 1)
        return try factory.makeRig(presentation: PetPresentation(configuration: configuration))
    }

    /// A node's position in root-local space (containers are unscaled at build time).
    private func rootPosition(_ node: SKNode) -> CGPoint {
        var point = CGPoint.zero
        var current: SKNode? = node
        while let n = current, n.name != "pet.root" {
            point.x += n.position.x
            point.y += n.position.y
            current = n.parent
        }
        return point
    }

    /// SpriteKit stores positions/anchors as Float, so compare with a tolerance.
    private func close(_ a: CGPoint, _ b: CGPoint, _ tolerance: CGFloat = 0.01) -> Bool {
        abs(a.x - b.x) < tolerance && abs(a.y - b.y) < tolerance
    }

    // MARK: Layout

    @Test func shippedLayoutHasEveryPartAndPivot() throws {
        let layout = try realLayout()
        for name in KittenRigLayout.requiredPartNames {
            let part = try layout.part(name)
            #expect(part.width > 0 && part.height > 0, "\(name)")
            #expect((0...1).contains(part.x) && (0...1).contains(part.y), "\(name)")
        }
        for name in KittenRigLayout.pivotedPartNames {
            let part = try layout.part(name)
            #expect(part.pivotX != nil && part.pivotY != nil, "\(name) needs a pivot")
        }
    }

    @Test func decodeRejectsMissingPartAndBadVersion() throws {
        let missing = #"{"version":1,"canvas":{"width":1024,"height":1024},"parts":{}}"#
        #expect(throws: KittenRigLayoutError.missingPart("k_shadow")) {
            try KittenRigLayout.decode(Data(missing.utf8))
        }
        let badVersion = #"{"version":2,"canvas":{"width":1024,"height":1024},"parts":{}}"#
        #expect(throws: KittenRigLayoutError.unsupportedVersion(2)) {
            try KittenRigLayout.decode(Data(badVersion.utf8))
        }
    }

    @Test func anchorPositionUsesPivot() throws {
        let json = #"""
        {"version":1,"canvas":{"width":1000,"height":1000},
         "parts":{"p":{"x":0.5,"y":0.5,"width":100,"height":200,"pivotX":0.25,"pivotY":0}}}
        """#
        let layout = try JSONDecoder().decode(KittenRigLayout.self, from: Data(json.utf8))
        #expect(try layout.anchorPosition(of: "p") == CGPoint(x: -25, y: -100))
        #expect(try layout.anchorPoint(of: "p") == CGPoint(x: 0.25, y: 0))
    }

    // MARK: Rig

    @Test func buildsNamedRigForTheMotionControllers() throws {
        let rig = try makeRig()
        #expect(rig.root.name == "pet.root")
        #expect(rig.body.childNode(withName: "//pet.body.base") is SKSpriteNode)
        for eye in [rig.leftEye, rig.rightEye] {
            let name = try #require(eye.name)
            for child in [".iris", ".pupil", ".catchlight", ".lid"] {
                #expect(eye.childNode(withName: name + child) != nil, "\(name)\(child)")
            }
        }
        #expect(rig.leftEyelid.alpha == 0 && rig.rightEyelid.alpha == 0)
        #expect(rig.magic == nil)
        #expect(rig.headTuft != nil && rig.chestTuft != nil)
        #expect(rig.leftCheek != nil && rig.rightCheek != nil)
    }

    @Test func partsSitWherePainted() throws {
        let layout = try realLayout()
        let rig = try makeRig()
        #expect(close(rootPosition(rig.head), try layout.anchorPosition(of: "k_head")))
        #expect(close(rootPosition(rig.tail), try layout.anchorPosition(of: "k_tail")))
        #expect(close(rootPosition(rig.leftEar), try layout.anchorPosition(of: "k_ear_left")))
        #expect(close(rootPosition(rig.leftEye), try layout.center(of: "k_eye_white_left")))
        #expect(close(rootPosition(rig.nose), try layout.center(of: "k_nose")))
    }

    @Test func rotatingPartsUseTheirPivots() throws {
        let layout = try realLayout()
        let rig = try makeRig()
        let tail = try #require(rig.tail as? SKSpriteNode)
        #expect(close(tail.anchorPoint, try layout.anchorPoint(of: "k_tail"), 0.0001))
        let ear = try #require(rig.leftEar as? SKSpriteNode)
        #expect(close(ear.anchorPoint, try layout.anchorPoint(of: "k_ear_left"), 0.0001))
    }

    @Test func rightSideIsMirroredFromLeft() throws {
        let rig = try makeRig()
        #expect(rig.rightEar.xScale == -1)
        #expect(abs(rootPosition(rig.rightEar).x - (-rootPosition(rig.leftEar).x)) < 0.01)
        #expect(abs(rootPosition(rig.rightEar).y - rootPosition(rig.leftEar).y) < 0.01)
        let leftBrow = try #require(rig.faceParts["pet.brow.left"])
        let rightBrow = try #require(rig.faceParts["pet.brow.right"])
        #expect(rightBrow.xScale == -1)
        #expect(abs(rootPosition(rightBrow).x - (-rootPosition(leftBrow).x)) < 0.01)

        // Iris offsets mirror; catchlight offsets keep the same light direction.
        let leftIris = try #require(rig.leftEye.childNode(withName: "pet.eye.left.iris"))
        let rightIris = try #require(rig.rightEye.childNode(withName: "pet.eye.right.iris"))
        #expect(rightIris.position.x == -leftIris.position.x)
        let leftLight = try #require(rig.leftEye.childNode(withName: "pet.eye.left.catchlight"))
        let rightLight = try #require(rig.rightEye.childNode(withName: "pet.eye.right.catchlight"))
        #expect(rightLight.position == leftLight.position)
    }

    @Test func onlyTheNeutralFaceIsVisible() throws {
        let rig = try makeRig()
        #expect(rig.faceParts["pet.mouth.neutral"]?.isHidden == false)
        for name in ["pet.mouth.smile", "pet.mouth.o", "pet.mouth.sad",
                     "pet.eye.left.happy", "pet.eye.right.happy",
                     "pet.eye.left.closed", "pet.eye.right.closed"] {
            let node = try #require(rig.faceParts[name], "\(name)")
            #expect(node.isHidden, "\(name)")
        }
    }

    @Test func nothingIsTinted() throws {
        let rig = try makeRig()
        var sprites: [SKSpriteNode] = []
        rig.root.enumerateChildNodes(withName: "//*") { node, _ in
            if let sprite = node as? SKSpriteNode { sprites.append(sprite) }
        }
        #expect(sprites.count >= KittenRigLayout.requiredPartNames.count)
        #expect(sprites.allSatisfy { $0.colorBlendFactor == 0 })
    }

    @Test func missingTexturesAreReported() throws {
        #expect(throws: KittenNodeFactoryError.missingTextures(["k_tail", "k_nose"])) {
            _ = try makeRig(missing: ["k_tail", "k_nose"])
        }
    }

    // MARK: Scene

    @Test func sceneHostsKittenAndAnimates() throws {
        let rig = try makeRig()
        let configuration = try PetGenerator.generate(seed: 7, version: 1)
        let scene = PetScene(
            rig: rig,
            presentation: PetPresentation(configuration: configuration),
            policy: .phone,
            reduceMotion: false
        )
        let old = scene.size
        scene.size = CGSize(width: 390, height: 844)
        scene.didChangeSize(old)
        let frame = scene.characterFrameInScene
        #expect(abs(frame.midX) <= 0.5 && abs(frame.midY) <= 0.5)
        #expect(abs(max(frame.width, frame.height) - 390 * PetRenderPolicy.phone.sizeFraction) < 2)

        // Advancing secondary motion must not throw or leave lids stuck shut.
        scene.startAnimation()
        for i in 0..<600 { scene.update(Double(i) / 60) }
        scene.stopAnimation()
        #expect(rig.leftEyelid.alpha == 0)
    }
}
