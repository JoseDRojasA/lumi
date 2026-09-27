import Foundation

public enum PetConfigurationCodec {
    public static func encode(_ configuration: PetConfiguration) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(configuration)
    }

    public static func decode(_ data: Data) throws -> PetConfiguration {
        try JSONDecoder().decode(PetConfiguration.self, from: data)
    }
}
