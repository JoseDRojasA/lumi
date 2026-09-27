//
//  appTests.swift
//  appTests
//
//  Task 11: Lumi shell (view model, dependencies, render policy, scene factory).
//

import Foundation
import CoreGraphics
import Testing
import LumiCore
import LumiRendering
@testable import app

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
struct LumiViewModelTests {
    @Test func startsLoading() {
        let repo = PetRepositorySpy(results: [.failure(.failed)])
        let model = LumiViewModel(repository: repo)
        #expect(model.state == .loading)
    }

    @Test func loadPublishesPetAfterRepositoryReturns() async throws {
        let pet = try makePet()
        let repo = PetRepositorySpy(results: [.success(pet)])
        let model = LumiViewModel(repository: repo)
        await model.load()
        #expect(model.state == .loaded(pet))
    }

    @Test func loadPublishesRetryableFailure() async {
        let repo = PetRepositorySpy(results: [.failure(.failed)])
        let model = LumiViewModel(repository: repo)
        await model.load()
        #expect(model.state == .failed("Load failed"))
    }

    @Test func retryAfterFailureLoadsPet() async throws {
        let pet = try makePet()
        let repo = PetRepositorySpy(results: [.failure(.failed), .success(pet)])
        let model = LumiViewModel(repository: repo)
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
        let model = LumiViewModel(repository: repo)
        async let first: Void = model.load()
        async let second: Void = model.load()
        _ = await (first, second)
        let calls = await repo.createCalls
        #expect(calls == 1)
        #expect(model.state == .loaded(pet))
    }
}

@MainActor
struct AppDependenciesTests {
    @Test func inMemoryDependenciesCreateAndReuseOnePet() async throws {
        let repository = try AppDependencies.make(inMemory: true)
        let first = try await repository.createPetIfNeeded()
        let second = try await repository.createPetIfNeeded()
        #expect(first.id == second.id)
    }
}

@MainActor
struct PetRenderPolicyResolverTests {
    @Test func phonePortraitResolvesToPhone() {
        #expect(PetRenderPolicy.resolve(idiom: .phone, size: CGSize(width: 390, height: 844)) == .phone)
    }

    @Test func phoneLandscapeResolvesToPhoneLandscape() {
        #expect(PetRenderPolicy.resolve(idiom: .phone, size: CGSize(width: 844, height: 390)) == .phoneLandscape)
    }

    @Test func padResolvesToPad() {
        #expect(PetRenderPolicy.resolve(idiom: .pad, size: CGSize(width: 1024, height: 1366)) == .pad)
        #expect(PetRenderPolicy.resolve(idiom: .pad, size: CGSize(width: 1366, height: 1024)) == .pad)
    }

    @Test func macResolvesToMac() {
        #expect(PetRenderPolicy.resolve(idiom: .mac, size: CGSize(width: 1440, height: 900)) == .mac)
    }
}

@MainActor
struct PetSceneFactoryTests {
    @Test func bundledAtlasAndLayoutLoad() throws {
        let (catalog, layout) = try PetSceneFactory.loadResources(bundle: .main)
        #expect(catalog.missingTextureNames.isEmpty)
        #expect(layout.version == 1)
    }

    @Test func makesSceneForPet() throws {
        let pet = try makePet()
        let scene = try PetSceneFactory.makeScene(for: pet, policy: .phone, reduceMotion: false)
        let expected = PetPresentation(configuration: pet.configuration).accessibilityDescription
        #expect(scene.accessibilityDescription == expected)
    }
}
