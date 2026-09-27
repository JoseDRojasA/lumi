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

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The built scene, or the error string if scene construction failed.
    @State private var built: Built?

    private enum Built {
        case scene(PetScene, petID: UUID)
        case failed(String)
    }

    var body: some View {
        GeometryReader { _ in
            content
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
                // On watchOS, wrist-down / Always-On Display is .inactive.
                // Pausing then saves battery; only .active runs the animation.
                scene.setApplicationActive(newPhase == .active)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch built {
        case let .scene(scene, _):
            // watchOS only exposes init(scene:transition:isPaused:preferredFramesPerSecond:);
            // the `options:` overload (e.g. .allowsTransparency) is unavailable here.
            // Transparency comes from the scene's clear backgroundColor instead.
            SpriteView(
                scene: scene,
                preferredFramesPerSecond: PetRenderPolicy.watch.preferredFramesPerSecond
            )
            .ignoresSafeArea()
            .onAppear {
                scene.setReduceMotion(reduceMotion)
                // onChange only fires on transitions; sync with the launch phase.
                scene.setApplicationActive(scenePhase == .active)
                scene.startAnimation()
            }
            .onDisappear { scene.stopAnimation() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(scene.accessibilityDescription)
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("lumi.pet")
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
            let scene = try WatchPetSceneFactory.makeScene(for: pet, reduceMotion: reduceMotion)
            built = .scene(scene, petID: pet.id)
        } catch {
            built = .failed(error.localizedDescription)
        }
    }
}
