import CoreGraphics
import SpriteKit

/// An additive/multiplicative offset contributed by one motion source to one
/// channel. `position` and `zRotation` compose additively; `xScale`/`yScale`
/// compose multiplicatively (so `1` is the neutral element for scale and `0`
/// the neutral element for position/rotation).
public struct PetMotionOffset: Equatable, Sendable {
    public var position: CGVector = .zero
    public var xScale: CGFloat = 1   // multiplicative
    public var yScale: CGFloat = 1   // multiplicative
    public var zRotation: CGFloat = 0

    /// The neutral offset: no translation, unit scale, no rotation.
    public static let identity = PetMotionOffset()

    public init(position: CGVector = .zero, xScale: CGFloat = 1, yScale: CGFloat = 1, zRotation: CGFloat = 0) {
        self.position = position
        self.xScale = xScale
        self.yScale = yScale
        self.zRotation = zRotation
    }
}

/// Channels that more than one controller may animate concurrently. Each maps
/// to at most one rig node; optional channels may be absent for some rigs.
public enum PetMotionChannel: String, CaseIterable, Sendable {
    case root, abdomen, chest, head, paws, leftEar, rightEar, tail, chestTuft, leftCheek, rightCheek
}

/// A stable identifier of a motion source (e.g. `"breathing"`, `"tailSway"`).
/// Sources are sorted by `rawValue` when combining so floating-point results
/// are deterministic regardless of insertion order.
public struct PetMotionSource: Hashable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

/// Composes the additive contributions of every motion source into the final
/// transform of each rig node. Multiple controllers write independent offsets
/// through `set(_:for:from:)`; `apply()` recomputes every channel absolutely
/// from `rig.base` plus the current offsets, so no stale state can survive and
/// there is no drift.
///
/// - Important: All members touch SpriteKit node transforms and are therefore
///   `@MainActor`-isolated. `apply()` is expected to run once per frame on the
///   main thread by whoever drives the rig.
@MainActor
public final class PetMotionComposer {
    private let rig: PetRig

    /// offsets[channel][source] = that source's contribution to that channel.
    private var offsets: [PetMotionChannel: [PetMotionSource: PetMotionOffset]] = [:]

    public init(rig: PetRig) {
        self.rig = rig
    }

    /// Replaces the offset this `source` contributes to `channel`. Passing
    /// `.identity` keeps a (harmless) neutral entry; use `clear(source:)` to
    /// drop a source entirely.
    public func set(_ offset: PetMotionOffset, for channel: PetMotionChannel, from source: PetMotionSource) {
        offsets[channel, default: [:]][source] = offset
    }

    /// Removes every offset contributed by `source` across all channels. Other
    /// sources' contributions are untouched.
    public func clear(source: PetMotionSource) {
        for channel in offsets.keys {
            offsets[channel]?[source] = nil
            if offsets[channel]?.isEmpty == true { offsets[channel] = nil }
        }
    }

    /// The combined offset for `channel`: position/rotation summed, scale
    /// multiplied, over all sources sorted by `rawValue` (deterministic order).
    public func combinedOffset(for channel: PetMotionChannel) -> PetMotionOffset {
        guard let sources = offsets[channel], !sources.isEmpty else { return .identity }
        var result = PetMotionOffset.identity
        for (_, o) in sources.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            result.position.dx += o.position.dx
            result.position.dy += o.position.dy
            result.xScale *= o.xScale
            result.yScale *= o.yScale
            result.zRotation += o.zRotation
        }
        return result
    }

    /// Writes `base + combinedOffset` to every channel node. Channels with no
    /// offsets are written exactly as base (bit-exact). Optional channels whose
    /// node or base transform is absent are skipped.
    public func apply() {
        for channel in PetMotionChannel.allCases {
            guard let base = baseTransform(for: channel), let node = node(for: channel) else { continue }
            write(base: base, offset: combinedOffset(for: channel), to: node)
        }
    }

    // MARK: - Private

    private func write(base: PetNodeTransform, offset: PetMotionOffset, to node: SKNode) {
        if offset == .identity {
            // Bit-exact base restoration, no float math.
            base.apply(to: node)
            return
        }
        node.position = CGPoint(
            x: base.position.x + offset.position.dx,
            y: base.position.y + offset.position.dy
        )
        node.xScale = base.xScale * offset.xScale
        node.yScale = base.yScale * offset.yScale
        node.zRotation = base.zRotation + offset.zRotation
    }

    private func node(for channel: PetMotionChannel) -> SKNode? {
        switch channel {
        case .root: return rig.root
        case .abdomen: return rig.abdomen
        case .chest: return rig.chest
        case .head: return rig.head
        case .paws: return rig.paws
        case .leftEar: return rig.leftEar
        case .rightEar: return rig.rightEar
        case .tail: return rig.tail
        case .chestTuft: return rig.chestTuft
        case .leftCheek: return rig.leftCheek
        case .rightCheek: return rig.rightCheek
        }
    }

    private func baseTransform(for channel: PetMotionChannel) -> PetNodeTransform? {
        let base = rig.base
        switch channel {
        case .root: return base.root
        case .abdomen: return base.abdomen
        case .chest: return base.chest
        case .head: return base.head
        case .paws: return base.paws
        case .leftEar: return base.leftEar
        case .rightEar: return base.rightEar
        case .tail: return base.tail
        case .chestTuft: return base.chestTuft
        case .leftCheek: return base.leftCheek
        case .rightCheek: return base.rightCheek
        }
    }
}
