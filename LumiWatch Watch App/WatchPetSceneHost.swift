//
//  WatchPetSceneHost.swift
//  LumiWatch Watch App
//
//  Hosts a PetScene for a single Lumi on the watch, wiring lifecycle,
//  scene phase (battery-saving pause when inactive), reduce-motion, and
//  accessibility. The scene resizes itself (.resizeFill), so we just fill
//  the available space.
//

import SwiftUI
import SpriteKit
import LumiCore
import LumiRendering

struct WatchPetSceneHost: View {
    let pet: Pet
    var appearance: WatchPetAppearance = .generated

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
        }
        .ignoresSafeArea()
        .onAppear { rebuildIfNeeded() }
        .onChange(of: pet.id) { _, _ in rebuildIfNeeded(force: true) }
        // Same pet, new appearance (e.g. the Pastel Kitten preset was applied).
        .onChange(of: appearance) { _, _ in rebuildIfNeeded(force: true) }
        .onChange(of: reduceMotion) { _, newValue in
            if case let .scene(scene, _) = built {
                scene.setReduceMotion(newValue)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if case let .scene(scene, _) = built {
                // On watchOS, wrist-down / Always-On Display is .inactive.
                // Pausing then saves battery; only .active runs the animation.
                scene.setApplicationActive(newPhase == .active)
            }
        }
    }

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch built {
        case let .scene(scene, _):
            let petFrame = scene.characterFrameInView(viewSize: size)
            ZStack(alignment: .topLeading) {
                // watchOS only exposes init(scene:transition:isPaused:preferredFramesPerSecond:);
                // the `options:` overload (e.g. .allowsTransparency) is unavailable here.
                // Transparency comes from the scene's clear backgroundColor instead.
                SpriteView(
                    scene: scene,
                    preferredFramesPerSecond: PetRenderPolicy.watch.preferredFramesPerSecond
                )
                .ignoresSafeArea()
                .accessibilityHidden(true)
                // New identity per scene: when the scene is rebuilt (e.g. the
                // Pastel Kitten preset), onAppear must run again to start it.
                // Without this the swapped-in scene was never started (frozen).
                .id(ObjectIdentifier(scene))
                .onAppear {
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
            WatchErrorView(message: message) { rebuildIfNeeded(force: true) }
        case nil:
            Color.clear
        }
    }

    private func rebuildIfNeeded(force: Bool = false) {
        if !force, case let .scene(_, petID) = built, petID == pet.id {
            return
        }
        do {
            let scene = try WatchPetSceneFactory.makeScene(for: pet, appearance: appearance, reduceMotion: reduceMotion)
            // Stop the outgoing scene and start the new one here rather than
            // relying on SpriteView.onAppear: on watchOS, swapping the scene
            // (e.g. the Pastel Kitten preset) does not re-run onAppear, which
            // left the new pet frozen at its rest pose.
            if case let .scene(old, _) = built { old.stopAnimation() }
            built = .scene(scene, petID: pet.id)
            scene.setReduceMotion(reduceMotion)
            scene.setApplicationActive(scenePhase == .active)
            scene.startAnimation()
        } catch {
            built = .failed(error.localizedDescription)
        }
    }
}
