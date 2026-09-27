//
//  LumiWatchApp.swift
//  LumiWatch Watch App
//
//  Watch entry point. Computes bootstrap once and shows the shell or a
//  retryable error. No fatalError, no SwiftData model container here.
//

import SwiftUI
import Foundation

@main
struct LumiWatchApp: App {
    @State private var bootstrap: WatchBootstrap = {
        let config = LaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
        return WatchBootstrap.make(inMemory: config.usesInMemoryStore, seed: config.seed)
    }()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case let .ready(repository):
                WatchRootView(repository: repository)
            case let .failed(message):
                WatchErrorView(message: message) {
                    let config = LaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
                    bootstrap = WatchBootstrap.make(inMemory: config.usesInMemoryStore, seed: config.seed)
                }
            }
        }
    }
}
