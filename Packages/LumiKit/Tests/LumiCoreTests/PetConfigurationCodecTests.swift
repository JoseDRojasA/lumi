import Foundation
import Testing
@testable import LumiCore

struct PetConfigurationCodecTests {
    @Test func roundTripPreservesEveryTrait() throws {
        let configuration = PetConfiguration.fixture(seed: 42)
        let data = try PetConfigurationCodec.encode(configuration)
        let decoded = try PetConfigurationCodec.decode(data)
        #expect(decoded == configuration)
    }

    @Test func encodingIsCanonical() throws {
        let configuration = PetConfiguration.fixture(seed: 42)
        #expect(try PetConfigurationCodec.encode(configuration) == PetConfigurationCodec.encode(configuration))
    }

    @Test func encodingUsesSortedKeys() throws {
        let data = try PetConfigurationCodec.encode(PetConfiguration.fixture(seed: 42))
        let json = try #require(String(data: data, encoding: .utf8))
        let bodyIndex = try #require(json.range(of: "\"body\"")).lowerBound
        let tailIndex = try #require(json.range(of: "\"tail\"")).lowerBound
        #expect(bodyIndex < tailIndex)
    }
}
