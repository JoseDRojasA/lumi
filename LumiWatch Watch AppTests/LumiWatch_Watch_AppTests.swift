//
//  LumiWatch_Watch_AppTests.swift
//  LumiWatch Watch AppTests
//
//  Task 12: watchOS Lumi shell (view model, dependencies, scene factory).
//

import Foundation
import Testing
import LumiCore
import LumiRendering
@testable import LumiWatch_Watch_App

private enum StubError: LocalizedError, Sendable {
    case failed
    var errorDescription: String? { "Load failed" }
}

private actor PetRepositorySpy: PetRepository {
    private var results: [Result<Pet, StubError>]
    private(set) var createCalls = 0
    init(results: [Result<Pet, StubError>]) { self.results = results }
    func activePet() async throws -> Pet? { try results.first?.get() }
    func createPetIfNeeded() async throws -> Pet {
        createCalls += 1
        let next = results.count > 1 ? results.removeFirst() : results[0]
        return try next.get()
    }
}

private func makePet(seed: UInt64 = 101) throws -> Pet {
    let configuration = try PetGenerator.generate(seed: seed, version: PetGenerator.currentVersion)
    return Pet.new(id: UUID(), configuration: configuration, now: Date(timeIntervalSince1970: 1_000))
}

@MainActor
struct WatchLumiViewModelTests {
    @Test func startsLoading() {
        let repo = PetRepositorySpy(results: [.failure(.failed)])
        let model = WatchLumiViewModel(repository: repo)
        #expect(model.state == .loading)
    }

    @Test func loadPublishesPet() async throws {
        let pet = try makePet()
        let repo = PetRepositorySpy(results: [.success(pet)])
        let model = WatchLumiViewModel(repository: repo)
        await model.load()
        #expect(model.state == .loaded(pet))
    }

    @Test func loadPublishesRetryableFailure() async {
        let repo = PetRepositorySpy(results: [.failure(.failed)])
        let model = WatchLumiViewModel(repository: repo)
        await model.load()
        #expect(model.state == .failed("Load failed"))
    }

    @Test func retryAfterFailureLoadsPet() async throws {
        let pet = try makePet()
        let repo = PetRepositorySpy(results: [.failure(.failed), .success(pet)])
        let model = WatchLumiViewModel(repository: repo)
        await model.load()
        #expect(model.state == .failed("Load failed"))
        await model.load()
        #expect(model.state == .loaded(pet))
        let calls = await repo.createCalls
        #expect(calls == 2)
    }

    @Test func concurrentLoadsCallRepositoryOnce() async throws {
        let pet = try makePet()
        let repo = PetRepositorySpy(results: [.success(pet)])
        let model = WatchLumiViewModel(repository: repo)
        async let first: Void = model.load()
        async let second: Void = model.load()
        _ = await (first, second)
        let calls = await repo.createCalls
        #expect(calls == 1)
        #expect(model.state == .loaded(pet))
    }
}

struct WatchLaunchConfigurationTests {
    @Test func productionDefault() {
        let config = LaunchConfiguration(arguments: ["/path/to/app"])
        #expect(config == LaunchConfiguration.production)
        #expect(config.usesInMemoryStore == false)
        #expect(config.seed == nil)
    }

    @Test func uiTestFlagSetsInMemory() {
        let config = LaunchConfiguration(arguments: ["/path/to/app", "-LumiUITest"])
        #expect(config.usesInMemoryStore == true)
        #expect(config.seed == nil)
    }

    @Test func seedParsed() {
        let config = LaunchConfiguration(arguments: ["/path/to/app", "-LumiUITest", "-LumiSeed", "42"])
        #expect(config.usesInMemoryStore == true)
        #expect(config.seed == 42)
    }

    @Test func malformedSeedIsNil() {
        let config = LaunchConfiguration(arguments: ["/path/to/app", "-LumiSeed", "notanumber"])
        #expect(config.seed == nil)
    }

    @Test func missingSeedValueIsNil() {
        let config = LaunchConfiguration(arguments: ["/path/to/app", "-LumiSeed"])
        #expect(config.seed == nil)
    }
}

@MainActor
struct WatchDependenciesTests {
    @Test func inMemoryDependenciesCreateAndReuseOnePet() async throws {
        let repository = try WatchDependencies.make(inMemory: true)
        let first = try await repository.createPetIfNeeded()
        let second = try await repository.createPetIfNeeded()
        #expect(first.id == second.id)
    }
}

@MainActor
struct WatchPetSceneFactoryTests {
    @Test func bundledWatchAtlasAndLayoutLoad() throws {
        let (catalog, _) = try WatchPetSceneFactory.loadResources(bundle: .main)
        #expect(catalog.missingTextureNames.isEmpty)
    }

    @Test func makesWatchScene() throws {
        let pet = try makePet()
        let scene = try WatchPetSceneFactory.makeScene(for: pet, reduceMotion: false)
        #expect(scene.policy == .watch)
        let expected = PetPresentation(configuration: pet.configuration).accessibilityDescription
        #expect(scene.accessibilityDescription == expected)
    }

    @Test func usesWatchAtlasName() {
        #expect(WatchPetSceneFactory.atlasName == "LumiPetWatch")
    }
}
