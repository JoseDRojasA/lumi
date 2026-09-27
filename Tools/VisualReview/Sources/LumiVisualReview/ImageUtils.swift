import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

#if canImport(AppKit)
import AppKit
#endif

// MARK: - CGImage <-> raw RGBA and PNG IO

enum ImageIOWriter {
    /// Build a CGImage from raw RGBA8 bytes.
    static func cgImage(rgba: [UInt8], width: Int, height: Int, premultiplied: Bool) -> CGImage? {
        guard width > 0, height > 0, rgba.count >= width * height * 4 else { return nil }
        let cs = CGColorSpaceCreateDeviceRGB()
        let bmpInfo = CGBitmapInfo(rawValue: (premultiplied
            ? CGImageAlphaInfo.premultipliedLast.rawValue
            : CGImageAlphaInfo.last.rawValue))
        var data = rgba
        guard let provider = CGDataProvider(data: Data(bytes: &data, count: data.count) as CFData) else {
            return nil
        }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: bmpInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "ImageIOWriter", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot create PNG destination"])
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else {
            throw NSError(domain: "ImageIOWriter", code: 2, userInfo: [NSLocalizedDescriptionKey: "cannot finalize PNG"])
        }
    }
}

// MARK: - A simple mutable RGBA canvas backed by CoreGraphics

/// Non-premultiplied RGBA8 canvas we can composite into and draw text on.
final class Canvas {
    let width: Int
    let height: Int
    let ctx: CGContext

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        let cs = CGColorSpaceCreateDeviceRGB()
        self.ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        // CoreGraphics origin is bottom-left. We'll draw with that convention
        // and flip when placing images so callers can think top-left.
    }

    func fill(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1) {
        ctx.setFillColor(red: r, green: g, blue: b, alpha: a)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }

    /// Vertical gradient fill from top color to bottom color.
    func fillGradient(top: (CGFloat, CGFloat, CGFloat), bottom: (CGFloat, CGFloat, CGFloat)) {
        let cs = CGColorSpaceCreateDeviceRGB()
        let colors = [
            CGColor(colorSpace: cs, components: [top.0, top.1, top.2, 1])!,
            CGColor(colorSpace: cs, components: [bottom.0, bottom.1, bottom.2, 1])!
        ] as CFArray
        guard let grad = CGGradient(colorsSpace: cs, colors: colors, locations: [0, 1]) else { return }
        // top of image = y = height
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: 0, y: CGFloat(height)),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    }

    /// Draw a CGImage into the destination rect using top-left origin semantics.
    func draw(_ image: CGImage, inTopLeftRect rect: CGRect, alpha: CGFloat = 1) {
        ctx.saveGState()
        ctx.setAlpha(alpha)
        // Convert top-left rect to bottom-left CG rect.
        let cgRect = CGRect(x: rect.origin.x, y: CGFloat(height) - rect.origin.y - rect.height, width: rect.width, height: rect.height)
        ctx.setBlendMode(.normal)
        ctx.draw(image, in: cgRect)
        ctx.restoreGState()
    }

    func drawText(_ text: String, atTopLeft point: CGPoint, fontSize: CGFloat, color: (CGFloat, CGFloat, CGFloat) = (1, 1, 1)) {
        #if canImport(AppKit)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor(calibratedRed: color.0, green: color.1, blue: color.2, alpha: 1)
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(str)
        let yBottomLeft = CGFloat(height) - point.y - fontSize
        ctx.saveGState()
        ctx.textPosition = CGPoint(x: point.x, y: yBottomLeft)
        CTLineDraw(line, ctx)
        ctx.restoreGState()
        #endif
    }

    func makeImage() -> CGImage? { ctx.makeImage() }

    func writePNG(to url: URL) throws {
        guard let img = makeImage() else {
            throw NSError(domain: "Canvas", code: 1, userInfo: [NSLocalizedDescriptionKey: "cannot make image"])
        }
        try ImageIOWriter.writePNG(img, to: url)
    }
}

// MARK: - Pixel access helpers on a CGImage

/// Extracts RGBA8 (non-premultiplied approximation) bytes from a CGImage into a
/// flat top-down buffer for analysis.
struct RGBABitmap {
    let width: Int
    let height: Int
    var pixels: [UInt8] // RGBA, row-major, top-down

    init?(_ image: CGImage) {
        let w = image.width
        let h = image.height
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buf,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        self.width = w
        self.height = h
        self.pixels = buf
    }

    func alpha(x: Int, y: Int) -> UInt8 {
        pixels[(y * width + x) * 4 + 3]
    }

    func rgba(x: Int, y: Int) -> (UInt8, UInt8, UInt8, UInt8) {
        let i = (y * width + x) * 4
        return (pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3])
    }
}
