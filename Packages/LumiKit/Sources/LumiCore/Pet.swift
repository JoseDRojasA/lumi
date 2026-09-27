import Foundation

/// A persisted Lumi: identity, its immutable generated appearance, and progression.
public struct Pet: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let configuration: PetConfiguration
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let level: Int
    public let experience: Int
    public let isActive: Bool

    public init(id: UUID, configuration: PetConfiguration, name: String, createdAt: Date, updatedAt: Date, level: Int, experience: Int, isActive: Bool) {
        self.id = id
        self.configuration = configuration
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.level = level
        self.experience = experience
        self.isActive = isActive
    }

    /// A freshly created Lumi: named "Lumi", level 1, no experience, active.
    public static func new(id: UUID, configuration: PetConfiguration, now: Date) -> Pet {
        Pet(id: id, configuration: configuration, name: "Lumi", createdAt: now, updatedAt: now, level: 1, experience: 0, isActive: true)
    }
}
