//
//  appApp.swift
//  app
//
//  Lumi app entry point. Computes bootstrap once and shows the shell or a
//  retryable error. No crash-on-failure, no SwiftData model container here.
//

import SwiftUI
import Foundation

@main
struct LumiApp: App {
    @State private var bootstrap: AppBootstrap = {
        let config = LaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
        return AppBootstrap.make(inMemory: config.usesInMemoryStore, seed: config.seed)
    }()

    var body: some Scene {
        WindowGroup {
            switch bootstrap {
            case let .ready(repository):
                ContentView(repository: repository)
            case let .failed(message):
                LumiErrorView(message: message) {
                    let config = LaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
                    bootstrap = AppBootstrap.make(inMemory: config.usesInMemoryStore, seed: config.seed)
                }
            }
        }
    }
}
