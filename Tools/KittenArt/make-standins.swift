// make-standins.swift — writes rough stand-in layers for the pastel kitten so
// the import pipeline and rig can be built before the real painting exists.
//
//   swift Tools/KittenArt/make-standins.swift [outputDir]   (default: Art/Kitten)
//
// Output matches what the artist delivers (see
// docs/superpowers/specs/2026-09-27-kitten-art-and-expressions.md): one
// full-canvas 2048×2048 transparent PNG per layer, drawn in place, plus
// pivots.json. Replace the PNGs with real art and re-run import.swift.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Art/Kitten")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

// Everything below is drawn in 1024-point design space, y up; the context is
// scaled ×2 onto the 2048-pixel canvas.
let canvasPixels = 2048
let designScale: CGFloat = 2

struct RGB { let r, g, b: CGFloat }
let coat = RGB(r: 0.80, g: 0.72, b: 0.92)
let coatLight = RGB(r: 0.90, g: 0.85, b: 0.98)
let coatShade = RGB(r: 0.66, g: 0.56, b: 0.82)
let cream = RGB(r: 0.96, g: 0.93, b: 1.00)
let earPink = RGB(r: 0.96, g: 0.66, b: 0.76)
let nosePink = RGB(r: 0.93, g: 0.52, b: 0.62)
let blushPink = RGB(r: 1.00, g: 0.60, b: 0.72)
let iris = RGB(r: 0.72, g: 0.40, b: 0.16)
let irisRim = RGB(r: 0.36, g: 0.16, b: 0.06)
let ink = RGB(r: 0.20, g: 0.12, b: 0.18)
let mouthDark = RGB(r: 0.45, g: 0.15, b: 0.24)
let browColor = RGB(r: 0.62, g: 0.50, b: 0.82)

func layer(_ name: String, _ draw: (CGContext) -> Void) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: canvasPixels, height: canvasPixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("context") }
    ctx.scaleBy(x: designScale, y: designScale)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    draw(ctx)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(
            outDir.appendingPathComponent("\(name).png") as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("write \(name)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("finalize \(name)") }
    print("wrote \(name).png")
}

func fill(_ ctx: CGContext, _ c: RGB, _ a: CGFloat = 1) { ctx.setFillColor(red: c.r, green: c.g, blue: c.b, alpha: a) }
func stroke(_ ctx: CGContext, _ c: RGB, _ width: CGFloat) {
    ctx.setStrokeColor(red: c.r, green: c.g, blue: c.b, alpha: 1)
    ctx.setLineWidth(width)
}
func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGRect {
    CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
}

/// Fills `path` with `base`, then a soft top-left highlight and a bottom shade
/// clipped to the same shape, for a rounded plush look.
func shaded(_ ctx: CGContext, _ path: CGPath, base: RGB, light: RGB, shade: RGB) {
    let box = path.boundingBoxOfPath
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    fill(ctx, base)
    ctx.fill(box)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let lightGradient = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: light.r, green: light.g, blue: light.b, alpha: 0.9),
        CGColor(srgbRed: light.r, green: light.g, blue: light.b, alpha: 0)
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(
        lightGradient,
        startCenter: CGPoint(x: box.minX + box.width * 0.35, y: box.minY + box.height * 0.72), startRadius: 0,
        endCenter: CGPoint(x: box.minX + box.width * 0.35, y: box.minY + box.height * 0.72),
        endRadius: max(box.width, box.height) * 0.6, options: []
    )
    let shadeGradient = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: shade.r, green: shade.g, blue: shade.b, alpha: 0),
        CGColor(srgbRed: shade.r, green: shade.g, blue: shade.b, alpha: 0.7)
    ] as CFArray, locations: [0.55, 1])!
    ctx.drawLinearGradient(
        shadeGradient,
        start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.minY), options: []
    )
    ctx.restoreGState()
}

func softSpot(_ ctx: CGContext, _ rect: CGRect, _ c: RGB, alpha: CGFloat) {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: alpha),
        CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: 0)
    ] as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.translateBy(x: rect.midX, y: rect.midY)
    ctx.scaleBy(x: rect.width / 2, y: rect.height / 2)
    ctx.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
    ctx.restoreGState()
}

func polygon(_ points: [(CGFloat, CGFloat)]) -> CGPath {
    let path = CGMutablePath()
    path.addLines(between: points.map { CGPoint(x: $0.0, y: $0.1) })
    path.closeSubpath()
    return path
}

