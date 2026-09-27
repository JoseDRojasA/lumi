import Foundation
import CoreGraphics
import ImageIO
import Metal
import SpriteKit
import UniformTypeIdentifiers
import LumiCore
import LumiRendering

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Disk atlas loading

/// Loads pet textures directly from an on-disk `.atlas` directory of PNGs,
/// bypassing SpriteKit's bundle-based `SKTextureAtlas(named:)`. Each texture is
/// `<atlasDir>/<name>.png`. Missing PNGs are simply absent from `availableNames`
/// so the catalog's fallback logic kicks in.
@MainActor
enum DiskAtlas {
    /// Build a `PetTextureCatalog` from a directory of PNGs by assembling an
    /// `SKTextureAtlas(dictionary:)` (the public catalog init path). Each
    /// `<name>.png` becomes an atlas entry keyed by `name`.
    static func makeCatalog(atlasDir: URL) throws -> PetTextureCatalog {
        let fm = FileManager.default
        let entries = (try? fm.contentsOfDirectory(atPath: atlasDir.path)) ?? []
        var dict: [String: Any] = [:]
        for entry in entries where entry.hasSuffix(".png") {
            let name = String(entry.dropLast(4))
            let url = atlasDir.appendingPathComponent(entry)
            if let image = NSImage(contentsOf: url) {
                dict[name] = image
            }
        }
        let atlas = SKTextureAtlas(dictionary: dict)
        return try PetTextureCatalog(atlas: atlas)
    }

    static func solid(r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255) -> SKTexture {
        let side = 4
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            bytes[i] = r; bytes[i + 1] = g; bytes[i + 2] = b; bytes[i + 3] = a
        }
        return SKTexture(data: Data(bytes), size: CGSize(width: side, height: side))
    }
}

// MARK: - Offscreen SpriteKit rendering

/// Headless SpriteKit renderer using `SKRenderer` + Metal texture readback.
/// No window, no user interaction required.
@MainActor
final class OffscreenRenderer {
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let renderer: SKRenderer

    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.device = device
        self.queue = queue
        self.renderer = SKRenderer(device: device)
    }

    /// Renders `scene` at `pixelSize` (device pixels) and returns a premultiplied
    /// RGBA8 `CGImage`.
    func render(scene: SKScene, pixelSize: CGSize) -> CGImage? {
        let width = max(1, Int(pixelSize.width.rounded()))
        let height = max(1, Int(pixelSize.height.rounded()))

        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .shared
        guard let target = device.makeTexture(descriptor: desc) else { return nil }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store

        guard let cmd = queue.makeCommandBuffer() else { return nil }

        renderer.scene = scene
        renderer.update(atTime: 0)
        renderer.render(
            withViewport: CGRect(x: 0, y: 0, width: width, height: height),
            commandBuffer: cmd,
            renderPassDescriptor: pass
        )
        cmd.commit()
        cmd.waitUntilCompleted()

        return Self.cgImage(from: target)
    }

    private static func cgImage(from texture: MTLTexture) -> CGImage? {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width * 4
        var raw = [UInt8](repeating: 0, count: bytesPerRow * height)
        texture.getBytes(
            &raw,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )
        // Metal renders with origin bottom-left in our viewport mapping; the
        // read-back rows are top-down already for SKRenderer. Build a CGImage
        // directly from the premultiplied RGBA bytes.
        return ImageIOWriter.cgImage(rgba: raw, width: width, height: height, premultiplied: true)
    }
}
