import Foundation
import CoreGraphics
import LumiCore

public enum PetRigLayoutError: Error, Equatable {
    case unsupportedVersion(Int)
    case missingAnchor(String)
    case missingTexture(String)
}

/// A value-type mirror of `RigAnchors.json`. Anchors are normalized (0..1 of the
/// canvas, y UP, value = CENTER of the part). Texture sizes are DESIGN sizes in
/// points. This type is `Sendable` so it can cross actor boundaries freely.
public struct PetRigLayout: Decodable, Equatable, Sendable {
    public struct Canvas: Decodable, Equatable, Sendable {
        public let width: Double
        public let height: Double
    }

    public struct NormalizedPoint: Decodable, Equatable, Sendable {
        public let x: Double
        public let y: Double
    }

    public struct TextureSize: Decodable, Equatable, Sendable {
        public let width: Double
        public let height: Double
    }

    public struct RelativeSizes: Decodable, Equatable, Sendable {
        public let iris: Double
        public let pupil: Double
        public let catchlight: Double
    }

    public let version: Int
    public let canvas: Canvas
    public let anchors: [String: NormalizedPoint]
    public let relativeSizes: RelativeSizes
    public let headVariants: [String: String]
    public let textures: [String: TextureSize]

    /// The 17 anchor keys every valid layout must define.
    public static let requiredAnchorNames: [String] = [
        "shadow", "paws", "body", "abdomen", "chest", "tail", "head",
        "leftEar", "rightEar", "headTuft", "leftEye", "rightEye",
        "muzzle", "nose", "leftCheek", "rightCheek", "magic"
    ]

    public static func decode(_ data: Data) throws -> PetRigLayout {
        let layout = try JSONDecoder().decode(PetRigLayout.self, from: data)
        guard layout.version == 1 else {
            throw PetRigLayoutError.unsupportedVersion(layout.version)
        }
        for name in requiredAnchorNames where layout.anchors[name] == nil {
            throw PetRigLayoutError.missingAnchor(name)
        }
        return layout
    }

    public var canvasSize: CGSize {
        CGSize(width: canvas.width, height: canvas.height)
    }

    public var textureNames: Set<String> {
        Set(textures.keys)
    }

    public func hasAnchor(_ name: String) -> Bool {
        anchors[name] != nil
    }

    /// The anchor in ROOT-LOCAL points where the root origin = canvas center:
    /// `((x - 0.5) * width, (y - 0.5) * height)`. Returns `.zero` for unknown
    /// anchor names (all required anchors are validated at decode time).
    public func point(for anchor: String) -> CGPoint {
        guard let p = anchors[anchor] else { return .zero }
        return CGPoint(
            x: (p.x - 0.5) * canvas.width,
            y: (p.y - 0.5) * canvas.height
        )
    }

    public func designSize(of texture: String) throws -> CGSize {
        guard let size = textures[texture] else {
            throw PetRigLayoutError.missingTexture(texture)
        }
        return CGSize(width: size.width, height: size.height)
    }

    public func headVariant(for furStyle: FurStyle) -> String? {
        headVariants[furStyle.rawValue]
    }
}
