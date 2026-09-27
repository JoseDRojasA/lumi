//
//  AppDependencies.swift
//  app
//
//  Composition root: builds the persistence-backed repository and the
//  launch-time bootstrap result. No crashes — failures surface as UI.
//

import Foundation
import LumiCore
import LumiPersistence

enum AppDependencies {
    /// Builds a SwiftData-backed repository. Pass `inMemory: true` for previews,
    /// tests, and UI tests. CloudKit is disabled for now (enabled in a later task).
    static func make(inMemory: Bool = false) throws -> any PetRepository {
        let container = try LumiModelContainerFactory.make(inMemory: inMemory, cloudKit: false)
        return SwiftDataPetRepository(container: container)
    }
}

/// The launch-time bootstrap outcome, computed once with do/catch.
enum AppBootstrap {
    case ready(any PetRepository)
    case failed(String)

    static func make(inMemory: Bool = false) -> AppBootstrap {
        do {
            return .ready(try AppDependencies.make(inMemory: inMemory))
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
