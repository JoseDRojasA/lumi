import Foundation
import Testing
@testable import LumiCore

struct PetDefaultsTests {
    @Test func newPetStartsAtLevelOne() throws {
        let configuration = try PetGenerator.generate(seed: 88, version: 1)
        let id = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        let pet = Pet.new(id: id, configuration: configuration, now: now)
        #expect(pet.id == id)
        #expect(pet.configuration == configuration)
        #expect(pet.name == "Lumi")
        #expect(pet.level == 1)
        #expect(pet.experience == 0)
        #expect(pet.isActive)
        #expect(pet.createdAt == now)
        #expect(pet.updatedAt == now)
    }

    @Test func memberwiseInitializerKeepsEveryField() throws {
        let configuration = try PetGenerator.generate(seed: 89, version: 1)
        let id = UUID()
        let created = Date(timeIntervalSince1970: 10)
        let updated = Date(timeIntervalSince1970: 20)
        let pet = Pet(id: id, configuration: configuration, name: "Mochi", createdAt: created, updatedAt: updated, level: 3, experience: 42, isActive: false)
        #expect(pet.name == "Mochi")
        #expect(pet.createdAt == created)
        #expect(pet.updatedAt == updated)
        #expect(pet.level == 3)
        #expect(pet.experience == 42)
        #expect(!pet.isActive)
    }
}
