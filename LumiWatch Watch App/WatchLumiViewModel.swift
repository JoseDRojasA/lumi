//
//  WatchLumiViewModel.swift
//  LumiWatch Watch App
//
//  Observable view model that loads the active Lumi through a PetRepository.
//  Mirrors the iOS LumiViewModel; duplicated into the watch module with a
//  `Watch` prefix (the app target is a separate module).
//

import Foundation
import Observation
import LumiCore

@MainActor
@Observable
final class WatchLumiViewModel {
    enum State: Equatable {
        case loading
        case loaded(Pet)
        case failed(String)
    }

    private(set) var state: State = .loading

    private let repository: any PetRepository
    /// A load already in flight; a second `load()` awaits this instead of starting another.
    private var inFlight: Task<Void, Never>?

    init(repository: any PetRepository) {
        self.repository = repository
    }

    func load() async {
        // Coalesce: reuse an in-flight load rather than starting a duplicate.
        if let inFlight {
            await inFlight.value
            return
        }

        state = .loading
        let task = Task { [repository] in
            do {
                let pet = try await repository.createPetIfNeeded()
                self.state = .loaded(pet)
            } catch {
                self.state = .failed(error.localizedDescription)
            }
        }
        inFlight = task
        await task.value
        inFlight = nil
    }
}
