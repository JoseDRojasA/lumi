//
//  LumiWatchApp.swift
//  LumiWatch Watch App
//
//  Watch entry point. Computes bootstrap once and shows the shell or a
//  retryable error. No fatalError, no SwiftData model container here.
//

import SwiftUI

@main
struct LumiWatchApp: App {
    @State private var bootstrap: WatchBootstrap = WatchBootstrap.make()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case let .ready(repository):
                WatchRootView(repository: repository)
            case let .failed(message):
                WatchErrorView(message: message) {
                    bootstrap = WatchBootstrap.make()
                }
            }
        }
    }
}
