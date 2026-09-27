//
//  WatchErrorView.swift
//  LumiWatch Watch App
//
//  Compact retryable error UI for the small watch screen.
//

import SwiftUI

struct WatchErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("Lumi couldn’t open")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Retry", action: retry)
                    .accessibilityIdentifier("lumi.retry")
            }
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    WatchErrorView(message: "Load failed") {}
}