// MARK: - Body

layer("k_shadow") { softSpot($0, ellipse(512, 120, 240, 40), RGB(r: 0.1, g: 0.05, b: 0.15), alpha: 0.28) }

layer("k_tail") { ctx in
    let spine = CGMutablePath()
    spine.move(to: CGPoint(x: 630, y: 235))
    spine.addCurve(to: CGPoint(x: 800, y: 560), control1: CGPoint(x: 820, y: 230), control2: CGPoint(x: 880, y: 440))
    let outline = spine.copy(strokingWithWidth: 100, lineCap: .round, lineJoin: .round, miterLimit: 1)
    shaded(ctx, outline, base: coat, light: coatLight, shade: coatShade)
    softSpot(ctx, ellipse(800, 560, 70, 70), cream, alpha: 0.8)
}

layer("k_body") { ctx in
    shaded(ctx, CGPath(ellipseIn: ellipse(512, 300, 200, 190), transform: nil), base: coat, light: coatLight, shade: coatShade)
}

layer("k_chest") { ctx in
    let path = CGMutablePath()
    for (x, y, r) in [(512.0, 400.0, 70.0), (452, 370, 58), (572, 370, 58), (480, 320, 56), (544, 320, 56), (512, 290, 50)] {
        path.addEllipse(in: ellipse(x, y, r, r))
    }
    shaded(ctx, path, base: cream, light: cream, shade: coatLight)
}

for (name, x) in [("k_paw_left", CGFloat(440)), ("k_paw_right", 584)] {
    layer(name) { ctx in
        shaded(ctx, CGPath(ellipseIn: ellipse(x, 135, 68, 44), transform: nil), base: coat, light: coatLight, shade: coatShade)
        stroke(ctx, coatShade, 5)
        for dx in [-20.0, 20.0] {
            ctx.move(to: CGPoint(x: x + dx, y: 105))
            ctx.addLine(to: CGPoint(x: x + dx, y: 130))
        }
        ctx.strokePath()
    }
}

// MARK: - Head

layer("k_head") { ctx in
    let path = CGMutablePath()
    path.addEllipse(in: ellipse(512, 600, 280, 225))
    // Cheek fluff spikes on both sides.
    path.addPath(polygon([(260, 640), (205, 540), (275, 560), (230, 470), (300, 500)]))
    path.addPath(polygon([(764, 640), (819, 540), (749, 560), (794, 470), (724, 500)]))
    shaded(ctx, path, base: coat, light: coatLight, shade: coatShade)
    softSpot(ctx, ellipse(512, 500, 120, 70), cream, alpha: 0.7) // lighter muzzle area
}

layer("k_ear_left") { ctx in
    shaded(ctx, polygon([(295, 700), (455, 785), (280, 965)]), base: coat, light: coatLight, shade: coatShade)
    fill(ctx, earPink)
    ctx.addPath(polygon([(318, 730), (420, 785), (298, 915)]))
    ctx.fillPath()
}

layer("k_hair") { ctx in
    let path = CGMutablePath()
    for (baseX, tipX, tipY) in [(470.0, 430.0, 905.0), (495, 480, 950), (515, 525, 975), (535, 575, 940), (555, 610, 895)] {
        path.addPath(polygon([(baseX - 40, 800), (baseX + 40, 800), (tipX, tipY)]))
    }
    shaded(ctx, path, base: coatLight, light: cream, shade: coat)
}

// MARK: - Eyes

for (side, x) in [("left", CGFloat(410)), ("right", 614)] {
    layer("k_eye_white_\(side)") { ctx in
        fill(ctx, RGB(r: 1, g: 1, b: 1))
        ctx.fillEllipse(in: ellipse(x, 590, 78, 84))
        stroke(ctx, ink, 7)
        ctx.strokeEllipse(in: ellipse(x, 590, 78, 84))
    }
    layer("k_lid_\(side)") { ctx in
        shaded(ctx, CGPath(ellipseIn: ellipse(x, 592, 86, 92), transform: nil), base: coat, light: coatLight, shade: coat)
    }
    layer("k_eye_happy_\(side)") { ctx in
        stroke(ctx, ink, 12)
        ctx.move(to: CGPoint(x: x - 50, y: 575))
        ctx.addQuadCurve(to: CGPoint(x: x + 50, y: 575), control: CGPoint(x: x, y: 640))
        ctx.strokePath()
    }
    layer("k_eye_closed_\(side)") { ctx in
        stroke(ctx, ink, 12)
        ctx.move(to: CGPoint(x: x - 50, y: 595))
        ctx.addQuadCurve(to: CGPoint(x: x + 50, y: 595), control: CGPoint(x: x, y: 560))
        ctx.strokePath()
    }
}

