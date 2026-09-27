import Foundation
import CoreGraphics
import SpriteKit
import LumiCore

/// Per-device rendering policy: how large the pet is drawn relative to the
/// available space, the target frame rate, and which motion tiers are enabled.
public enum PetRenderPolicy: Equatable, Sendable {
    case phone, phoneLandscape, pad, mac, watch

    /// The fraction of the shorter scene dimension the character should occupy.
    public var sizeFraction: CGFloat {
        switch self {
        case .phone: return 0.46
        case .phoneLandscape: return 0.40
        case .pad: return 0.42
        case .mac: return 0.38
        case .watch: return 0.62
        }
    }

    public var preferredFramesPerSecond: Int {
        self == .watch ? 30 : 60
    }

    /// Whether the resting breath includes its delayed secondary tier.
    public var includesSecondaryBreathing: Bool {
        self != .watch
    }

    /// Whether magic/glow effects animate.
    public var includesEffects: Bool {
        self != .watch
    }
}

/// The SpriteKit scene that hosts one pet rig. It owns the rig, a breathing
/// controller and a secondary-motion controller, and it is the single place
/// that applies the motion composer each frame.
///
/// Layout contract: the composer rewrites `rig.root`'s transform every frame,
/// so the scene NEVER scales or positions `rig.root`. Instead it nests the rig
/// inside a dedicated `stage` node and scales/positions only that node.
@MainActor
public final class PetScene: SKScene {
    public let rig: PetRig
    public var petRoot: SKNode { rig.root }
    public let stage: SKNode

    public private(set) var policy: PetRenderPolicy
    public private(set) var reduceMotion: Bool
    public private(set) var isAnimating: Bool = false
    public let accessibilityDescription: String

    private let configuration: PetConfiguration
    private let composer: PetMotionComposer
    private let breathing: BreathingController
    private let secondary: SecondaryMotionController

    /// Character bounds at the base pose, in root-local coordinates, EXCLUDING
    /// the magic node (so a large glow halo doesn't shrink the pet).
    private let characterBounds: CGRect

    private var lastUpdateTime: TimeInterval?

    // MARK: - Test accessors

    public var secondaryElapsedForTesting: TimeInterval { secondary.elapsed }
    public var breathingProfileForTesting: BreathingProfile { breathing.profile }
    public var secondaryProfileForTesting: SecondaryMotionProfile { secondary.profile }

    // MARK: - Init

    public init(
        presentation: PetPresentation,
        catalog: PetTextureCatalog,
        layout: PetRigLayout,
        policy: PetRenderPolicy,
        reduceMotion: Bool
    ) throws {
        self.configuration = presentation.configuration
        self.policy = policy
        self.reduceMotion = reduceMotion
        self.accessibilityDescription = presentation.accessibilityDescription

        let factory = PetNodeFactory(catalog: catalog, layout: layout)
        let rig = try factory.makeRig(presentation: presentation)
        self.rig = rig

        let stage = SKNode()
        stage.name = "pet.stage"
        self.stage = stage

        let composer = PetMotionComposer(rig: rig)
        self.composer = composer

        let breathingProfile = BreathingProfile(
            personality: configuration.motionPersonality,
            reduceMotion: reduceMotion,
            includesSecondaryMotion: policy.includesSecondaryBreathing
        )
        self.breathing = BreathingController(rig: rig, composer: composer, profile: breathingProfile)

        self.secondary = SecondaryMotionController(
            rig: rig,
            composer: composer,
            configuration: configuration,
            reduceMotion: reduceMotion,
            includesEffects: policy.includesEffects
        )

        // Character bounds computed ONCE at the base pose, excluding magic.
        self.characterBounds = Self.computeCharacterBounds(root: rig.root, magic: rig.magic)

        super.init(size: CGSize(width: 1, height: 1))

        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = .clear

        stage.addChild(rig.root)
        addChild(stage)

        // Policies without effects (e.g. .watch) must NOT draw the static magic
        // node. characterBounds already excludes magic, so hiding it is safe.
        applyMagicVisibility()

        relayout()
    }

