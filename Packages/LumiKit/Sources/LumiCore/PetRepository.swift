/// Storage boundary for Lumis. Implemented by LumiPersistence; views and scenes depend only on this.
public protocol PetRepository: Sendable {
    /// The canonical active Lumi, or nil if none has been created yet.
    func activePet() async throws -> Pet?
    /// Returns the canonical active Lumi, generating and persisting one first if none exists.
    func createPetIfNeeded() async throws -> Pet
}
