import Foundation
import CoreGraphics
import SpriteKit
import LumiCore

public enum KittenNodeFactoryError: Error, Equatable {
    case missingTextures(Set<String>)
}

/// Builds the hand-painted "pastel kitten" rig from `KittenRig.json` and the
/// `LumiKitten` atlas. All art is pre-colored, so nothing is tinted.
///
/// The rig follows the same `pet.*` naming contract as `PetNodeFactory`, so
/// breathing, blinking, gaze, ear twitches, tail sway and weight shift work
/// unchanged. Rotating parts (tail, ears, head) use their painted pivots as
/// `anchorPoint`, so they turn around the tail root, ear base and neck.
///
/// Expression layers (brows, mouth shapes, closed eyes) are built too and
/// exposed through `PetRig.faceParts`; only the neutral face is visible.
@MainActor
public struct KittenNodeFactory {
    private let layout: KittenRigLayout
    private let texture: (String) -> SKTexture?

    public init(layout: KittenRigLayout, texture: @escaping (String) -> SKTexture?) {
        self.layout = layout
        self.texture = texture
    }

    /// Looks textures up in `atlas`, treating names the atlas lacks as missing.
    public init(layout: KittenRigLayout, atlas: SKTextureAtlas) {
        let names = Set(atlas.textureNames.map(Self.normalize))
        self.init(layout: layout, texture: { name in
            names.contains(name) ? atlas.textureNamed(name) : nil
        })
    }

    public func makeRig(presentation: PetPresentation) throws -> PetRig {
        let missing = Set(KittenRigLayout.requiredPartNames.filter { texture($0) == nil })
        guard missing.isEmpty else { throw KittenNodeFactoryError.missingTextures(missing) }

        var faceParts: [String: SKNode] = [:]

        // MARK: Root
        let root = SKNode()
        root.name = "pet.root"

        let shadow = try sprite("pet.shadow", part: "k_shadow", in: root, z: -20)

        // Tail rotates around its root (pivot) and sits behind the body.
        let tail = try sprite("pet.tail", part: "k_tail", in: root, z: -10)

        // MARK: Body
        let body = try container("pet.body", at: layout.center(of: "k_body"), in: root, z: 0)
        _ = try sprite("pet.body.base", part: "k_body", in: body, z: 0)

        // No separate belly layer: the abdomen is an (empty) breathing pivot at
        // the chest so the composer's abdomen channel still has a node.
        let chestCenter = try layout.center(of: "k_chest")
        let abdomen = try container("pet.abdomen", at: chestCenter, in: body, z: 1)
        let chest = try container("pet.chest", at: chestCenter, in: body, z: 3)
        let chestTuft = try sprite("pet.chest.tuft", part: "k_chest", in: chest, z: 0)

        // MARK: Paws (planted on the root while the body breathes)
        let leftPaw = try layout.center(of: "k_paw_left")
        let rightPaw = try layout.center(of: "k_paw_right")
        let pawsCenter = CGPoint(x: (leftPaw.x + rightPaw.x) / 2, y: (leftPaw.y + rightPaw.y) / 2)
        let paws = try container("pet.paws", at: pawsCenter, in: root, z: 4)
        _ = try sprite("pet.paw.left", part: "k_paw_left", in: paws, z: 0)
        _ = try sprite("pet.paw.right", part: "k_paw_right", in: paws, z: 0)

        // MARK: Head (container sits at the neck so head tilts pivot there)
        let head = try container("pet.head", at: layout.anchorPosition(of: "k_head"), in: root, z: 10)
        _ = try sprite("pet.head.base", part: "k_head", in: head, z: 0)

        let ears = try container("pet.ears", at: absolute(head), in: head, z: -1)
        let leftEar = try sprite("pet.ear.left", part: "k_ear_left", in: ears, z: 0)
        let rightEar = try sprite("pet.ear.right", part: "k_ear_left", in: ears, z: 0, mirrored: true)

        let headTuft = try sprite("pet.headTuft", part: "k_hair", in: head, z: 2)

        let cheeks = try container("pet.cheeks", at: absolute(head), in: head, z: 3)
        let leftCheek = try sprite("pet.cheek.left", part: "k_blush_left", in: cheeks, z: 0)
        let rightCheek = try sprite("pet.cheek.right", part: "k_blush_left", in: cheeks, z: 0, mirrored: true)

        // Mouth shapes share one container; only the neutral one is visible.
        let muzzle = try container("pet.muzzle", at: layout.center(of: "k_mouth_neutral"), in: head, z: 4)
        for (name, part) in [
            ("pet.mouth.neutral", "k_mouth_neutral"),
            ("pet.mouth.smile", "k_mouth_smile"),
            ("pet.mouth.o", "k_mouth_o"),
            ("pet.mouth.sad", "k_mouth_sad")
        ] {
            let mouth = try sprite(name, part: part, in: muzzle, z: 0)
            mouth.isHidden = part != "k_mouth_neutral"
            faceParts[name] = mouth
        }

        let nose = try sprite("pet.nose", part: "k_nose", in: head, z: 5)

        // MARK: Eyes
        let eyes = try container("pet.eyes", at: absolute(head), in: head, z: 6)
        let leftEye = try makeEye(side: "left", in: eyes, faceParts: &faceParts)
        let rightEye = try makeEye(side: "right", in: eyes, faceParts: &faceParts)

        // MARK: Brows (one painted brow, mirrored for the right side)
        let brows = try container("pet.brows", at: absolute(head), in: head, z: 7)
        faceParts["pet.brow.left"] = try sprite("pet.brow.left", part: "k_brow_left", in: brows, z: 0)
        faceParts["pet.brow.right"] = try sprite("pet.brow.right", part: "k_brow_left", in: brows, z: 0, mirrored: true)

        return PetRig(
            root: root,
            shadow: shadow,
            tail: tail,
            body: body,
            abdomen: abdomen,
            chest: chest,
            paws: paws,
            head: head,
            ears: ears,
            leftEar: leftEar,
            rightEar: rightEar,
            eyes: eyes,
            leftEye: leftEye.eye,
            rightEye: rightEye.eye,
            leftEyelid: leftEye.lid,
            rightEyelid: rightEye.lid,
            muzzle: muzzle,
            nose: nose,
            headTuft: headTuft,
            chestTuft: chestTuft,
            leftCheek: leftCheek,
            rightCheek: rightCheek,
            magic: nil,
            bodyPattern: nil,
            facePattern: nil,
            faceParts: faceParts
        )
    }