    public required init?(coder: NSCoder) {
        nil
    }

    // MARK: - Bounds

    /// The union of every child frame in root-local space, excluding the magic
    /// node. Computed by temporarily removing magic from the accumulated frame.
    private static func computeCharacterBounds(root: SKNode, magic: SKNode?) -> CGRect {
        let savedAlpha = magic?.alpha
        // Hiding via isHidden removes the node from calculateAccumulatedFrame.
        magic?.isHidden = true
        let bounds = root.calculateAccumulatedFrame()
        magic?.isHidden = false
        if let a = savedAlpha { magic?.alpha = a }
        return bounds
    }

    // MARK: - Layout

    private func relayout() {
        let shorter = min(size.width, size.height)
        guard shorter > 0 else { return }
        let longest = max(characterBounds.width, characterBounds.height)
        guard longest > 0 else { return }
        let scale = shorter * policy.sizeFraction / longest
        stage.setScale(scale)
        stage.position = CGPoint(
            x: -characterBounds.midX * scale,
            y: -characterBounds.midY * scale
        )
    }

    /// SpriteKit invokes `didChangeSize(_:)` on the main thread. On the iOS/tvOS/
    /// macOS SDKs `SKNode`/`SKScene` inherit `@MainActor` isolation (via
    /// `UIResponder`/`NSResponder`), so the override is main-actor isolated like
    /// the rest of this class. On watchOS `SKNode` descends from `NSObject` and is
    /// nonisolated, so the override must be `nonisolated` there and hop onto the
    /// main actor with `MainActor.assumeIsolated`. That hop is sound because
    /// SpriteKit only ever calls this on the main thread, so `self` is never
    /// touched concurrently.
    #if os(watchOS)
    nonisolated public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        nonisolated(unsafe) let unsafeSelf = self
        MainActor.assumeIsolated {
            unsafeSelf.relayout()
        }
    }
    #else
    public override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        relayout()
    }
    #endif

    public func setPolicy(_ policy: PetRenderPolicy) {
        self.policy = policy
        // Breathing tier may change with the policy.
        breathing.setProfile(
            BreathingProfile(
                personality: configuration.motionPersonality,
                reduceMotion: reduceMotion,
                includesSecondaryMotion: policy.includesSecondaryBreathing
            )
        )
        // Effects availability may change with the policy — update magic.
        applyMagicVisibility()
        relayout()
    }

    /// Shows or hides the static magic node according to the current policy's
    /// `includesEffects`. Called at init and whenever the policy changes.
    private func applyMagicVisibility() {
        rig.magic?.isHidden = !policy.includesEffects
    }

    /// Base-pose character bounds mapped into scene coordinates.
    public var characterFrameInScene: CGRect {
        let scale = stage.xScale
        let originX = stage.position.x + characterBounds.minX * scale
        let originY = stage.position.y + characterBounds.minY * scale
        return CGRect(
            x: originX,
            y: originY,
            width: characterBounds.width * scale,
            height: characterBounds.height * scale
        )
    }

    /// The base-pose character rect in scene coordinates for a scene of the
    /// given size and policy, computed purely (does not read or mutate the live
    /// `size`/`policy`). Mirrors `relayout()`'s math so the host can position an
    /// accessibility overlay deterministically before SpriteKit lays out.
    public func characterFrameInScene(forSize size: CGSize, policy: PetRenderPolicy) -> CGRect {
        let shorter = min(size.width, size.height)
        let longest = max(characterBounds.width, characterBounds.height)
        guard shorter > 0, longest > 0 else { return .zero }
        let scale = shorter * policy.sizeFraction / longest
        // relayout(): stage.position = -characterBounds.mid * scale.
        let stageX = -characterBounds.midX * scale
        let stageY = -characterBounds.midY * scale
        return CGRect(
            x: stageX + characterBounds.minX * scale,
            y: stageY + characterBounds.minY * scale,
            width: characterBounds.width * scale,
            height: characterBounds.height * scale
        )
    }

    /// Converts a rect expressed in this scene's coordinate space (anchorPoint
    /// (0.5, 0.5), y-up, origin at the scene centre) into SwiftUI view
    /// coordinates (origin top-left, y-down). The scene uses `.resizeFill`, so
    /// scene points and view points share the same scale; `sceneSize` is the
    /// view's size in points.
    ///
    /// Pure and static so it can be unit-tested without a live scene.
    public static func viewRect(fromSceneRect sceneRect: CGRect, sceneSize: CGSize) -> CGRect {
        let halfWidth = sceneSize.width / 2
        let halfHeight = sceneSize.height / 2
        // x: shift origin from centre to left edge.
        let viewX = halfWidth + sceneRect.minX
        // y: flip. The scene's TOP edge (maxY, up) becomes the view's minY.
        let viewY = halfHeight - sceneRect.maxY
        return CGRect(x: viewX, y: viewY, width: sceneRect.width, height: sceneRect.height)
    }

    /// The base-pose character rect in SwiftUI view coordinates for a view of
    /// `viewSize` points (equal to the scene size under `.resizeFill`).
    public func characterFrameInView(viewSize: CGSize) -> CGRect {
        let sceneRect = characterFrameInScene(forSize: viewSize, policy: policy)
        return Self.viewRect(fromSceneRect: sceneRect, sceneSize: viewSize)
    }

    // MARK: - Animation lifecycle

    public func startAnimation() {
        isAnimating = true
        lastUpdateTime = nil
        breathing.start(on: rig.root, variationSeed: configuration.seed)
    }

    public func stopAnimation() {
        isAnimating = false
        lastUpdateTime = nil
        breathing.stop(on: rig.root)
        secondary.reset()
        composer.apply()
    }

    public func setApplicationActive(_ active: Bool) {
        isPaused = !active
        // On resume, the next update should not apply a large time jump.
        lastUpdateTime = nil
    }

    public func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        breathing.setProfile(
            BreathingProfile(
                personality: configuration.motionPersonality,
                reduceMotion: enabled,
                includesSecondaryMotion: policy.includesSecondaryBreathing
            )
        )
        secondary.setReduceMotion(enabled)
    }

    // MARK: - Frame loop

    /// SpriteKit invokes `update(_:)` on the main thread. See ``didChangeSize(_:)``
    /// for why watchOS needs a `nonisolated` override while the other platforms
    /// keep the class's main-actor isolation.
    #if os(watchOS)
    nonisolated public override func update(_ currentTime: TimeInterval) {
        nonisolated(unsafe) let unsafeSelf = self
        MainActor.assumeIsolated {
            unsafeSelf.step(currentTime: currentTime)
        }
    }
    #else
    public override func update(_ currentTime: TimeInterval) {
        step(currentTime: currentTime)
    }
    #endif

    private func step(currentTime: TimeInterval) {
        guard isAnimating, !isPaused else {
            lastUpdateTime = nil
            return
        }
        let dt: TimeInterval
        if let last = lastUpdateTime {
            dt = min(0.1, max(0, currentTime - last))
        } else {
            dt = 0
        }
        lastUpdateTime = currentTime
        secondary.advance(by: dt)
    }

    /// SpriteKit invokes `didEvaluateActions()` on the main thread. See
    /// ``didChangeSize(_:)`` for why watchOS needs a `nonisolated` override while
    /// the other platforms keep the class's main-actor isolation.
    #if os(watchOS)
    nonisolated public override func didEvaluateActions() {
        nonisolated(unsafe) let unsafeSelf = self
        MainActor.assumeIsolated {
            unsafeSelf.applyComposedMotion()
        }
    }
    #else
    public override func didEvaluateActions() {
        applyComposedMotion()
    }
    #endif

    private func applyComposedMotion() {
        // Single authoritative write per frame, after breathing's SKActions ran.
        composer.apply()
    }
}
