//
//  DebugActivityPanel.swift
//  app
//
//  A DEBUG-only overlay of buttons that trigger procedural activities on the
//  live PetScene (jump, dance, idle activities) so motion can be verified on
//  device. Compiled out of release builds.
//

#if DEBUG
import SwiftUI
import LumiRendering

/// Floating control strip that drives `PetScene.playActivity(_:)` / `stopActivity()`.
struct DebugActivityPanel: View {
    let scene: PetScene

    private struct Item: Identifiable {
        let id: String
        let label: String
        let systemImage: String
        let activity: PetActivity
    }

    private let items: [Item] = [
        Item(id: "jump", label: "Jump", systemImage: "arrow.up.circle", activity: .jump),
        Item(id: "dance", label: "Dance", systemImage: "music.note", activity: .dance),
        Item(id: "stretch", label: "Stretch", systemImage: "figure.flexibility", activity: .stretch),
        Item(id: "lookAround", label: "Look", systemImage: "eye", activity: .lookAround),
        Item(id: "happyWiggle", label: "Wiggle", systemImage: "sparkles", activity: .happyWiggle),
    ]

    var body: some View {
        VStack {
            Spacer()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        Button {
                            scene.playActivity(item.activity)
                        } label: {
                            Label(item.label, systemImage: item.systemImage)
                                .labelStyle(.iconOnly)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityIdentifier("debug.activity.\(item.id)")
                        .accessibilityLabel("Play \(item.label)")
                    }

                    Button {
                        scene.stopActivity()
                    } label: {
                        Label("Stop", systemImage: "stop.circle")
                            .labelStyle(.iconOnly)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityIdentifier("debug.activity.stop")
                    .accessibilityLabel("Stop activity")
                }
                .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(.horizontal, 12)
            .padding(.bottom, 80)
        }
        .allowsHitTesting(true)
    }
}
#endif
