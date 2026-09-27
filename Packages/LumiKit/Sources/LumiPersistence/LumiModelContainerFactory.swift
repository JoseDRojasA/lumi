import Foundation
import SwiftData
import os

public enum LumiModelContainerFactory {
    public static let cloudContainerIdentifier = "iCloud.heylumipet.app"

    private static let logger = Logger(subsystem: "heylumipet.app", category: "persistence")

    /// How the active on-disk (or in-memory) store was actually opened.
    public enum LumiStoreMode: Equatable, Sendable {
        case inMemory
        case cloudKit
        case localOnly
    }

    /// A ready-to-use container paired with the mode it was opened in.
    public struct LumiStore {
        public let container: ModelContainer
        public let mode: LumiStoreMode

        public init(container: ModelContainer, mode: LumiStoreMode) {
            self.container = container
            self.mode = mode
        }
    }

    /// - Parameters:
    ///   - inMemory: Use an ephemeral store (tests, previews, UI tests).
    ///   - cloudKit: Sync through the private CloudKit database. Requires the iCloud entitlement; ignored when `inMemory`.
    public static func make(inMemory: Bool = false, cloudKit: Bool = false) throws -> ModelContainer {
        let schema = Schema([PetRecord.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: (cloudKit && !inMemory) ? .private(cloudContainerIdentifier) : .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// Info.plist key that opts a host app into CloudKit sync.
    public static let cloudKitEnabledInfoKey = "LumiCloudKitEnabled"

    /// Whether the host app declares it is signed with the iCloud/CloudKit
    /// entitlement. This must be an explicit opt-in: when the entitlement is
    /// missing, CloudKit does NOT throw while opening the container — it traps
    /// the process asynchronously afterwards — so a try/catch fallback alone
    /// cannot protect unsigned or Personal Team builds.
    public static func isCloudKitEnabled(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) -> Bool {
        (infoDictionary?[cloudKitEnabledInfoKey] as? Bool) ?? false
    }

    /// Production entry point. When CloudKit is enabled (see `isCloudKitEnabled`),
    /// sync through the private CloudKit database; if that store can't be opened,
    /// fall back to the SAME on-disk store without sync so the pet is never lost
    /// and the app never fails to open for that reason.
    public static func makeSyncedStore(
        inMemory: Bool = false,
        cloudKitEnabled: Bool = isCloudKitEnabled()
    ) throws -> LumiStore {
        try makeSyncedStore(inMemory: inMemory, cloudKitEnabled: cloudKitEnabled, build: make(inMemory:cloudKit:))
    }

    /// Testable overload: the production entry point calls this with
    /// `make(inMemory:cloudKit:)`. The CloudKit and local configurations use the
    /// SAME default store location (default `ModelConfiguration` name/url), so
    /// switching between them never moves or loses the existing on-disk pet.
    static func makeSyncedStore(
        inMemory: Bool,
        cloudKitEnabled: Bool = true,
        build: (_ inMemory: Bool, _ cloudKit: Bool) throws -> ModelContainer
    ) throws -> LumiStore {
        if inMemory {
            let container = try build(true, false)
            logger.info("Opened in-memory store (no CloudKit).")
            return LumiStore(container: container, mode: .inMemory)
        }

        guard cloudKitEnabled else {
            let container = try build(false, false)
            logger.info("CloudKit disabled for this build; opened local-only store.")
            return LumiStore(container: container, mode: .localOnly)
        }

        do {
            let container = try build(false, true)
            logger.info("Opened CloudKit-synced store (private database).")
            return LumiStore(container: container, mode: .cloudKit)
        } catch {
            logger.error("CloudKit-synced store unavailable, falling back to local-only: \(String(describing: error), privacy: .public)")
            // Same default store location as the CloudKit attempt — the pet persists.
            let container = try build(false, false)
            logger.info("Opened local-only store (no CloudKit sync).")
            return LumiStore(container: container, mode: .localOnly)
        }
    }
}
