//
//  LaunchConfiguration.swift
//  LumiWatch Watch App
//
//  Parses UI-test launch arguments into a small, pure value. Production
//  launches (no `-LumiUITest`) leave behaviour unchanged. Mirrors the iOS
//  LaunchConfiguration; duplicated into the watch module (separate target).
//

import Foundation

/// Parsed launch options derived from process arguments.
///
/// - `-LumiUITest` selects an in-memory store (no CloudKit, no on-disk state).
/// - `-LumiSeed <UInt64>` makes the repository's seed deterministic so UI
///   tests always see the same pet.
struct LaunchConfiguration: Equatable {
    /// Whether the app should bootstrap with an in-memory store.
    let usesInMemoryStore: Bool
    /// A deterministic seed for the repository, if requested.
    let seed: UInt64?

    /// The production default: on-disk store, random seed.
    static let production = LaunchConfiguration(usesInMemoryStore: false, seed: nil)

    init(usesInMemoryStore: Bool, seed: UInt64?) {
        self.usesInMemoryStore = usesInMemoryStore
        self.seed = seed
    }

    /// Parses the given argument vector. Only `-LumiUITest` enables the
    /// in-memory store; `-LumiSeed <value>` is honoured regardless but is only
    /// meaningful alongside `-LumiUITest`. A missing or malformed seed value
    /// yields `nil`.
    init(arguments: [String]) {
        let usesInMemory = arguments.contains("-LumiUITest")
        var parsedSeed: UInt64?
        if let index = arguments.firstIndex(of: "-LumiSeed"),
           index + 1 < arguments.count,
           let value = UInt64(arguments[index + 1]) {
            parsedSeed = value
        }
        self.usesInMemoryStore = usesInMemory
        self.seed = parsedSeed
    }
}
