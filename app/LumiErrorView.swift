//
//  LumiErrorView.swift
//  app
//
//  Retryable error UI shown when loading or bootstrap fails.
//

import SwiftUI

struct LumiErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Lumi couldn’t open", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: retry)
                .accessibilityIdentifier("lumi.retry")
        }
    }
}

#Preview {
    LumiErrorView(message: "Load failed") {}
}
