import Testing
@testable import LumiPersistence

struct LumiPersistencePackageSmokeTests {
    @Test func moduleLinks() {
        #expect(LumiModelContainerFactory.cloudContainerIdentifier == "iCloud.heylumipet.app")
    }
}
