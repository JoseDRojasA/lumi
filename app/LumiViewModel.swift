//
//  LumiViewModel.swift
//  app
//
//  Observable view model that loads the active Lumi through a PetRepository.
//

import Foundation
import Observation
import LumiCore

@MainActor
@Observable
final class LumiViewModel {
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

    /// Replaces the loaded Lumi's appearance with `configuration` (validated).
    /// Display-only: the stored pet is unchanged, so a relaunch shows it again.
    func apply(_ configuration: PetConfiguration) {
        guard case let .loaded(pet) = state else { return }
        do {
            let validated = try PetConfigurationValidator.validate(configuration)
            state = .loaded(Pet(
                id: pet.id,
                configuration: validated,
                name: pet.name,
                createdAt: pet.createdAt,
                updatedAt: Date(),
                level: pet.level,
                experience: pet.experience,
                isActive: pet.isActive
            ))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