// Iris, pupil and catchlights are painted once, in the LEFT eye.
layer("k_iris") { ctx in
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let gradient = CGGradient(colorsSpace: space, colors: [
        CGColor(srgbRed: iris.r * 1.2, green: iris.g * 1.3, blue: iris.b, alpha: 1),
        CGColor(srgbRed: iris.r, green: iris.g, blue: iris.b, alpha: 1),
        CGColor(srgbRed: irisRim.r, green: irisRim.g, blue: irisRim.b, alpha: 1)
    ] as CFArray, locations: [0, 0.6, 1])!
    ctx.addEllipse(in: ellipse(412, 582, 62, 62))
    ctx.clip()
    ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 412, y: 570), startRadius: 0,
                           endCenter: CGPoint(x: 412, y: 582), endRadius: 62, options: [])
}
layer("k_pupil") { ctx in
    fill(ctx, RGB(r: 0.08, g: 0.05, b: 0.07))
    ctx.fillEllipse(in: ellipse(412, 580, 34, 38))
}
layer("k_catchlight_big") { ctx in
    fill(ctx, RGB(r: 1, g: 1, b: 1))
    ctx.fillEllipse(in: ellipse(434, 608, 20, 20))
}
layer("k_catchlight_small") { ctx in
    fill(ctx, RGB(r: 1, g: 1, b: 1))
    ctx.fillEllipse(in: ellipse(392, 560, 9, 9))
}

// MARK: - Face

layer("k_brow_left") { ctx in
    stroke(ctx, browColor, 12)
    ctx.move(to: CGPoint(x: 360, y: 695))
    ctx.addQuadCurve(to: CGPoint(x: 445, y: 700), control: CGPoint(x: 400, y: 725))
    ctx.strokePath()
}

layer("k_nose") { ctx in
    fill(ctx, nosePink)
    ctx.addPath(polygon([(490, 532), (534, 532), (512, 506)]))
    ctx.fillPath()
}

layer("k_blush_left") { softSpot($0, ellipse(335, 515, 62, 36), blushPink, alpha: 0.6) }

layer("k_mouth_neutral") { ctx in
    stroke(ctx, mouthDark, 7)
    ctx.move(to: CGPoint(x: 482, y: 488))
    ctx.addQuadCurve(to: CGPoint(x: 512, y: 490), control: CGPoint(x: 497, y: 470))
    ctx.addQuadCurve(to: CGPoint(x: 542, y: 488), control: CGPoint(x: 527, y: 470))
    ctx.strokePath()
}
layer("k_mouth_smile") { ctx in
    fill(ctx, mouthDark)
    ctx.move(to: CGPoint(x: 478, y: 492))
    ctx.addQuadCurve(to: CGPoint(x: 546, y: 492), control: CGPoint(x: 512, y: 425))
    ctx.closePath()
    ctx.fillPath()
    fill(ctx, earPink)
    ctx.fillEllipse(in: ellipse(512, 465, 17, 10))
}
layer("k_mouth_o") { ctx in
    fill(ctx, mouthDark)
    ctx.fillEllipse(in: ellipse(512, 476, 14, 17))
}
layer("k_mouth_sad") { ctx in
    stroke(ctx, mouthDark, 7)
    ctx.move(to: CGPoint(x: 488, y: 470))
    ctx.addQuadCurve(to: CGPoint(x: 536, y: 470), control: CGPoint(x: 512, y: 494))
    ctx.strokePath()
}

// MARK: - Pivots (design points, 1024 canvas, y up)

let pivots: [String: [Double]] = [
    "k_tail": [640, 240],     // tail root, inside the body
    "k_ear_left": [370, 745], // ear base, inside the head
    "k_head": [512, 420]      // neck
]
let pivotData = try JSONSerialization.data(withJSONObject: pivots, options: [.prettyPrinted, .sortedKeys])
try pivotData.write(to: outDir.appendingPathComponent("pivots.json"))
print("wrote pivots.json")
