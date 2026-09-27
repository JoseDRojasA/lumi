//
//  ContentView.swift
//  app
//
//  The centered Lumi shell: background + loading / pet / error states.
//

import SwiftUI
import LumiCore

struct ContentView: View {
    @State private var model: LumiViewModel

    init(repository: any PetRepository) {
        _model = State(initialValue: LumiViewModel(repository: repository))
    }

    var body: some View {
        ZStack {
            LumiBackground()

            switch model.state {
            case .loading:
                ProgressView()
                    .controlSize(.large)
            case let .loaded(pet):
                PetSceneHost(pet: pet)
                    .overlay(alignment: .bottom) {
                        Button("Pastel Kitten", systemImage: "wand.and.stars") {
                            model.apply(LumiPresets.pastelKitten)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.bottom, 24)
                        .accessibilityHint("Sets the traits to recreate the pastel kitten reference character")
                        .accessibilityIdentifier("lumi.applyPreset")
                    }
            case let .failed(message):
                LumiErrorView(message: message) {
                    Task { await model.load() }
                }
            }
        }
        .task { await model.load() }
    }
}

#Preview {
    // In-memory repository so the preview shows a freshly generated Lumi.
    if let repository = try? AppDependencies.make(inMemory: true) {
        ContentView(repository: repository)
    } else {
        LumiErrorView(message: "Preview unavailable") {}
    }
}
