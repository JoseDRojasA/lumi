import Foundation
import CoreGraphics
import SpriteKit
import LumiCore

public struct PetNodeTransform: Equatable, Sendable {
    public let position: CGPoint
    public let xScale: CGFloat
    public let yScale: CGFloat
    public let zRotation: CGFloat

    public init(position: CGPoint, xScale: CGFloat, yScale: CGFloat, zRotation: CGFloat) {
        self.position = position
        self.xScale = xScale
        self.yScale = yScale
        self.zRotation = zRotation
    }

    @MainActor
    init(capturing node: SKNode) {
        self.position = node.position
        self.xScale = node.xScale
        self.yScale = node.yScale
        self.zRotation = node.zRotation
    }

    @MainActor
    func apply(to node: SKNode) {
        node.position = position
        node.xScale = xScale
        node.yScale = yScale
        node.zRotation = zRotation
    }
}

public struct PetRigBaseTransforms: Equatable, Sendable {
    public let root: PetNodeTransform
    public let abdomen: PetNodeTransform
    public let chest: PetNodeTransform
    public let head: PetNodeTransform
    public let paws: PetNodeTransform
    public let leftEar: PetNodeTransform
    public let rightEar: PetNodeTransform
    public let tail: PetNodeTransform
    public let chestTuft: PetNodeTransform?
    public let leftCheek: PetNodeTransform?
    public let rightCheek: PetNodeTransform?

    public init(
        root: PetNodeTransform,
        abdomen: PetNodeTransform,
        chest: PetNodeTransform,
        head: PetNodeTransform,
        paws: PetNodeTransform,
        leftEar: PetNodeTransform,
        rightEar: PetNodeTransform,
        tail: PetNodeTransform,
        chestTuft: PetNodeTransform?,
        leftCheek: PetNodeTransform?,
        rightCheek: PetNodeTransform?
    ) {
        self.root = root
        self.abdomen = abdomen
        self.chest = chest
        self.head = head
        self.paws = paws
        self.leftEar = leftEar
        self.rightEar = rightEar
        self.tail = tail
        self.chestTuft = chestTuft
        self.leftCheek = leftCheek
        self.rightCheek = rightCheek
    }
}

/// A fully assembled, semantically-named SpriteKit pet rig. Node references are
/// read-only; consumers animate them and can reset with `restoreBaseTransforms()`.
@MainActor
public final class PetRig {
    public let root: SKNode
    public let shadow: SKNode
    public let tail: SKNode
    public let body: SKNode
    public let abdomen: SKNode
    public let chest: SKNode
    public let paws: SKNode
    public let head: SKNode
    public let ears: SKNode
    public let leftEar: SKNode
    public let rightEar: SKNode
    public let eyes: SKNode
    public let leftEye: SKNode
    public let rightEye: SKNode
    public let leftEyelid: SKNode
    public let rightEyelid: SKNode
    public let muzzle: SKNode
    public let nose: SKNode

    public let headTuft: SKNode?
    public let chestTuft: SKNode?
    public let leftCheek: SKNode?
    public let rightCheek: SKNode?
    public let magic: SKNode?
    public let bodyPattern: SKNode?
    public let facePattern: SKNode?

    public let base: PetRigBaseTransforms
    public let requiredNodes: [SKNode]

    init(
        root: SKNode,
        shadow: SKNode,
        tail: SKNode,
        body: SKNode,
        abdomen: SKNode,
        chest: SKNode,
        paws: SKNode,
        head: SKNode,
        ears: SKNode,
        leftEar: SKNode,
        rightEar: SKNode,
        eyes: SKNode,
        leftEye: SKNode,
        rightEye: SKNode,
        leftEyelid: SKNode,
        rightEyelid: SKNode,
        muzzle: SKNode,
        nose: SKNode,
        headTuft: SKNode?,
        chestTuft: SKNode?,
        leftCheek: SKNode?,
        rightCheek: SKNode?,
        magic: SKNode?,
        bodyPattern: SKNode?,
        facePattern: SKNode?
    ) {
        self.root = root
        self.shadow = shadow
        self.tail = tail
        self.body = body
        self.abdomen = abdomen
        self.chest = chest
        self.paws = paws
        self.head = head
        self.ears = ears
        self.leftEar = leftEar
        self.rightEar = rightEar
        self.eyes = eyes
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.leftEyelid = leftEyelid
        self.rightEyelid = rightEyelid
        self.muzzle = muzzle
        self.nose = nose
        self.headTuft = headTuft
        self.chestTuft = chestTuft
        self.leftCheek = leftCheek
        self.rightCheek = rightCheek
        self.magic = magic
        self.bodyPattern = bodyPattern
        self.facePattern = facePattern

        self.requiredNodes = [
            root, body, abdomen, chest, head,
            leftEye, rightEye, leftEar, rightEar,
            tail, paws, shadow
        ]

        self.base = PetRigBaseTransforms(
            root: PetNodeTransform(capturing: root),
            abdomen: PetNodeTransform(capturing: abdomen),
            chest: PetNodeTransform(capturing: chest),
            head: PetNodeTransform(capturing: head),
            paws: PetNodeTransform(capturing: paws),
            leftEar: PetNodeTransform(capturing: leftEar),
            rightEar: PetNodeTransform(capturing: rightEar),
            tail: PetNodeTransform(capturing: tail),
            chestTuft: chestTuft.map(PetNodeTransform.init(capturing:)),
            leftCheek: leftCheek.map(PetNodeTransform.init(capturing:)),
            rightCheek: rightCheek.map(PetNodeTransform.init(capturing:))
        )
    }

    /// Restores every captured base transform, undoing any animation mutations.
    public func restoreBaseTransforms() {
        base.root.apply(to: root)
        base.abdomen.apply(to: abdomen)
        base.chest.apply(to: chest)
        base.head.apply(to: head)
        base.paws.apply(to: paws)
        base.leftEar.apply(to: leftEar)
        base.rightEar.apply(to: rightEar)
        base.tail.apply(to: tail)
        if let t = base.chestTuft, let node = chestTuft { t.apply(to: node) }
        if let t = base.leftCheek, let node = leftCheek { t.apply(to: node) }
        if let t = base.rightCheek, let node = rightCheek { t.apply(to: node) }
    }
}
