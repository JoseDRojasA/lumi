import SwiftData

public enum LumiModelContainerFactory {
    public static let cloudContainerIdentifier = "iCloud.heylumipet.app"

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
}
