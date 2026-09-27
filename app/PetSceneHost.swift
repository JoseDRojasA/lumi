//
//  PetSceneHost.swift
//  app
//
//  Hosts a PetScene for a single Lumi, wiring size → policy, lifecycle,
//  scene phase, reduce-motion, and accessibility.
//

import SwiftUI
import SpriteKit
import LumiCore
import LumiRendering

struct PetSceneHost: View {
    let pet: Pet

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The built scene, or the error string if scene construction failed.
    @State private var built: Built?

    private enum Built {
        case scene(PetScene, petID: UUID)
        case failed(String)
    }

    var body: some View {
        GeometryReader { geometry in
            content(size: geometry.size)
                .onChange(of: geometry.size) { _, newSize in
                    if case let .scene(scene, _) = built {
                        scene.setPolicy(PetRenderPolicy.resolve(idiom: .current, size: newSize))
                    }
                }
        }
        .onAppear { rebuildIfNeeded() }
        .onChange(of: pet.id) { _, _ in rebuildIfNeeded(force: true) }
        .onChange(of: reduceMotion) { _, newValue in
            if case let .scene(scene, _) = built {
                scene.setReduceMotion(newValue)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if case let .scene(scene, _) = built {
                scene.setApplicationActive(newPhase == .active)
            }
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch built {
        case let .scene(scene, _):
            // The scene renders at the GeometryReader's `size` (the SpriteView
            // is expanded past the safe area only for background bleed; the
            // scene's `.resizeFill` uses this content size). Compute the pet's
            // on-screen frame in this same coordinate space so the overlay lines
            // up with the rendered character.
            let petFrame = scene.characterFrameInView(viewSize: size)
            ZStack(alignment: .topLeading) {
                SpriteView(
                    scene: scene,
                    preferredFramesPerSecond: scene.policy.preferredFramesPerSecond,
                    options: [.allowsTransparency]
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .onAppear {
                    scene.setPolicy(PetRenderPolicy.resolve(idiom: .current, size: size))
                    scene.setReduceMotion(reduceMotion)
                    // onChange only fires on transitions; sync with the launch phase.
                    scene.setApplicationActive(scenePhase == .active)
                    scene.startAnimation()
                }
                .onDisappear { scene.stopAnimation() }

                // A clear element sized/positioned to the pet's on-screen
                // character frame, carrying the single `lumi.pet` accessibility
                // element (the SpriteView above is hidden so its SpriteKit node
                // names are not exposed as nested elements).
                Color.clear
                    .frame(width: petFrame.width, height: petFrame.height)
                    .position(x: petFrame.midX, y: petFrame.midY)
                    .accessibilityElement()
                    .accessibilityLabel(scene.accessibilityDescription)
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("lumi.pet")
            }
            .frame(width: size.width, height: size.height)
        case let .failed(message):
            LumiErrorView(message: message) { rebuildIfNeeded(force: true) }
        case nil:
            Color.clear
        }
    }

    private func rebuildIfNeeded(force: Bool = false) {
        if !force, case let .scene(_, petID) = built, petID == pet.id {
            return
        }
        do {
            let scene = try PetSceneFactory.makeScene(
                for: pet,
                policy: PetRenderPolicy.resolve(idiom: .current, size: .zero),
                reduceMotion: reduceMotion
            )
            built = .scene(scene, petID: pet.id)
        } catch {
            built = .failed(error.localizedDescription)
        }
    }
}