    // MARK: - Eyes

    private struct Eye {
        let eye: SKSpriteNode
        let lid: SKSpriteNode
    }

    /// Builds one eye. The iris, pupil and catchlights are painted once, in the
    /// LEFT eye; the right eye reuses them. Iris and pupil offsets are mirrored
    /// for the right eye, catchlight offsets are not (the light comes from the
    /// same side for both eyes).
    private func makeEye(side: String, in eyes: SKNode, faceParts: inout [String: SKNode]) throws -> Eye {
        let prefix = "pet.eye.\(side)"
        let isRight = side == "right"
        let eye = try sprite(prefix, part: "k_eye_white_\(side)", in: eyes, z: 0)

        let leftEyeCenter = try layout.center(of: "k_eye_white_left")
        func offset(_ part: String, mirror: Bool) throws -> CGPoint {
            let c = try layout.center(of: part)
            let dx = c.x - leftEyeCenter.x
            let dy = c.y - leftEyeCenter.y
            return CGPoint(x: isRight && mirror ? -dx : dx, y: dy)
        }

        let iris = try plainSprite("\(prefix).iris", part: "k_iris")
        iris.position = try offset("k_iris", mirror: true)
        iris.zPosition = 1
        eye.addChild(iris)

        let pupil = try plainSprite("\(prefix).pupil", part: "k_pupil")
        pupil.position = try offset("k_pupil", mirror: true)
        pupil.zPosition = 2
        eye.addChild(pupil)

        // The small catchlight rides on the big one so gaze moves both.
        let catchlight = try plainSprite("\(prefix).catchlight", part: "k_catchlight_big")
        catchlight.position = try offset("k_catchlight_big", mirror: false)
        catchlight.zPosition = 3
        eye.addChild(catchlight)

        let small = try plainSprite("\(prefix).catchlight.small", part: "k_catchlight_small")
        let big = try layout.center(of: "k_catchlight_big")
        let smallCenter = try layout.center(of: "k_catchlight_small")
        small.position = CGPoint(x: smallCenter.x - big.x, y: smallCenter.y - big.y)
        catchlight.addChild(small)

        // Lid: fully covers the eye; the blink controller drives its alpha.
        let lid = try sprite("\(prefix).lid", part: "k_lid_\(side)", in: eye, z: 4)
        lid.alpha = 0

        // Closed-eye overlays for expressions (hidden in the neutral face).
        for kind in ["happy", "closed"] {
            let name = "\(prefix).\(kind)"
            let overlay = try sprite(name, part: "k_eye_\(kind)_\(side)", in: eye, z: 5)
            overlay.isHidden = true
            faceParts[name] = overlay
        }

        return Eye(eye: eye, lid: lid)
    }

    // MARK: - Node construction

    /// An untransformed container placed at `position` (root-local) inside `parent`.
    private func container(_ name: String, at position: CGPoint, in parent: SKNode, z: CGFloat) throws -> SKNode {
        let node = SKNode()
        node.name = name
        node.position = subtract(position, absolute(parent))
        node.zPosition = z
        parent.addChild(node)
        return node
    }

    /// A sprite placed exactly where `part` was painted, relative to `parent`.
    /// `mirrored` flips it horizontally around the canvas center line (for the
    /// right-hand copy of a left-only part).
    @discardableResult
    private func sprite(
        _ name: String,
        part: String,
        in parent: SKNode,
        z: CGFloat,
        mirrored: Bool = false
    ) throws -> SKSpriteNode {
        let node = try plainSprite(name, part: part)
        var position = try layout.anchorPosition(of: part)
        if mirrored {
            position.x = -position.x
            node.xScale = -1
        }
        node.position = subtract(position, absolute(parent))
        node.zPosition = z
        parent.addChild(node)
        return node
    }

    /// A sized, untinted sprite with the part's pivot as anchor, not yet placed.
    private func plainSprite(_ name: String, part: String) throws -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture(part))
        node.name = name
        node.size = try layout.size(of: part)
        node.anchorPoint = try layout.anchorPoint(of: part)
        node.colorBlendFactor = 0
        return node
    }

    /// The node's position in root-local space. Containers above the parts are
    /// never scaled or rotated at build time, so summing positions is exact.
    private func absolute(_ node: SKNode) -> CGPoint {
        var point = CGPoint.zero
        var current: SKNode? = node
        while let n = current, n.name != "pet.root" {
            point.x += n.position.x
            point.y += n.position.y
            current = n.parent
        }
        return point
    }

    private func subtract(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: a.x - b.x, y: a.y - b.y)
    }

    private static func normalize(_ name: String) -> String {
        var result = name
        if result.hasSuffix(".png") { result.removeLast(4) }
        for suffix in ["@2x", "@3x"] where result.hasSuffix(suffix) { result.removeLast(3) }
        return result
    }
}
