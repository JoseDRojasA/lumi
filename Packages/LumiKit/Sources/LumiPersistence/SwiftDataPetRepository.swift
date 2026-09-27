import Foundation
import SwiftData
import LumiCore

public enum PetRepositoryError: Error, Equatable {
    case invalidSeed(String)
    case unsupportedGeneratorVersion(Int)
}

public actor SwiftDataPetRepository: PetRepository {
    private let container: ModelContainer
    private let seed: @Sendable () -> UInt64
    private let makeID: @Sendable () -> UUID
    private let now: @Sendable () -> Date

    public init(
        container: ModelContainer,
        seed: @escaping @Sendable () -> UInt64 = { UInt64.random(in: .min ... .max) },
        makeID: @escaping @Sendable () -> UUID = { UUID() },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.container = container
        self.seed = seed
        self.makeID = makeID
        self.now = now
    }

    /// Returns the canonical active pet, or `nil` if the store is empty.
    ///
    /// As a convergence side effect, if multiple active records exist this
    /// deactivates all non-canonical duplicates (persisting the change) so that
    /// exactly one record remains active.
    public func activePet() async throws -> Pet? {
        try canonicalActivePet(in: ModelContext(container))
    }

    public func createPetIfNeeded() async throws -> Pet {
        let context = ModelContext(container)
        if let existing = try canonicalActivePet(in: context) {
            return existing
        }

        let seedValue = seed()
        let configuration = try PetGenerator.generate(seed: seedValue, version: PetGenerator.currentVersion)
        let data = try PetConfigurationCodec.encode(configuration)
        let timestamp = now()
        let id = makeID()

        context.insert(PetRecord(
            id: id,
            configurationData: data,
            configurationFormatVersion: configuration.formatVersion,
            generatorVersion: configuration.generatorVersion,
            seed: String(seedValue),
            name: "Lumi",
            createdAt: timestamp,
            updatedAt: timestamp,
            level: 1,
            experience: 0,
            isActive: true
        ))
        try context.save()

        return Pet.new(id: id, configuration: configuration, now: timestamp)
    }

    /// Fetches the active records within the given context, selects the canonical
    /// one (earliest `createdAt`, then lowest `id.uuidString`), deactivates any
    /// other active records (saving once if changed), and maps it to a `Pet`.
    ///
    /// This is synchronous and actor-isolated so callers can compose it with
    /// insertion without introducing a suspension point between the check and the
    /// insert.
    private func canonicalActivePet(in context: ModelContext) throws -> Pet? {
        let records = try context.fetch(FetchDescriptor<PetRecord>(predicate: #Predicate { $0.isActive }))
        guard !records.isEmpty else { return nil }

        let sorted = records.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        let canonical = sorted[0]
        var didChange = false
        for record in sorted.dropFirst() where record.isActive {
            record.isActive = false
            didChange = true
        }
        if didChange {
            try context.save()
        }

        return try pet(from: canonical)
    }

    private func pet(from record: PetRecord) throws -> Pet {
        let configuration = try configuration(from: record)
        return Pet(
            id: record.id,
            configuration: configuration,
            name: record.name,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
            level: record.level,
            experience: record.experience,
            isActive: record.isActive
        )
    }

    private func configuration(from record: PetRecord) throws -> PetConfiguration {
        if let decoded = try? PetConfigurationCodec.decode(record.configurationData) {
            return try PetConfigurationValidator.validate(decoded)
        }
        guard let seed = UInt64(record.seed) else {
            throw PetRepositoryError.invalidSeed(record.seed)
        }
        do {
            return try PetGenerator.generate(seed: seed, version: record.generatorVersion)
        } catch PetGeneratorError.unsupportedVersion(let version) {
            throw PetRepositoryError.unsupportedGeneratorVersion(version)
        }
    }
}
