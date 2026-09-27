import Foundation
import SwiftData
import Testing
import LumiCore
@testable import LumiPersistence

@Suite(.serialized)
struct SwiftDataPetRepositoryTests {
    @Test func firstRequestCreatesAndSecondRequestReusesPet() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let repository = SwiftDataPetRepository(container: container, seed: { 123 }, now: { Date(timeIntervalSince1970: 5) })
        let first = try await repository.createPetIfNeeded()
        let second = try await repository.createPetIfNeeded()
        #expect(first.id == second.id)
        #expect(first.configuration == second.configuration)
        #expect(first.configuration == (try PetGenerator.generate(seed: 123, version: 1)))
        #expect(first.level == 1 && first.experience == 0 && first.name == "Lumi" && first.isActive)
        #expect(try recordCount(in: container) == 1)
    }

    @Test func createdPetIsVisibleToANewRepositoryOnTheSameStore() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let created = try await SwiftDataPetRepository(container: container, seed: { 7 }).createPetIfNeeded()
        let reloaded = try await SwiftDataPetRepository(container: container, seed: { 999 }).activePet()
        #expect(reloaded == created)
    }

    @Test func activePetIsNilForEmptyStore() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        #expect(try await SwiftDataPetRepository(container: container).activePet() == nil)
    }

    @Test func canonicalSelectionUsesDateThenIDAndDeactivatesOthers() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let earlierID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let laterID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        try insertRecord(id: laterID, createdAt: Date(timeIntervalSince1970: 2), seed: 2, into: container)
        try insertRecord(id: earlierID, createdAt: Date(timeIntervalSince1970: 1), seed: 1, into: container)
        let repository = SwiftDataPetRepository(container: container)
        #expect(try await repository.activePet()?.id == earlierID)
        let states = try activeStates(in: container)
        #expect(states[earlierID] == true)
        #expect(states[laterID] == false)
        #expect(states.count == 2)
    }

    @Test func equalCreationDatesBreakTiesByUUIDString() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let a = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000A"))
        let b = try #require(UUID(uuidString: "00000000-0000-0000-0000-00000000000B"))
        let sameDate = Date(timeIntervalSince1970: 3)
        try insertRecord(id: b, createdAt: sameDate, seed: 5, into: container)
        try insertRecord(id: a, createdAt: sameDate, seed: 6, into: container)
        #expect(try await SwiftDataPetRepository(container: container).activePet()?.id == a)
    }

    @Test func corruptPayloadRegeneratesFromStoredSeed() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        try insertRecord(id: UUID(), createdAt: .distantPast, seed: 44, payload: Data("not json".utf8), into: container)
        let pet = try await SwiftDataPetRepository(container: container).activePet()
        #expect(pet?.configuration == (try PetGenerator.generate(seed: 44, version: 1)))
    }

    @Test func invalidStoredSeedWithCorruptPayloadThrows() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        try insertRecord(id: UUID(), createdAt: .distantPast, seedString: "banana", payload: Data(), into: container)
        await #expect(throws: PetRepositoryError.invalidSeed("banana")) {
            try await SwiftDataPetRepository(container: container).activePet()
        }
    }

    @Test func storedPayloadIsCanonicalEncoding() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let pet = try await SwiftDataPetRepository(container: container, seed: { 321 }).createPetIfNeeded()
        let record = try #require(try fetchAll(in: container).first)
        #expect(record.configurationData == (try PetConfigurationCodec.encode(pet.configuration)))
        #expect(record.seed == "321")
        #expect(record.generatorVersion == 1)
        #expect(record.configurationFormatVersion == 1)
    }

    @Test func concurrentCreationYieldsExactlyOneActivePet() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let repository = SwiftDataPetRepository(container: container)
        let ids = try await withThrowingTaskGroup(of: UUID.self) { group in
            for _ in 0..<16 {
                group.addTask { try await repository.createPetIfNeeded().id }
            }
            var collected: [UUID] = []
            for try await id in group { collected.append(id) }
            return collected
        }
        #expect(Set(ids).count == 1)
        #expect(try recordCount(in: container) == 1)
    }

    @Test func fullUInt64SeedRoundTripsThroughStringStorage() async throws {
        let container = try LumiModelContainerFactory.make(inMemory: true)
        let pet = try await SwiftDataPetRepository(container: container, seed: { UInt64.max }).createPetIfNeeded()
        #expect(try fetchAll(in: container).first?.seed == "18446744073709551615")
        #expect(pet.configuration.seed == UInt64.max)
    }
}

// MARK: - Helpers

private func insertRecord(
    id: UUID,
    createdAt: Date,
    seed: UInt64 = 0,
    seedString: String? = nil,
    payload: Data? = nil,
    into container: ModelContainer
) throws {
    let context = ModelContext(container)
    let data = try payload ?? PetConfigurationCodec.encode(PetGenerator.generate(seed: seed, version: 1))
    context.insert(PetRecord(
        id: id,
        configurationData: data,
        configurationFormatVersion: 1,
        generatorVersion: 1,
        seed: seedString ?? String(seed),
        name: "Lumi",
        createdAt: createdAt,
        updatedAt: createdAt,
        level: 1,
        experience: 0,
        isActive: true
    ))
    try context.save()
}

private func fetchAll(in container: ModelContainer) throws -> [PetRecord] {
    try ModelContext(container).fetch(FetchDescriptor<PetRecord>())
}

private func recordCount(in container: ModelContainer) throws -> Int {
    try fetchAll(in: container).count
}

private func activeStates(in container: ModelContainer) throws -> [UUID: Bool] {
    Dictionary(uniqueKeysWithValues: try fetchAll(in: container).map { ($0.id, $0.isActive) })
}
