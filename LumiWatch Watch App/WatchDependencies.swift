//
//  WatchDependencies.swift
//  LumiWatch Watch App
//
//  Composition root for the watch shell: builds the persistence-backed
//  repository and the launch-time bootstrap result. No crashes — failures
//  surface as UI. Production launches sync through the private CloudKit
//  database and fall back to a local-only store if CloudKit is unavailable.
//

import Foundation
import LumiCore
import LumiPersistence

enum WatchDependencies {
    /// Builds a SwiftData-backed repository. Pass `inMemory: true` for previews
    /// and tests. Production launches sync through the private CloudKit database
    /// and fall back to a local-only store if CloudKit is unavailable.
    static func make(inMemory: Bool = false, seed: UInt64? = nil) throws -> any PetRepository {
        let store = try LumiModelContainerFactory.makeSyncedStore(inMemory: inMemory)
        if let seed {
            return SwiftDataPetRepository(container: store.container, seed: { seed })
        }
        return SwiftDataPetRepository(container: store.container)
    }
}

/// The launch-time bootstrap outcome, computed once with do/catch.
enum WatchBootstrap {
    case ready(any PetRepository)
    case failed(String)

    static func make(inMemory: Bool = false, seed: UInt64? = nil) -> WatchBootstrap {
        do {
            return .ready(try WatchDependencies.make(inMemory: inMemory, seed: seed))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
