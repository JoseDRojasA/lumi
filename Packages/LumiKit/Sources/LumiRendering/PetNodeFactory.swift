import Foundation
import CoreGraphics
import SpriteKit
import LumiCore

/// Builds a semantic SpriteKit rig from a `PetPresentation`. Pure assembly: it
/// never runs actions, never imports SwiftData, and never calls `PetGenerator`.
@MainActor
public struct PetNodeFactory {
    private let catalog: PetTextureCatalog
    private let layout: PetRigLayout

    public init(catalog: PetTextureCatalog, layout: PetRigLayout) {
        self.catalog = catalog
        self.layout = layout
    }

    public func makeRig(presentation: PetPresentation) throws -> PetRig {
        let config = presentation.configuration
        let palette = config.palette

        // Anchor points in root-local space.
        let bodyAnchor = layout.point(for: "body")
        let headAnchor = layout.point(for: "head")

        // MARK: Root
        let root = SKNode()
        root.name = "pet.root"

        // MARK: Shadow (relative to root)
        let shadow = makeSprite(
            name: "pet.shadow",
            texture: "shadow_diffuse",
            fallback: "shadow_diffuse",
            designName: "shadow_diffuse",
            tint: nil
        )
        shadow.position = layout.point(for: "shadow")
        shadow.zPosition = -20
        shadow.alpha = 1
        root.addChild(shadow)

        // MARK: Tail (relative to root), width × thickness, height × length
        //
        // The tail sprite's anchorPoint is set to the tail's ROOT (the base of
        // the spine within the texture), NOT its centre. That way (a) scaling by
        // thickness/length grows the tail AWAY from the root, (b) sway rotation
        // pivots at the root, and (c) placing that anchor at a socket inside the
        // body silhouette guarantees the base always tucks behind the body for
        // every style and the full thickness/length range.
        let tailDesign = try (try? layout.designSize(of: "tail_\(config.tail.tailStyle.rawValue)"))
            ?? layout.designSize(of: "fallback_tail")
        let tail = makeSprite(
            name: "pet.tail",
            texture: "tail_\(config.tail.tailStyle.rawValue)",
            fallback: "fallback_tail",
            explicitSize: CGSize(
                width: tailDesign.width * CGFloat(config.tail.tailThickness),
                height: tailDesign.height * CGFloat(config.tail.tailLength)
            ),
            tint: palette.baseColor
        )
        tail.anchorPoint = Self.tailRootAnchor(for: config.tail.tailStyle)
        // Socket: inside the body silhouette on the tail side. The body.base is
        // centred on `bodyAnchor` with half-width `bodyHalfWidth`; pull the
        // socket inward from the body's right edge so even the smallest body
        // fully contains the tail root.
        let bodyBaseDesignForSocket = try (try? layout.designSize(of: "body_\(config.body.bodyShape.rawValue)"))
            ?? layout.designSize(of: "fallback_body")
        let bodyHalfWidth = bodyBaseDesignForSocket.width * CGFloat(config.body.bodyScale) / 2
        let bodyHalfHeight = bodyBaseDesignForSocket.height * CGFloat(config.body.bodyScale) / 2
        // Keep the socket on the same side as the original tail anchor (right),
        // but clamp it well inside the body so it can never float free.
        let tailSideSign: CGFloat = layout.point(for: "tail").x >= bodyAnchor.x ? 1 : -1
        tail.position = CGPoint(
            x: bodyAnchor.x + tailSideSign * bodyHalfWidth * 0.42,
            y: bodyAnchor.y + bodyHalfHeight * 0.02
        )
        tail.zPosition = -10
        root.addChild(tail)

        // MARK: Body container (carries body anchor)
        let body = SKNode()
        body.name = "pet.body"
        body.position = bodyAnchor
        body.zPosition = 0
        root.addChild(body)

        let bodyScale = CGFloat(config.body.bodyScale)

        // body.base
        let bodyBaseDesign = try (try? layout.designSize(of: "body_\(config.body.bodyShape.rawValue)"))
            ?? layout.designSize(of: "fallback_body")
        let bodyBase = makeSprite(
            name: "pet.body.base",
            texture: "body_\(config.body.bodyShape.rawValue)",
            fallback: "fallback_body",
            explicitSize: scaled(bodyBaseDesign, by: bodyScale),
            tint: palette.baseColor
        )
        bodyBase.position = .zero
        bodyBase.zPosition = 0
        body.addChild(bodyBase)

        // abdomen (anchor abdomen - body), tint secondary, size × bodyScale
        let abdomenDesign = try layout.designSize(of: "abdomen_soft")
        let abdomen = makeSprite(
            name: "pet.abdomen",
            texture: "abdomen_soft",
            fallback: "fallback_body",
            explicitSize: scaled(abdomenDesign, by: bodyScale),
            tint: palette.secondaryColor
        )
        abdomen.position = subtract(layout.point(for: "abdomen"), bodyAnchor)
        abdomen.zPosition = 1
        body.addChild(abdomen)

        // body.pattern (spots/stripes/gradient) tint accent, alpha 0.35+0.5*density,
        // size × bodyScale × patternScale, CLIPPED to the body silhouette.
        //
        // The pattern sprite is wrapped in an SKCropNode named `pet.body.pattern`
        // whose maskNode is an SKSpriteNode duplicating body.base's
        // texture/size/position (alpha-based mask) so only pixels inside the body
        // are visible — never a translucent disc overflowing the outline. The
        // crop lives in the SAME parent space as body.base (both children of
        // `pet.body`, both at .zero), so any body/abdomen breathing scale applied
        // to the container transforms the mask and the pattern identically.
        var bodyPattern: SKNode? = nil
        if let patternTexture = bodyPatternTexture(for: config.body.patternStyle) {
            // Cap the pattern so it never exceeds the base part (in addition to
            // clipping): patternScale relative to the base is clamped to ≤ 1.0,
            // then the final size is clamped to the body base size so the crop's
            // accumulated frame (union of mask + content) never exceeds the body.
            let patternScale = bodyScale * min(CGFloat(config.body.patternScale), 1.0)
            if let design = try? layout.designSize(of: patternTexture),
               catalog.contains(patternTexture) {
                let scaledDesign = scaled(design, by: patternScale)
                let cappedSize = CGSize(
                    width: min(scaledDesign.width, bodyBase.size.width),
                    height: min(scaledDesign.height, bodyBase.size.height)
                )
                let sprite = makeSprite(
                    name: "pet.body.pattern.sprite",
                    texture: patternTexture,
                    fallback: patternTexture,
                    explicitSize: cappedSize,
                    tint: palette.accentColor
                )
                sprite.position = .zero
                sprite.alpha = 0.35 + 0.5 * CGFloat(config.body.patternDensity)
                let crop = makeCrop(
                    name: "pet.body.pattern",
                    maskFrom: bodyBase,
                    maskPosition: bodyBase.position,
                    content: sprite,
                    zPosition: 2
                )
                crop.position = .zero
                body.addChild(crop)
                bodyPattern = crop
            }
        }

        // chest container (always present, anchor chest - body)
        let chest = SKNode()
        chest.name = "pet.chest"
        chest.position = subtract(layout.point(for: "chest"), bodyAnchor)
        chest.zPosition = 3
        body.addChild(chest)

        // chest.tuft (style != none) tint secondary, size × bodyScale
        var chestTuft: SKNode? = nil
        if config.details.chestTuftStyle != .none {
            let textureName = "chesttuft_\(config.details.chestTuftStyle.rawValue)"
            if catalog.contains(textureName), let design = try? layout.designSize(of: textureName) {
                let node = makeSprite(
                    name: "pet.chest.tuft",
                    texture: textureName,
                    fallback: textureName,
                    explicitSize: scaled(design, by: bodyScale),
                    tint: palette.secondaryColor
                )
                node.position = .zero
                node.zPosition = 0
                chest.addChild(node)
                chestTuft = node
            }
        }

        // MARK: Paws (child of ROOT — planted while body breathes)
        let pawsDesign = try layout.designSize(of: "paws_round")
        let paws = makeSprite(
            name: "pet.paws",
            texture: "paws_round",
            fallback: "fallback_paws",
            explicitSize: pawsDesign,
            tint: palette.baseColor
        )
        // Anchor the paws at the layout point, but never let them sit so low that
        // they detach from the belly. On the smallest bodies the rounded body tip
        // and the belly (abdomen) narrow to almost nothing, leaving the paws
        // bridged by only a few anti-aliased pixels (reads as a detached blob).
        // Raise the paws so their TOP tucks a solid margin into the belly.
        let pawsPoint = layout.point(for: "paws")
        let abdomenDesignForPaws = try layout.designSize(of: "abdomen_soft")
        let abdomenCenterY = layout.point(for: "abdomen").y
        let abdomenBottom = abdomenCenterY - abdomenDesignForPaws.height * CGFloat(config.body.bodyScale) / 2
        let pawsHalfHeight = pawsDesign.height / 2
        // The paws' top edge (y + halfHeight) must reach at least a small margin
        // above the belly bottom so the silhouette stays a single blob.
        let minPawsTop = abdomenBottom + pawsHalfHeight * 0.35
        let minPawsY = minPawsTop - pawsHalfHeight
        paws.position = CGPoint(x: pawsPoint.x, y: max(pawsPoint.y, minPawsY))
        paws.zPosition = 4
        root.addChild(paws)

        // paws.pattern (socks) tint accent, CLIPPED to the paws silhouette.
        if config.body.patternStyle == .socks, catalog.contains("pattern_socks"),
           let design = try? layout.designSize(of: "pattern_socks") {
            // Cap the socks so they never exceed the paws sprite.
            let cappedSize = CGSize(
                width: min(design.width, pawsDesign.width),
                height: min(design.height, pawsDesign.height)
            )
            let sprite = makeSprite(
                name: "pet.paws.pattern.sprite",
                texture: "pattern_socks",
                fallback: "pattern_socks",
                explicitSize: cappedSize,
                tint: palette.accentColor
            )
            sprite.position = .zero
            // Mask: a sprite duplicating the paws texture/size/position so the
            // socks only show where the paws are. The crop is a child of paws at
            // .zero, so the paws' local transform applies to both equally.
            let crop = makeCrop(
                name: "pet.paws.pattern",
                maskFrom: paws,
                maskPosition: .zero,
                content: sprite,
                zPosition: 0
            )
            crop.position = .zero
            paws.addChild(crop)
        }

        // MARK: Head container (carries head anchor)
        let head = SKNode()
        head.name = "pet.head"
        head.position = headAnchor
        head.zPosition = 10
        root.addChild(head)

        let headScale = CGFloat(config.body.headScale)

        // ears container
        let ears = SKNode()
        ears.name = "pet.ears"
        ears.position = .zero
        ears.zPosition = -1
        head.addChild(ears)

        let earDesign = try (try? layout.designSize(of: "ear_\(config.ears.earStyle.rawValue)"))
            ?? layout.designSize(of: "fallback_ear")
        let earSize = scaled(earDesign, by: CGFloat(config.ears.earScale))
        let earRotation = CGFloat(config.ears.earAngle - 0.5) * 0.35

        let leftEar = makeSprite(
            name: "pet.ear.left",
            texture: "ear_\(config.ears.earStyle.rawValue)",
            fallback: "fallback_ear",
            explicitSize: earSize,
            tint: palette.baseColor
        )
        leftEar.position = subtract(layout.point(for: "leftEar"), headAnchor)
        leftEar.zRotation = earRotation
        leftEar.xScale = 1
        ears.addChild(leftEar)

        let rightEar = makeSprite(
            name: "pet.ear.right",
            texture: "ear_\(config.ears.earStyle.rawValue)",
            fallback: "fallback_ear",
            explicitSize: earSize,
            tint: palette.baseColor
        )
        rightEar.position = subtract(layout.point(for: "rightEar"), headAnchor)
        rightEar.zRotation = -earRotation
        rightEar.xScale = -1 // mirrored
        ears.addChild(rightEar)

        // head.base — uses fur variant, fallback fallback_head, tint base, × headScale
        let headVariant = layout.headVariant(for: config.body.furStyle) ?? "fallback_head"
        let headDesign = try (try? layout.designSize(of: headVariant)) ?? layout.designSize(of: "fallback_head")
        let headBase = makeSprite(
            name: "pet.head.base",
            texture: headVariant,
            fallback: "fallback_head",
            explicitSize: scaled(headDesign, by: headScale),
            tint: palette.baseColor
        )
        headBase.position = .zero
        headBase.zPosition = 0
        head.addChild(headBase)

        // facePattern (mask) tint accent, × headScale, CLIPPED to the head
        // silhouette. Mask duplicates head.base's fur-variant texture/size/pos so
        // the face mask only shows on the head. The crop lives in head space at
        // .zero, alongside head.base, so headScale/breathing transforms apply
        // equally to the mask and the pattern.
        var facePattern: SKNode? = nil
        if config.body.patternStyle == .mask, catalog.contains("pattern_mask"),
           let design = try? layout.designSize(of: "pattern_mask") {
            // Cap the face pattern so it never exceeds the head base.
            let cappedSize = CGSize(
                width: min(design.width * headScale, headBase.size.width),
                height: min(design.height * headScale, headBase.size.height)
            )
            let sprite = makeSprite(
                name: "pet.facePattern.sprite",
                texture: "pattern_mask",
                fallback: "pattern_mask",
                explicitSize: cappedSize,
                tint: palette.accentColor
            )
            sprite.position = .zero
            let crop = makeCrop(
                name: "pet.facePattern",
                maskFrom: headBase,
                maskPosition: headBase.position,
                content: sprite,
                zPosition: 1
            )
            crop.position = .zero
            head.addChild(crop)
            facePattern = crop
        }

        // headTuft (style != none) tint accent, relative to head
        var headTuft: SKNode? = nil
        if config.details.headTuftStyle != .none {
            let textureName = "headtuft_\(config.details.headTuftStyle.rawValue)"
            if catalog.contains(textureName), let design = try? layout.designSize(of: textureName) {
                let node = makeSprite(
                    name: "pet.headTuft",
                    texture: textureName,
                    fallback: textureName,
                    explicitSize: design,
                    tint: palette.accentColor
                )
                node.position = subtract(layout.point(for: "headTuft"), headAnchor)
                node.zPosition = 2
                head.addChild(node)
                headTuft = node
            }
        }

        // cheeks container → left/right (style != none) tint cheekColor
        var leftCheek: SKNode? = nil
        var rightCheek: SKNode? = nil
        if config.face.cheekStyle != .none {
            let textureName = "cheek_\(config.face.cheekStyle.rawValue)"
            if catalog.contains(textureName), let design = try? layout.designSize(of: textureName) {
                let cheeks = SKNode()
                cheeks.name = "pet.cheeks"
                cheeks.position = .zero
                cheeks.zPosition = 3
                head.addChild(cheeks)

                let left = makeSprite(
                    name: "pet.cheek.left",
                    texture: textureName,
                    fallback: textureName,
                    explicitSize: design,
                    tint: config.face.cheekColor
                )
                left.position = subtract(layout.point(for: "leftCheek"), headAnchor)
                left.zPosition = 0
                cheeks.addChild(left)
                leftCheek = left

                let right = makeSprite(
                    name: "pet.cheek.right",
                    texture: textureName,
                    fallback: textureName,
                    explicitSize: design,
                    tint: config.face.cheekColor
                )
                right.position = subtract(layout.point(for: "rightCheek"), headAnchor)
                right.zPosition = 0
                right.xScale = -1
                cheeks.addChild(right)
                rightCheek = right
            }
        }

        // muzzle tint secondary, relative to head
        let muzzleDesign = try layout.designSize(of: "muzzle_\(config.face.muzzleStyle.rawValue)")
        let muzzle = makeSprite(
            name: "pet.muzzle",
            texture: "muzzle_\(config.face.muzzleStyle.rawValue)",
            fallback: "muzzle_\(config.face.muzzleStyle.rawValue)",
            explicitSize: muzzleDesign,
            tint: palette.secondaryColor
        )
        muzzle.position = subtract(layout.point(for: "muzzle"), headAnchor)
        muzzle.zPosition = 4
        head.addChild(muzzle)

        // nose tint noseColor, relative to head
        let noseDesign = try layout.designSize(of: "nose_\(config.face.noseStyle.rawValue)")
        let nose = makeSprite(
            name: "pet.nose",
            texture: "nose_\(config.face.noseStyle.rawValue)",
            fallback: "nose_\(config.face.noseStyle.rawValue)",
            explicitSize: noseDesign,
            tint: config.face.noseColor
        )
        nose.position = subtract(layout.point(for: "nose"), headAnchor)
        nose.zPosition = 5
        head.addChild(nose)

        // eyes container
        let eyes = SKNode()
        eyes.name = "pet.eyes"
        eyes.position = .zero
        eyes.zPosition = 6
        head.addChild(eyes)

        let eyeScale = CGFloat(config.face.eyeScale)
        let eyeDesign = try (try? layout.designSize(of: "eye_\(config.face.eyeShape.rawValue)"))
            ?? layout.designSize(of: "fallback_eye")
        let eyeSize = scaled(eyeDesign, by: eyeScale)
        let irisSide = eyeSize.width * CGFloat(layout.relativeSizes.iris)
        let pupilWidth = eyeSize.width * CGFloat(layout.relativeSizes.pupil)
        let catchlightSide = eyeSize.width * CGFloat(layout.relativeSizes.catchlight)

        let leftEyePair = makeEye(
            side: "left",
            anchorName: "leftEye",
            headAnchor: headAnchor,
            eyeSize: eyeSize,
            irisSide: irisSide,
            pupilWidth: pupilWidth,
            catchlightSide: catchlightSide,
            config: config
        )
        eyes.addChild(leftEyePair.eye)

        let rightEyePair = makeEye(
            side: "right",
            anchorName: "rightEye",
            headAnchor: headAnchor,
            eyeSize: eyeSize,
            irisSide: irisSide,
            pupilWidth: pupilWidth,
            catchlightSide: catchlightSide,
            config: config
        )
        eyes.addChild(rightEyePair.eye)

        // MARK: Magic (relative to root)
        //
        // Per-feature look (art direction: soft cinematic light, luminous pastel
        // magic — NEVER a translucent glass bubble covering the pet):
        //  - glow: a soft, rimless AURA BEHIND the pet (z below tail, above the
        //    shadow), additive over a near-white radial falloff, tinted with the
        //    magical colour, centred on the character (body+head midpoint) and
        //    larger than it, alpha ~0.18…0.45 mapped from intensity.
        //  - sparkles / orbitingLight: small additive light points that may sit
        //    in front (z 20) but read as light, not a veil.
        var magic: SKNode? = nil
        if config.details.magicalFeature != .none {
            let feature = config.details.magicalFeature
            let textureName = PetTextureCatalog.magicTextureName(for: feature)
            if catalog.contains(textureName), let design = try? layout.designSize(of: textureName) {
                let intensity = CGFloat(config.details.magicalIntensity)
                let node: SKSpriteNode
                switch feature {
                case .glow:
                    // Aura: scaled up so it extends beyond the silhouette; centred
                    // on the character midpoint (between body and head anchors).
                    let auraScale: CGFloat = 2.0
                    node = makeSprite(
                        name: "pet.magic",
                        texture: textureName,
                        fallback: textureName,
                        explicitSize: scaled(design, by: auraScale),
                        tint: config.details.magicalColor
                    )
                    let characterMidY = (bodyAnchor.y + headAnchor.y) / 2
                    node.position = CGPoint(x: bodyAnchor.x, y: characterMidY)
                    node.zPosition = -15               // behind tail (-10), above shadow (-20)
                    node.blendMode = .add
                    node.alpha = 0.18 + 0.27 * intensity   // 0.18 … 0.45
                case .sparkles, .orbitingLight:
                    node = makeSprite(
                        name: "pet.magic",
                        texture: textureName,
                        fallback: textureName,
                        explicitSize: design,
                        tint: config.details.magicalColor
                    )
                    node.position = layout.point(for: "magic")
                    node.zPosition = 20                // in front, but additive
                    node.blendMode = .add
                    node.alpha = 0.30 + 0.45 * intensity
                case .none:
                    node = makeSprite(
                        name: "pet.magic", texture: textureName, fallback: textureName,
                        explicitSize: design, tint: config.details.magicalColor
                    )
                }
                root.addChild(node)
                magic = node
            }
        }

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
            leftEye: leftEyePair.eye,
            rightEye: rightEyePair.eye,
            leftEyelid: leftEyePair.lid,
            rightEyelid: rightEyePair.lid,
            muzzle: muzzle,
            nose: nose,
            headTuft: headTuft,
            chestTuft: chestTuft,
            leftCheek: leftCheek,
            rightCheek: rightCheek,
            magic: magic,
            bodyPattern: bodyPattern,
            facePattern: facePattern
        )
    }

    // MARK: - Eye assembly

    private struct EyePair {
        let eye: SKSpriteNode
        let lid: SKSpriteNode
    }

    private func makeEye(
        side: String,
        anchorName: String,
        headAnchor: CGPoint,
        eyeSize: CGSize,
        irisSide: CGFloat,
        pupilWidth: CGFloat,
        catchlightSide: CGFloat,
        config: PetConfiguration
    ) -> EyePair {
        let prefix = "pet.eye.\(side)"

        // Eye base — untinted (pre-colored).
        let eye = makeSprite(
            name: prefix,
            texture: "eye_\(config.face.eyeShape.rawValue)",
            fallback: "fallback_eye",
            explicitSize: eyeSize,
            tint: nil
        )
        eye.position = subtract(layout.point(for: anchorName), headAnchor)
        eye.zPosition = 0

        // iris (iris_base) tint irisColor, square side.
        let iris = makeSprite(
            name: "\(prefix).iris",
            texture: "iris_base",
            fallback: "iris_base",
            explicitSize: CGSize(width: irisSide, height: irisSide),
            tint: config.face.irisColor
        )
        iris.position = .zero
        iris.zPosition = 1
        eye.addChild(iris)

        // pupil — untinted, width by relativeSizes.pupil, height by texture aspect.
        let pupilTexture = "pupil_\(config.face.pupilStyle.rawValue)"
        let pupilDesign = (try? layout.designSize(of: pupilTexture))
            ?? (try? layout.designSize(of: "pupil_round"))
            ?? CGSize(width: 1, height: 1)
        let pupilAspect = pupilDesign.height / max(pupilDesign.width, 0.0001)
        let pupil = makeSprite(
            name: "\(prefix).pupil",
            texture: pupilTexture,
            fallback: "pupil_round",
            explicitSize: CGSize(width: pupilWidth, height: pupilWidth * pupilAspect),
            tint: nil
        )
        pupil.position = .zero
        pupil.zPosition = 2
        eye.addChild(pupil)

        // catchlight — untinted, square.
        let catchlight = makeSprite(
            name: "\(prefix).catchlight",
            texture: "eye_catchlight",
            fallback: "eye_catchlight",
            explicitSize: CGSize(width: catchlightSide, height: catchlightSide),
            tint: nil
        )
        catchlight.position = .zero
        catchlight.zPosition = 3
        eye.addChild(catchlight)

        // lid (eyelid) tint base, alpha 0 = open, at upper part of eye.
        let lidDesign = (try? layout.designSize(of: "eyelid")) ?? eyeSize
        let lid = makeSprite(
            name: "\(prefix).lid",
            texture: "eyelid",
            fallback: "eyelid",
            explicitSize: lidDesign,
            tint: config.palette.baseColor
        )
        lid.position = CGPoint(x: 0, y: 0.2 * eyeSize.height)
        lid.zPosition = 4
        lid.alpha = 0
        eye.addChild(lid)

        return EyePair(eye: eye, lid: lid)
    }

    // MARK: - Sprite construction

    /// Builds a sprite, sizing it to `explicitSize` and applying a tint if given.
    /// A `nil` tint leaves `colorBlendFactor` at 0 (pre-colored art).
    private func makeSprite(
        name: String,
        texture: String,
        fallback: String,
        explicitSize: CGSize,
        tint: RGBAColor?
    ) -> SKSpriteNode {
        let tex = catalog.texture(named: texture, fallback: fallback)
        let sprite = SKSpriteNode(texture: tex)
        sprite.name = name
        sprite.size = explicitSize
        applyTint(tint, to: sprite)
        return sprite
    }

    /// Overload that reads the design size for `designName` from the layout.
    private func makeSprite(
        name: String,
        texture: String,
        fallback: String,
        designName: String,
        tint: RGBAColor?
    ) -> SKSpriteNode {
        let size = (try? layout.designSize(of: designName)) ?? CGSize(width: 1, height: 1)
        return makeSprite(name: name, texture: texture, fallback: fallback, explicitSize: size, tint: tint)
    }

    /// Wraps `content` in an `SKCropNode` (named `name`) whose maskNode is a
    /// fresh `SKSpriteNode` duplicating `base`'s texture, size and position so
    /// only pixels inside `base`'s silhouette (alpha-based mask) survive.
    ///
    /// SKCropNode is available on iOS, macOS and watchOS. The mask is a NEW
    /// sprite (the real base stays in the tree), left fully opaque and untinted:
    /// an alpha mask keys off the mask node's per-pixel alpha, so the tint colour
    /// is irrelevant and must not reduce opacity. The crop node is placed by the
    /// caller in the SAME parent space as `base`, so any container scale
    /// (breathing/abdomen/head) transforms the mask and content identically.
    private func makeCrop(
        name: String,
        maskFrom base: SKSpriteNode,
        maskPosition: CGPoint,
        content: SKSpriteNode,
        zPosition: CGFloat
    ) -> SKCropNode {
        let mask = SKSpriteNode(texture: base.texture)
        mask.name = "\(name).mask"
        mask.size = base.size
        mask.position = maskPosition
        mask.zRotation = base.zRotation
        mask.xScale = base.xScale
        mask.yScale = base.yScale
        // Fully opaque, untinted — the alpha mask keys off the texture's alpha.
        mask.colorBlendFactor = 0
        mask.alpha = 1

        let crop = SKCropNode()
        crop.name = name
        crop.zPosition = zPosition
        crop.maskNode = mask
        crop.addChild(content)
        return crop
    }

    private func applyTint(_ tint: RGBAColor?, to sprite: SKSpriteNode) {
        guard let tint else {
            sprite.colorBlendFactor = 0
            return
        }
        sprite.color = SKColor(
            red: CGFloat(tint.red),
            green: CGFloat(tint.green),
            blue: CGFloat(tint.blue),
            alpha: 1
        )
        sprite.colorBlendFactor = 1
    }

    private func bodyPatternTexture(for style: PatternStyle) -> String? {
        switch style {
        case .spots: return "pattern_spots"
        case .stripes: return "pattern_stripes"
        case .gradient: return "pattern_gradient"
        default: return nil
        }
    }

    /// The tail's ROOT (base of the spine) in the tail texture's normalized,
    /// y-up coordinates (0,0 = bottom-left), used as the sprite's `anchorPoint`.
    ///
    /// These MUST track the spine roots defined in
    /// `Tools/TextureGenerator/generate.swift` `drawTail(_:_:style:)`:
    ///   short  spineN[0] = (0.42, 0.28)
    ///   long   spineN[0] = (0.32, 0.16)
    ///   plume  spineN[0] = (0.32, 0.16)
    ///   curled arc[0]     ≈ (0.405, 0.266)
    static func tailRootAnchor(for style: TailStyle) -> CGPoint {
        switch style {
        case .short:  return CGPoint(x: 0.42, y: 0.28)
        case .long:   return CGPoint(x: 0.32, y: 0.16)
        case .plume:  return CGPoint(x: 0.32, y: 0.16)
        case .curled: return CGPoint(x: 0.405, y: 0.266)
        }
    }

    private func scaled(_ size: CGSize, by factor: CGFloat) -> CGSize {
        CGSize(width: size.width * factor, height: size.height * factor)
    }

    private func subtract(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: a.x - b.x, y: a.y - b.y)
    }
}
