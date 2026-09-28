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

        // The abdomen carries the VISIBLE body sprite so the breathing controller's
        // abdomen scale channel visibly squashes/stretches the torso each breath.
        // It is centered on the body so the scale pivots around the torso center.
        let abdomen = try container("pet.abdomen", at: layout.center(of: "k_body"), in: body, z: 1)
        _ = try sprite("pet.body.base", part: "k_body", in: abdomen, z: 0)

        let chestCenter = try layout.center(of: "k_chest")
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
        let lid: SKNode
    }

    /// Builds one eye as a true two-state sprite pair:
    /// - `k_eye_open_<side>`: the painted open eye (iris/pupil/catchlight), cut
    ///   from the reference and placed where it was painted. Visible at rest.
    /// - `k_lid_<side>`: the painted CLOSED eye, layered directly above the open
    ///   eye with alpha 0 at rest. The blink controller raises its alpha to 1 to
    ///   swap the open sprite for the closed one (a real sprite swap/crossfade).
    ///
    /// Invisible iris/pupil/catchlight stubs are still attached (under the open
    /// eye) so `SecondaryMotionController`'s gaze code keeps finding its nodes;
    /// they carry no visible art now that the eye is a single painted sprite.
    private func makeEye(side: String, in eyes: SKNode, faceParts: inout [String: SKNode]) throws -> Eye {
        let prefix = "pet.eye.\(side)"
        let openPart = "k_eye_open_\(side)"

        // The open-eye sprite IS the eye node, placed at its painted position.
        let eye = try sprite(prefix, part: openPart, in: eyes, z: 0)

        // Gaze stubs: positioned at the eye center, invisible (the painted eye
        // already includes iris/pupil/catchlight). Kept so gaze has live nodes.
        let eyeCenter = try layout.center(of: openPart)
        func stub(_ suffix: String, part: String) throws -> SKSpriteNode {
            let node = try plainSprite("\(prefix).\(suffix)", part: part)
            let c = try layout.center(of: part)
            node.position = CGPoint(x: c.x - eyeCenter.x, y: c.y - eyeCenter.y)
            node.isHidden = true
            return node
        }

        let iris = try stub("iris", part: "k_iris")
        iris.zPosition = 1
        eye.addChild(iris)

        let pupil = try stub("pupil", part: "k_pupil")
        pupil.zPosition = 2
        eye.addChild(pupil)

        let catchlight = try stub("catchlight", part: "k_catchlight_big")
        catchlight.zPosition = 3
        eye.addChild(catchlight)

        let small = try stub("catchlight.small", part: "k_catchlight_small")
        catchlight.addChild(small)

        // Sliding eyelid: a fur curtain clipped to the eye by a crop mask. The
        // eye stays open underneath; the controller writes `alpha` (0=open,
        // 1=closed) and the lid slides straight down to cover the eye.
        let lidSprite = try plainSprite("\(prefix).lid.curtain", part: "k_lid_\(side)")
        let lidCenter = try layout.center(of: "k_lid_\(side)")
        // Position (its CLOSED resting place) is the lid's painted offset in eye-local space.
        lidSprite.position = CGPoint(x: lidCenter.x - eyeCenter.x, y: lidCenter.y - eyeCenter.y)

        let maskSprite = try plainSprite("\(prefix).lid.mask", part: "k_eye_mask_\(side)")
        let maskCenter = try layout.center(of: "k_eye_mask_\(side)")
        maskSprite.position = CGPoint(x: maskCenter.x - eyeCenter.x, y: maskCenter.y - eyeCenter.y)

        // Travel = eye height, so at blink 1 the lid fully covers the socket.
        let travel = try layout.size(of: "k_eye_mask_\(side)").height
        let lid = BlinkLidNode(lid: lidSprite, mask: maskSprite, travel: travel)
        lid.name = "\(prefix).lid"
        lid.zPosition = 4
        eye.addChild(lid)

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
