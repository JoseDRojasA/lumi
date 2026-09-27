import Foundation
import SwiftData

/// CloudKit-compatible SwiftData record for one Lumi.
/// Every property has a default and there are no unique constraints or relationships,
/// because CloudKit cannot enforce them.
@Model
public final class PetRecord {
    public var id: UUID = UUID()
    public var configurationData: Data = Data()
    public var configurationFormatVersion: Int = 1
    public var generatorVersion: Int = 1
    public var seed: String = "0"
    public var name: String = "Lumi"
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var level: Int = 1
    public var experience: Int = 0
    public var isActive: Bool = true

    public init(id: UUID, configurationData: Data, configurationFormatVersion: Int, generatorVersion: Int, seed: String, name: String, createdAt: Date, updatedAt: Date, level: Int, experience: Int, isActive: Bool) {
        self.id = id
        self.configurationData = configurationData
        self.configurationFormatVersion = configurationFormatVersion
        self.generatorVersion = generatorVersion
        self.seed = seed
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.level = level
        self.experience = experience
        self.isActive = isActive
    }
}
