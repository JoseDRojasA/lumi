import Foundation
import CoreGraphics
import SpriteKit
import LumiCore
import LumiRendering

/// Wraps a factory-built `PetRig` inside a plain `SKScene` with the same
/// stage-scaling contract as `PetScene`, but gives us direct access to the rig,
/// composer and breathing controller so we can drive motion deterministically
/// and hide the magic node per-render.
@MainActor
final class RigStage {
    let scene: SKScene
    let stage: SKNode
    let rig: PetRig
    let composer: PetMotionComposer
    let breathing: BreathingController
    let configuration: PetConfiguration
    let characterBounds: CGRect

    init(
        configuration: PetConfiguration,
        catalog: PetTextureCatalog,
        layout: PetRigLayout,
        policy: PetRenderPolicy,
        sceneSize: CGSize,
        background: SKColor,
        reduceMotion: Bool = false
    ) throws {
        self.configuration = configuration
        let presentation = PetPresentation(configuration: configuration)
        let factory = PetNodeFactory(catalog: catalog, layout: layout)
        let rig = try factory.makeRig(presentation: presentation)
        self.rig = rig

        let composer = PetMotionComposer(rig: rig)
        self.composer = composer

        let profile = BreathingProfile(
            personality: configuration.motionPersonality,
            reduceMotion: reduceMotion,
            includesSecondaryMotion: policy.includesSecondaryBreathing
        )
        self.breathing = BreathingController(rig: rig, composer: composer, profile: profile)

        // Character bounds excluding magic (same rule as PetScene).
        let savedHidden = rig.magic?.isHidden
        rig.magic?.isHidden = true
        let bounds = rig.root.calculateAccumulatedFrame()
        if let s = savedHidden { rig.magic?.isHidden = s }
        self.characterBounds = bounds

        let scene = SKScene(size: sceneSize)
        scene.scaleMode = .resizeFill
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scene.backgroundColor = background
        self.scene = scene

        let stage = SKNode()
        stage.name = "pet.stage"
        self.stage = stage
        stage.addChild(rig.root)
        scene.addChild(stage)

        // Layout: scale so the character occupies policy.sizeFraction of the
        // shorter dimension; center on character bounds midpoint.
        let shorter = min(sceneSize.width, sceneSize.height)
        let longest = max(bounds.width, bounds.height)
        if shorter > 0, longest > 0 {
            let scale = shorter * policy.sizeFraction / longest
            stage.setScale(scale)
            stage.position = CGPoint(x: -bounds.midX * scale, y: -bounds.midY * scale)
        }

        // Mirror PetScene: policies without effects (e.g. .watch) must NOT draw
        // the static magic node.
        rig.magic?.isHidden = !policy.includesEffects
    }

    func setMagicHidden(_ hidden: Bool) {
        rig.magic?.isHidden = hidden
    }

    /// Hide or show every pattern overlay (body spots/stripes/gradient, face
    /// mask, paw socks) so callers can render the pattern-free silhouette to
    /// measure whether any pattern pixel spills outside the base part.
    func setPatternsHidden(_ hidden: Bool) {
        rig.bodyPattern?.isHidden = hidden
        rig.facePattern?.isHidden = hidden
        rig.paws.childNode(withName: "pet.paws.pattern")?.isHidden = hidden
    }

    /// Apply a breathing phase deterministically (no SKActions/time), then
    /// compose. Phase 0 (or exactly base) yields the base pose.
    func applyBreathingPhase(_ phase: Double) {
        breathing.apply(phase: phase)
        composer.apply()
    }

    /// Reset to base pose (clear breathing offsets).
    func resetToBase() {
        breathing.apply(phase: 0)
        composer.apply()
        rig.restoreBaseTransforms()
    }
}
