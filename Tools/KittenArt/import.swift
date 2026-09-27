// import.swift — turns full-canvas kitten layers into the app's atlas + layout.
//
//   swift Tools/KittenArt/import.swift [sourceDir] [atlasDir] [layoutJSON]
//   defaults: Art/Kitten  app/LumiKitten.atlas  app/KittenRig.json
//
// Input: one transparent PNG per layer (k_*.png), all the same square size and
// painted IN PLACE on the full canvas (2048×2048 recommended), plus
// pivots.json with pivot points for rotating parts in 1024-point design space
// (y up), e.g. {"k_head": [512, 420]}.
//
// For every layer this crops to the painted pixels, writes <name>@2x.png into
// the atlas (resampled to 2 px per design point) and records the part's center
// and size in KittenRig.json. Output is deterministic.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let sourceDir = URL(fileURLWithPath: args.count > 1 ? args[1] : "Art/Kitten")
let atlasDir = URL(fileURLWithPath: args.count > 2 ? args[2] : "app/LumiKitten.atlas")
let layoutURL = URL(fileURLWithPath: args.count > 3 ? args[3] : "app/KittenRig.json")

let designCanvas = 1024.0
let outputDensity = 2.0   // pixels per design point in the atlas (@2x)
let alphaThreshold: UInt8 = 2
let paddingPixels = 4

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { fail("cannot read \(url.lastPathComponent)") }
    return image
}

/// Redraws `image` into a known RGBA8 layout (row 0 = top) so alpha can be scanned.
func rgbaPixels(_ image: CGImage) -> [UInt8] {
    let w = image.width, h = image.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    pixels.withUnsafeMutableBytes { buffer in
        guard let ctx = CGContext(
            data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { fail("context") }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return pixels
}

/// Bounding box of painted pixels in top-left image coordinates, padded.
func paintedBounds(_ image: CGImage, name: String) -> CGRect {
    let w = image.width, h = image.height
    let pixels = rgbaPixels(image)
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h {
        let row = y * w * 4
        for x in 0..<w where pixels[row + x * 4 + 3] > alphaThreshold {
            if x < minX { minX = x }
            if x > maxX { maxX = x }
            if y < minY { minY = y }
            if y > maxY { maxY = y }
        }
    }
    guard maxX >= 0 else { fail("\(name) is empty") }
    minX = max(0, minX - paddingPixels)
    minY = max(0, minY - paddingPixels)
    maxX = min(w - 1, maxX + paddingPixels)
    maxY = min(h - 1, maxY + paddingPixels)
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fail("cannot write \(url.lastPathComponent)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fail("cannot finalize \(url.lastPathComponent)") }
}

/// Resamples `image` to `width × height` pixels (high-quality interpolation).
func resampled(_ image: CGImage, width: Int, height: Int) -> CGImage {
    if image.width == width && image.height == height { return image }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fail("resample context") }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let out = ctx.makeImage() else { fail("resample") }
    return out
}

/// Rounds to 4 decimals as a Decimal so the JSON prints e.g. `0.1035`, not
/// `0.10349999999999999`.
func rounded(_ value: Double) -> Decimal { Decimal(string: String(format: "%.4f", value)) ?? Decimal(value) }

// MARK: - Main

let fm = FileManager.default
let layerFiles = ((try? fm.contentsOfDirectory(atPath: sourceDir.path)) ?? [])
    .filter { $0.hasPrefix("k_") && $0.hasSuffix(".png") }
    .sorted()
guard !layerFiles.isEmpty else { fail("no k_*.png layers in \(sourceDir.path)") }

var pivots: [String: [Double]] = [:]
let pivotURL = sourceDir.appendingPathComponent("pivots.json")
if let data = try? Data(contentsOf: pivotURL) {
    guard let decoded = try? JSONDecoder().decode([String: [Double]].self, from: data) else {
        fail("pivots.json must map part names to [x, y]")
    }
    pivots = decoded
}

try fm.createDirectory(at: atlasDir, withIntermediateDirectories: true)
// Remove previously imported layers so renamed/deleted art doesn't linger.
for old in (try? fm.contentsOfDirectory(atPath: atlasDir.path)) ?? [] where old.hasPrefix("k_") {
    try fm.removeItem(at: atlasDir.appendingPathComponent(old))
}

var canvasSide: Int?
var parts: [String: [String: Decimal]] = [:]

for file in layerFiles {
    let name = String(file.dropLast(4))
    let image = loadImage(sourceDir.appendingPathComponent(file))
    guard image.width == image.height else { fail("\(file) must be square (full canvas)") }
    if let side = canvasSide, side != image.width {
        fail("\(file) is \(image.width) px; every layer must be \(side) px")
    }
    canvasSide = image.width

    let side = Double(image.width)
    let pixelsPerPoint = side / designCanvas
    let bounds = paintedBounds(image, name: file)
    guard let cropped = image.cropping(to: bounds) else { fail("crop \(file)") }

    let widthPoints = Double(bounds.width) / pixelsPerPoint
    let heightPoints = Double(bounds.height) / pixelsPerPoint
    let output = resampled(
        cropped,
        width: Int((widthPoints * outputDensity).rounded()),
        height: Int((heightPoints * outputDensity).rounded())
    )
    writePNG(output, to: atlasDir.appendingPathComponent("\(name)@2x.png"))

    // Center, normalized with y UP (image rows run top-down).
    let centerX = (Double(bounds.minX) + Double(bounds.width) / 2) / side
    let centerY = 1 - (Double(bounds.minY) + Double(bounds.height) / 2) / side
    var part: [String: Decimal] = [
        "x": rounded(centerX),
        "y": rounded(centerY),
        "width": rounded(widthPoints),
        "height": rounded(heightPoints)
    ]

    if let pivot = pivots[name] {
        guard pivot.count == 2 else { fail("pivot for \(name) must be [x, y]") }
        let left = Double(bounds.minX) / pixelsPerPoint
        let bottom = (side - Double(bounds.maxY)) / pixelsPerPoint
        let px = (pivot[0] - left) / widthPoints
        let py = (pivot[1] - bottom) / heightPoints
        guard (0...1).contains(px), (0...1).contains(py) else {
            fail("pivot for \(name) \(pivot) lies outside the painted part")
        }
        part["pivotX"] = rounded(px)
        part["pivotY"] = rounded(py)
    }
    parts[name] = part
    print("\(name): \(Int(widthPoints))×\(Int(heightPoints)) pt")
}

for name in pivots.keys where parts[name] == nil {
    fail("pivots.json names \(name), but there is no \(name).png")
}

let layout: [String: Any] = [
    "version": 1,
    "canvas": ["width": designCanvas, "height": designCanvas],
    "parts": parts
]
let json = try JSONSerialization.data(withJSONObject: layout, options: [.prettyPrinted, .sortedKeys])
try json.write(to: layoutURL)
print("wrote \(parts.count) parts to \(atlasDir.path) and \(layoutURL.path)")
