//
//  WatchRootView.swift
//  LumiWatch Watch App
//
//  The centered Lumi shell for the watch: dark-friendly gradient background +
//  loading / pet / error states.
//

import SwiftUI
import LumiCore

struct WatchRootView: View {
    @State private var model: WatchLumiViewModel

    init(repository: any PetRepository) {
        _model = State(initialValue: WatchLumiViewModel(repository: repository))
    }

    var body: some View {
        ZStack {
            // Deep lavender dusk into near-black; the watch prefers dark.
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.15, blue: 0.28),
                    Color(red: 0.05, green: 0.04, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch model.state {
            case .loading:
                ProgressView()
            case let .loaded(pet):
                WatchPetSceneHost(pet: pet, appearance: model.appearance)
                    .overlay(alignment: .bottom) {
                        if model.appearance != .kitten {
                            Button("Pastel Kitten", systemImage: "wand.and.stars") {
                                model.apply(LumiPresets.pastelKitten, appearance: .kitten)
                            }
                            .font(.footnote)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .accessibilityIdentifier("watch.pastelKitten")
                        }
                    }
            case let .failed(message):
                WatchErrorView(message: message) {
                    Task { await model.load() }
                }
            }
        }
        .task { await model.load() }
    }
}

#Preview {
    // In-memory repository so the preview shows a freshly generated Lumi.
    if let repository = try? WatchDependencies.make(inMemory: true) {
        WatchRootView(repository: repository)
    } else {
        WatchErrorView(message: "Preview unavailable") {}
    }
}
