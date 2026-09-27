import Foundation
import CoreGraphics

public enum KittenRigLayoutError: Error, Equatable {
    case unsupportedVersion(Int)
    case missingPart(String)
}

/// A value-type mirror of `KittenRig.json`, written by `Tools/KittenArt/import.swift`.
///
/// Every part was cut from the same full-size master painting, so its CENTER
/// (normalized 0...1 of the canvas, y UP) places it exactly where the artist
/// painted it. Sizes are design points in the canvas space. Parts that rotate
/// (tail, ears, head) carry a pivot: the SpriteKit `anchorPoint` inside the
/// part (normalized, y UP), e.g. the ear base or the neck.
public struct KittenRigLayout: Decodable, Equatable, Sendable {
    public struct Canvas: Decodable, Equatable, Sendable {
        public let width: Double
        public let height: Double
    }

    public struct Part: Decodable, Equatable, Sendable {
        public let x: Double
        public let y: Double
        public let width: Double
        public let height: Double
        public let pivotX: Double?
        public let pivotY: Double?
    }

    public let version: Int
    public let canvas: Canvas
    public let parts: [String: Part]

    /// Parts every kitten layout must contain (texture names are identical).
    public static let requiredPartNames: [String] = [
        "k_shadow", "k_tail", "k_body", "k_chest", "k_paw_left", "k_paw_right",
        "k_head", "k_ear_left", "k_hair",
        "k_eye_white_left", "k_eye_white_right", "k_iris", "k_pupil",
        "k_catchlight_big", "k_catchlight_small", "k_lid_left", "k_lid_right",
        "k_brow_left", "k_nose", "k_blush_left",
        "k_eye_happy_left", "k_eye_happy_right", "k_eye_closed_left", "k_eye_closed_right",
        "k_mouth_neutral", "k_mouth_smile", "k_mouth_o", "k_mouth_sad"
    ]

    /// Parts that must define a pivot (they rotate around it).
    public static let pivotedPartNames: [String] = ["k_tail", "k_ear_left", "k_head"]

    public static func decode(_ data: Data) throws -> KittenRigLayout {
        let layout = try JSONDecoder().decode(KittenRigLayout.self, from: data)
        guard layout.version == 1 else {
            throw KittenRigLayoutError.unsupportedVersion(layout.version)
        }
        for name in requiredPartNames where layout.parts[name] == nil {
            throw KittenRigLayoutError.missingPart(name)
        }
        return layout
    }

    public func part(_ name: String) throws -> Part {
        guard let part = parts[name] else { throw KittenRigLayoutError.missingPart(name) }
        return part
    }

    /// The part's center in ROOT-LOCAL points (root origin = canvas center).
    public func center(of name: String) throws -> CGPoint {
        let p = try part(name)
        return CGPoint(x: (p.x - 0.5) * canvas.width, y: (p.y - 0.5) * canvas.height)
    }

    public func size(of name: String) throws -> CGSize {
        let p = try part(name)
        return CGSize(width: p.width, height: p.height)
    }

    /// The sprite `anchorPoint` for the part: its pivot, or its center (0.5, 0.5).
    public func anchorPoint(of name: String) throws -> CGPoint {
        let p = try part(name)
        return CGPoint(x: p.pivotX ?? 0.5, y: p.pivotY ?? 0.5)
    }

    /// Where the part's anchor point lies, in ROOT-LOCAL points. Placing a
    /// sprite (with `anchorPoint(of:)`) at this position reproduces the painting.
    public func anchorPosition(of name: String) throws -> CGPoint {
        let center = try center(of: name)
        let size = try size(of: name)
        let anchor = try anchorPoint(of: name)
        return CGPoint(
            x: center.x + (anchor.x - 0.5) * size.width,
            y: center.y + (anchor.y - 0.5) * size.height
        )
    }
}
