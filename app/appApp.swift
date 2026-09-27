//
//  appApp.swift
//  app
//
//  Lumi app entry point. Computes bootstrap once and shows the shell or a
//  retryable error. No crash-on-failure, no SwiftData model container here.
//

import SwiftUI

@main
struct LumiApp: App {
    @State private var bootstrap: AppBootstrap = AppBootstrap.make()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case let .ready(repository):
                ContentView(repository: repository)
            case let .failed(message):
                LumiErrorView(message: message) {
                    bootstrap = AppBootstrap.make()
                }
            }
        }
    }
}
