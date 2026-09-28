import Foundation
import CoreGraphics
import SpriteKit

/// A real, anatomically-styled eyelid for the kitten rig.
///
/// The eye underneath stays fully open at all times. This node is an
/// `SKCropNode` masked to the eye shape; inside it a fur "curtain" (the painted
/// lid, whose bottom edge is the lash margin) slides straight **down** to cover
/// the eye as the blink progresses, then back up — exactly like a real eyelid.
///
/// The rig exposes this node as `leftEyelid` / `rightEyelid`, and
/// `SecondaryMotionController` drives it by writing `alpha` in `0...1` (its blink
/// curve). To avoid changing that controller, this subclass **reinterprets
/// `alpha` as the blink amount**: `0` = lid fully up (eye open), `1` = lid fully
/// down (eye covered). The node's own opacity is always 1 while covering, so the
/// lid reads as an opaque eyelid, not a fade.
public final class BlinkLidNode: SKCropNode {
    private let lid: SKSpriteNode
    /// Vertical distance the lid travels from "parked above the eye" (open) to
    /// "covering the eye" (closed), in the node's local points.
    private let travel: CGFloat
    /// Local y of the lid at rest (fully open) — parked just above the eye.
    private let openY: CGFloat

    private var blinkAmount: CGFloat = 0

    /// - Parameters:
    ///   - lid: the fur eyelid-curtain sprite (bottom edge = lash margin), whose
    ///     `position` is where it sits when the eye is fully CLOSED.
    ///   - mask: an opaque eye-shaped sprite used as the crop mask.
    ///   - travel: how far (points) the lid slides to fully cover the eye.
    public init(lid: SKSpriteNode, mask: SKSpriteNode, travel: CGFloat) {
        self.lid = lid
        self.travel = travel
        self.openY = lid.position.y + travel   // parked one travel ABOVE closed
        super.init()
        maskNode = mask
        lid.position.y = openY
        addChild(lid)
        updateLid()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Reinterpreted as blink amount: 0 = open, 1 = fully closed. The crop node
    /// itself stays fully opaque so the descending lid looks solid.
    public override var alpha: CGFloat {
        get { blinkAmount }
        set {
            blinkAmount = max(0, min(1, newValue))
            updateLid()
        }
    }

    private func updateLid() {
        // Slide the lid down from openY by `blinkAmount * travel`.
        lid.position.y = openY - blinkAmount * travel
    }
}
