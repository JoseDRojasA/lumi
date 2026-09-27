import Testing
@testable import LumiCore

struct LumiCorePackageSmokeTests {
    @Test func moduleLinks() { #expect(BodyShape.allCases.count == 3) }
}
