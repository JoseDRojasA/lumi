import Foundation
import SwiftData
import Testing
import LumiCore
@testable import LumiPersistence

private enum SyncedStoreStubError: Error, Equatable {
    case cloudFailure
    case localFailure
}

@Suite(.serialized)
struct SyncedStoreTests {
    /// Records every (inMemory, cloudKit) tuple the factory asked us to build.
    private final class BuildRecorder: @unchecked Sendable {
        private(set) var calls: [(inMemory: Bool, cloudKit: Bool)] = []
        func record(_ inMemory: Bool, _ cloudKit: Bool) { calls.append((inMemory, cloudKit)) }
    }

    @Test func inMemoryNeverAttemptsCloudKit() throws {
        let recorder = BuildRecorder()
        let store = try LumiModelContainerFactory.makeSyncedStore(inMemory: true) { inMemory, cloudKit in
            recorder.record(inMemory, cloudKit)
            return try LumiModelContainerFactory.make(inMemory: true)
        }
        #expect(recorder.calls.map { [$0.inMemory, $0.cloudKit] } == [[true, false]])
        #expect(store.mode == .inMemory)
    }

    @Test func prefersCloudKit() throws {
        let recorder = BuildRecorder()
        let store = try LumiModelContainerFactory.makeSyncedStore(inMemory: false) { inMemory, cloudKit in
            recorder.record(inMemory, cloudKit)
            return try LumiModelContainerFactory.make(inMemory: true)
        }
        #expect(recorder.calls.map { [$0.inMemory, $0.cloudKit] } == [[false, true]])
        #expect(store.mode == .cloudKit)
    }

    @Test func fallsBackToLocalWhenCloudKitFails() throws {
        let recorder = BuildRecorder()
        let store = try LumiModelContainerFactory.makeSyncedStore(inMemory: false) { inMemory, cloudKit in
            recorder.record(inMemory, cloudKit)
            if cloudKit { throw SyncedStoreStubError.cloudFailure }
            return try LumiModelContainerFactory.make(inMemory: true)
        }
        #expect(recorder.calls.map { [$0.inMemory, $0.cloudKit] } == [[false, true], [false, false]])
        #expect(store.mode == .localOnly)
    }

    @Test func rethrowsWhenLocalAlsoFails() {
        let recorder = BuildRecorder()
        #expect(throws: SyncedStoreStubError.localFailure) {
            try LumiModelContainerFactory.makeSyncedStore(inMemory: false) { inMemory, cloudKit in
                recorder.record(inMemory, cloudKit)
                throw cloudKit ? SyncedStoreStubError.cloudFailure : SyncedStoreStubError.localFailure
            }
        }
        #expect(recorder.calls.map { [$0.inMemory, $0.cloudKit] } == [[false, true], [false, false]])
    }

    /// Without the iCloud entitlement, CloudKit traps asynchronously AFTER the
    /// container opens (no error is thrown), so a disabled gate must never even
    /// attempt the CloudKit configuration.
    @Test func disabledGateNeverAttemptsCloudKit() throws {
        let recorder = BuildRecorder()
        let store = try LumiModelContainerFactory.makeSyncedStore(inMemory: false, cloudKitEnabled: false) { inMemory, cloudKit in
            recorder.record(inMemory, cloudKit)
            return try LumiModelContainerFactory.make(inMemory: true)
        }
        #expect(recorder.calls.map { [$0.inMemory, $0.cloudKit] } == [[false, false]])
        #expect(store.mode == .localOnly)
    }

    @Test func gateReadsInfoDictionaryFlag() {
        #expect(LumiModelContainerFactory.isCloudKitEnabled(infoDictionary: ["LumiCloudKitEnabled": true]))
        #expect(!LumiModelContainerFactory.isCloudKitEnabled(infoDictionary: ["LumiCloudKitEnabled": false]))
        #expect(!LumiModelContainerFactory.isCloudKitEnabled(infoDictionary: [:]))
        #expect(!LumiModelContainerFactory.isCloudKitEnabled(infoDictionary: nil))
    }

    @Test func productionInMemoryStoreWorks() async throws {
        let store = try LumiModelContainerFactory.makeSyncedStore(inMemory: true)
        #expect(store.mode == .inMemory)
        let repository = SwiftDataPetRepository(container: store.container)
        let pet = try await repository.createPetIfNeeded()
        #expect(pet.isActive)
    }
}
