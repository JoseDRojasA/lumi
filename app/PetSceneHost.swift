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
            SpriteView(
                scene: scene,
                preferredFramesPerSecond: scene.policy.preferredFramesPerSecond,
                options: [.allowsTransparency]
            )
            .ignoresSafeArea()
            .onAppear {
                scene.setPolicy(PetRenderPolicy.resolve(idiom: .current, size: size))
                scene.setReduceMotion(reduceMotion)
                scene.startAnimation()
            }
            .onDisappear { scene.stopAnimation() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(scene.accessibilityDescription)
            .accessibilityAddTraits(.isImage)
            .accessibilityIdentifier("lumi.pet")
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
