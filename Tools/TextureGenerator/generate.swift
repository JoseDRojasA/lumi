// generate.swift
// Deterministic procedural texture generator for the Lumi SpriteKit virtual pet.
// Run from repo root:  swift Tools/TextureGenerator/generate.swift
// Uses only CoreGraphics, ImageIO, UniformTypeIdentifiers, Foundation.

import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// =====================================================================
// MARK: - Deterministic PRNG (SplitMix64) + FNV-1a 64-bit name hashing
// =====================================================================

struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
    // Uniform double in [0,1)
    mutating func unit() -> Double {
        return Double(next() >> 11) * (1.0 / 9007199254740992.0)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double {
        return lo + (hi - lo) * unit()
    }
    mutating func gaussian() -> Double {
        // Box-Muller
        let u1 = max(unit(), 1e-12)
        let u2 = unit()
        return (-2.0 * log(u1)).squareRoot() * cos(2.0 * Double.pi * u2)
    }
}

func fnv1a64(_ s: String) -> UInt64 {
    var hash: UInt64 = 0xcbf29ce484222325
    let prime: UInt64 = 0x100000001b3
    for byte in s.utf8 {
        hash ^= UInt64(byte)
        hash = hash &* prime
    }
    return hash
}

// =====================================================================
// MARK: - Small math helpers
// =====================================================================

func clamp(_ x: Double, _ lo: Double = 0, _ hi: Double = 1) -> Double { min(max(x, lo), hi) }
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
    let t = clamp((x - e0) / (e1 - e0))
    return t * t * (3 - 2 * t)
}

typealias P = CGPoint

func pt(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

// =====================================================================
// MARK: - Bitmap canvas wrapper
// =====================================================================

final class Canvas {
    let ctx: CGContext
    let w: Int
    let h: Int
    init(_ w: Int, _ h: Int) {
        self.w = w; self.h = h
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        // Premultiplied last (RGBA), 8-bit.
        ctx = CGContext(data: nil,
                        width: w, height: h,
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .high
        ctx.setShouldAntialias(true)
        ctx.setAllowsAntialiasing(true)
        // origin bottom-left, y up == default CG coordinate system for a bitmap context.
    }
    var image: CGImage { ctx.makeImage()! }
}

// gray in 0..1 luminance, alpha 0..1  -> sets fill color (neutral gray, no hue)
func setGray(_ ctx: CGContext, _ g: Double, _ a: Double = 1) {
    let v = CGFloat(clamp(g))
    ctx.setFillColor(red: v, green: v, blue: v, alpha: CGFloat(clamp(a)))
}
func setStrokeGray(_ ctx: CGContext, _ g: Double, _ a: Double = 1) {
    let v = CGFloat(clamp(g))
    ctx.setStrokeColor(red: v, green: v, blue: v, alpha: CGFloat(clamp(a)))
}
func setRGBA(_ ctx: CGContext, _ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
    ctx.setFillColor(red: CGFloat(clamp(r)), green: CGFloat(clamp(g)), blue: CGFloat(clamp(b)), alpha: CGFloat(clamp(a)))
}

// =====================================================================
// MARK: - PNG saving
// =====================================================================

@discardableResult
func savePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

// =====================================================================
// MARK: - Texture registry (56 names + design sizes in points)
// =====================================================================

struct TexSpec { let name: String; let w: Int; let h: Int }

let TEXTURES: [TexSpec] = [
    // Tintable bodies
    .init(name: "body_round", w: 440, h: 380),
    .init(name: "body_compact", w: 400, h: 340),
    .init(name: "body_pear", w: 420, h: 400),
    .init(name: "abdomen_soft", w: 280, h: 220),
    .init(name: "paws_round", w: 320, h: 100),
    .init(name: "head_base", w: 580, h: 500),
    // Head variants (complete heads, used AS the head at runtime)
    .init(name: "fur_smooth", w: 580, h: 500),
    .init(name: "fur_fluffy", w: 580, h: 500),
    .init(name: "fur_spiky", w: 580, h: 500),
    // Patterns
    .init(name: "pattern_spots", w: 440, h: 380),
    .init(name: "pattern_stripes", w: 440, h: 380),
    .init(name: "pattern_socks", w: 320, h: 100),
    .init(name: "pattern_gradient", w: 440, h: 380),
    .init(name: "pattern_mask", w: 580, h: 500),
    .init(name: "eyelid", w: 170, h: 100),
    .init(name: "iris_base", w: 128, h: 128),
    // Ears (left only)
    .init(name: "ear_pointed", w: 210, h: 280),
    .init(name: "ear_rounded", w: 210, h: 230),
    .init(name: "ear_long", w: 180, h: 320),
    .init(name: "ear_floppy", w: 230, h: 240),
    // Tails
    .init(name: "tail_short", w: 200, h: 180),
    .init(name: "tail_long", w: 260, h: 340),
    .init(name: "tail_curled", w: 280, h: 300),
    .init(name: "tail_plume", w: 300, h: 360),
    // Head tufts
    .init(name: "headtuft_curl", w: 200, h: 170),
    .init(name: "headtuft_split", w: 220, h: 170),
    .init(name: "headtuft_windswept", w: 240, h: 170),
    // Chest tufts
    .init(name: "chesttuft_small", w: 200, h: 140),
    .init(name: "chesttuft_layered", w: 250, h: 190),
    .init(name: "chesttuft_cloud", w: 280, h: 200),
    // Muzzles
    .init(name: "muzzle_small", w: 150, h: 100),
    .init(name: "muzzle_round", w: 170, h: 115),
    .init(name: "muzzle_pronounced", w: 190, h: 130),
    // Noses
    .init(name: "nose_dot", w: 36, h: 30),
    .init(name: "nose_triangle", w: 44, h: 34),
    .init(name: "nose_heart", w: 46, h: 38),
    // Cheeks
    .init(name: "cheek_blush", w: 120, h: 80),
    .init(name: "cheek_freckles", w: 120, h: 80),
    .init(name: "cheek_glow", w: 130, h: 90),
    // Magic
    .init(name: "magic_glow", w: 420, h: 420),
    .init(name: "magic_sparkles", w: 420, h: 420),
    .init(name: "magic_orbiting_light", w: 420, h: 420),
    // Fallbacks (tintable)
    .init(name: "fallback_body", w: 440, h: 380),
    .init(name: "fallback_head", w: 580, h: 500),
    .init(name: "fallback_ear", w: 210, h: 280),
    .init(name: "fallback_tail", w: 260, h: 340),
    .init(name: "fallback_paws", w: 320, h: 100),
    // Non-tinted eyes
    .init(name: "eye_round", w: 150, h: 160),
    .init(name: "eye_almond", w: 160, h: 130),
    .init(name: "eye_sleepy", w: 160, h: 110),
    .init(name: "pupil_round", w: 80, h: 86),
    .init(name: "pupil_vertical", w: 44, h: 96),
    .init(name: "pupil_star", w: 88, h: 88),
    .init(name: "eye_catchlight", w: 90, h: 90),
    .init(name: "fallback_eye", w: 150, h: 160),
    .init(name: "shadow_diffuse", w: 560, h: 120),
]

// =====================================================================
// MARK: - Shading toolkit
// Shared helpers to give tintable parts the plush 3D look:
// fluffy outward-tuft edges, top-left key light, bottom AO,
// top rim light, and faint internal fur strands.
// All in neutral gray luminance (0.70..1.0) so runtime multiply-tint works.
// =====================================================================

// A blob outline as a closed path of many points, radius modulated ONLY by a
// few low-frequency harmonics (no high-frequency sawtooth) so the silhouette
// is a smooth soft plush shape. Fur detail is added separately as strands.
struct BlobParams {
    var cx: Double
    var cy: Double
    var rx: Double
    var ry: Double
    var lobes: Int          // low-freq bumps
    var lobeAmt: Double     // 0..1 relative radius variation
    var tuftCount: Int      // (legacy) kept for source compatibility, unused for edge
    var tuftLen: Double     // (legacy) kept for source compatibility
    var tuftJitter: Double  // (legacy)
    var points: Int         // path resolution
}

// Returns a SMOOTH boundary (low-frequency harmonics only). The overall radius
// factor stays <= ~1.0 + lobeAmt so the shape fits the rx/ry envelope with no
// spikes. Callers must size rx/ry to leave room for strands + margin.
func fluffyBoundary(_ rng: inout SplitMix64, _ p: BlobParams) -> [CGPoint] {
    var pts: [CGPoint] = []
    let n = max(64, p.points)
    let phase = rng.range(0, 2 * .pi)
    let lobePhase2 = rng.range(0, 2 * .pi)
    for i in 0..<n {
        let t = Double(i) / Double(n) * 2 * .pi
        var rf = 1.0
        rf += p.lobeAmt * 0.6 * sin(Double(p.lobes) * t + phase)
        rf += p.lobeAmt * 0.4 * sin(Double(max(2, p.lobes - 1)) * t + lobePhase2)
        let rx = p.rx * rf
        let ry = p.ry * rf
        pts.append(pt(p.cx + cos(t) * rx, p.cy + sin(t) * ry))
    }
    return pts
}

// Draw a filled path from points (closed).
func fillPath(_ ctx: CGContext, _ pts: [CGPoint]) {
    guard pts.count > 2 else { return }
    ctx.beginPath()
    ctx.move(to: pts[0])
    for i in 1..<pts.count { ctx.addLine(to: pts[i]) }
    ctx.closePath()
    ctx.fillPath()
}
func addPathToCtx(_ ctx: CGContext, _ pts: [CGPoint]) {
    guard pts.count > 2 else { return }
    ctx.move(to: pts[0])
    for i in 1..<pts.count { ctx.addLine(to: pts[i]) }
    ctx.closePath()
}

func centroidOf(_ pts: [CGPoint]) -> CGPoint {
    guard !pts.isEmpty else { return .zero }
    var sx = 0.0, sy = 0.0
    for p in pts { sx += Double(p.x); sy += Double(p.y) }
    return pt(sx / Double(pts.count), sy / Double(pts.count))
}

// Outward unit normal at boundary point i (from neighbouring segment direction).
func outwardNormal(_ boundary: [CGPoint], _ i: Int, centroid: CGPoint) -> (Double, Double) {
    let n = boundary.count
    let a = boundary[(i - 1 + n) % n]
    let b = boundary[(i + 1) % n]
    let tx = Double(b.x - a.x), ty = Double(b.y - a.y)
    // normal candidates
    var nx = ty, ny = -tx
    let len = (nx*nx + ny*ny).squareRoot()
    if len < 1e-6 {
        var dx = Double(boundary[i].x - centroid.x), dy = Double(boundary[i].y - centroid.y)
        let d = (dx*dx+dy*dy).squareRoot(); if d < 1e-6 { return (0, 1) }
        dx/=d; dy/=d; return (dx, dy)
    }
    nx /= len; ny /= len
    // orient outward (away from centroid)
    let ox = Double(boundary[i].x - centroid.x), oy = Double(boundary[i].y - centroid.y)
    if nx*ox + ny*oy < 0 { nx = -nx; ny = -ny }
    return (nx, ny)
}

// Colored feathered fill (used by eyes): expands the boundary outward in rings
// with decreasing alpha to create a soft 1.5-2px edge, filled with an RGB color.
func fillFeatheredColor(_ ctx: CGContext,
                        boundary: [CGPoint],
                        centroid: CGPoint,
                        feather: Double,
                        rings: Int,
                        r: Double, g: Double, b: Double,
                        coreAlpha: Double = 1.0) {
    guard boundary.count > 2 else { return }
    let cx = Double(centroid.x), cy = Double(centroid.y)
    let rr = max(1, rings)
    for ring in stride(from: rr, through: 0, by: -1) {
        let frac = Double(ring) / Double(rr)
        let offset = feather * frac
        let a = ring == 0 ? coreAlpha : coreAlpha * pow(1.0 - frac, 1.4)
        var poly: [CGPoint] = []
        poly.reserveCapacity(boundary.count)
        for p in boundary {
            var dx = Double(p.x) - cx, dy = Double(p.y) - cy
            let d = (dx*dx+dy*dy).squareRoot()
            if d < 1e-6 { poly.append(p); continue }
            dx/=d; dy/=d
            poly.append(pt(Double(p.x) + dx*offset, Double(p.y) + dy*offset))
        }
        ctx.saveGState()
        ctx.beginPath()
        ctx.move(to: poly[0])
        for k in 1..<poly.count { ctx.addLine(to: poly[k]) }
        ctx.closePath()
        setRGBA(ctx, r, g, b, a)
        ctx.fillPath()
        ctx.restoreGState()
    }
}

// Draw many thin tapered fur STRANDS along a boundary. Each strand is a slightly
// curved stroke, wide (2-5 px) at the root tapering toward ~0.5 px, pointing
// roughly along the outward normal with small angular jitter, alpha fading to
// the tip, luminance following a shade function (lighter top-left).
func drawStrands(_ ctx: CGContext,
                 _ rng: inout SplitMix64,
                 boundary: [CGPoint],
                 centroid: CGPoint,
                 count: Int,
                 lenMin: Double,
                 lenMax: Double,
                 rootW: Double,
                 jitter: Double,
                 straightness: Double,          // 0 curvy .. 1 straight
                 shade: (Double, Double) -> Double,
                 rootInset: Double = 6.0,
                 alphaMul: Double = 1.0,
                 bounds: CGRect? = nil) {
    guard boundary.count > 3 else { return }
    let n = boundary.count
    ctx.setLineCap(.round)
    for _ in 0..<count {
        let idx = Int(rng.unit() * Double(n)) % n
        let bp = boundary[idx]
        var (nx, ny) = outwardNormal(boundary, idx, centroid: centroid)
        // angular jitter
        let jit = rng.range(-jitter, jitter)
        let ca = cos(jit), sa = sin(jit)
        let dx = nx * ca - ny * sa
        let dy = nx * sa + ny * ca
        nx = dx; ny = dy
        var len = rng.range(lenMin, lenMax)
        // root starts slightly INSIDE the mask so strands blend in
        let rootX = Double(bp.x) - nx * rootInset
        let rootY = Double(bp.y) - ny * rootInset
        // If a safe bounds rect is supplied, shorten len so the tip (plus its
        // rounded width) stays inside it — this is geometry control, not erasing.
        if let b = bounds {
            let pad = 1.5
            // distance to each wall along the strand direction
            func lim(_ toWall: Double, _ comp: Double) -> Double {
                if abs(comp) < 1e-6 { return .greatestFiniteMagnitude }
                let d = toWall / comp
                return d > 0 ? d : .greatestFiniteMagnitude
            }
            let dRight = lim(Double(b.maxX) - pad - rootX, nx)
            let dLeft  = lim(Double(b.minX) + pad - rootX, nx)
            let dTop   = lim(Double(b.maxY) - pad - rootY, ny)
            let dBot   = lim(Double(b.minY) + pad - rootY, ny)
            let maxLen = min(min(dRight, dLeft), min(dTop, dBot))
            if maxLen <= 0 { continue }
            len = min(len, maxLen)
            if len < 1.0 { continue }
        }
        let tipX = rootX + nx * len
        let tipY = rootY + ny * len
        // perpendicular for a gentle curve
        let px = -ny, py = nx
        let curl = (1.0 - straightness) * rng.range(-0.35, 0.35) * len
        let midX = (rootX + tipX) * 0.5 + px * curl
        let midY = (rootY + tipY) * 0.5 + py * curl
        // Tapered strand: build as a filled sliver (root width -> ~0.5 tip).
        let rw = rootW * rng.range(0.8, 1.25)
        let g0 = shade(rootX, rootY)
        // root corners
        let rLx = rootX + px * rw * 0.5, rLy = rootY + py * rw * 0.5
        let rRx = rootX - px * rw * 0.5, rRy = rootY - py * rw * 0.5
        // mid corners (narrower)
        let mw = rw * 0.5
        let mLx = midX + px * mw * 0.5, mLy = midY + py * mw * 0.5
        let mRx = midX - px * mw * 0.5, mRy = midY - py * mw * 0.5
        ctx.saveGState()
        ctx.beginPath()
        ctx.move(to: pt(rLx, rLy))
        ctx.addQuadCurve(to: pt(tipX, tipY), control: pt(mLx, mLy))
        ctx.addQuadCurve(to: pt(rRx, rRy), control: pt(mRx, mRy))
        ctx.closePath()
        setGray(ctx, g0, clamp(rng.range(0.55, 0.9) * alphaMul))
        ctx.fillPath()
        ctx.restoreGState()
    }
}

// ---------------------------------------------------------------------
// Superellipse ("squircle" / soft ball) boundary. exponent ~2.4 gives a
// round plush ball with no corners. cheekBulge adds two soft outward bulges
// low on the left/right sides (for chubby cheeks on the head).
// ---------------------------------------------------------------------
func superellipseBoundary(cx: Double, cy: Double, rx: Double, ry: Double,
                          exponent: Double = 2.4, points: Int = 360,
                          cheekBulge: Double = 0.0, cheekY: Double = -0.30,
                          topFlatten: Double = 0.0) -> [CGPoint] {
    var pts: [CGPoint] = []
    let n = max(64, points)
    let e = 2.0 / exponent
    for i in 0..<n {
        let t = Double(i) / Double(n) * 2 * .pi
        let ct = cos(t), st = sin(t)
        // signed power for superellipse
        let sx = (ct >= 0 ? 1.0 : -1.0) * pow(abs(ct), e)
        let sy = (st >= 0 ? 1.0 : -1.0) * pow(abs(st), e)
        var x = cx + sx * rx
        var y = cy + sy * ry
        // cheek bulges: add outward horizontal push where sy is near cheekY and
        // |sx| is toward the sides.
        if cheekBulge > 0 {
            let bulge = cheekBulge * exp(-pow((sy - cheekY) / 0.34, 2)) * abs(sx)
            x = cx + sx * rx * (1.0 + bulge)
        }
        // slight flattening of the very top so the head reads as a rounded dome
        // (not egg-pointed) — pulls the top band down a touch.
        if topFlatten > 0 && sy > 0.5 {
            y -= (sy - 0.5) * ry * topFlatten
        }
        pts.append(pt(x, y))
    }
    return pts
}
// Build a CGPath from boundary points.
func cgPath(_ pts: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    guard pts.count > 2 else { return path }
    path.move(to: pts[0])
    for i in 1..<pts.count { path.addLine(to: pts[i]) }
    path.closeSubpath()
    return path
}

// Make a smooth grayscale gradient (for shading fills).
func grayGradient(_ stops: [(loc: CGFloat, gray: Double, alpha: Double)]) -> CGGradient {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    var comps: [CGFloat] = []
    var locs: [CGFloat] = []
    for s in stops {
        let v = CGFloat(clamp(s.gray))
        comps.append(contentsOf: [v, v, v, CGFloat(clamp(s.alpha))])
        locs.append(s.loc)
    }
    return CGGradient(colorSpace: cs, colorComponents: comps, locations: locs, count: stops.count)!
}
func colorGradient(_ stops: [(loc: CGFloat, r: Double, g: Double, b: Double, a: Double)]) -> CGGradient {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    var comps: [CGFloat] = []
    var locs: [CGFloat] = []
    for s in stops {
        comps.append(contentsOf: [CGFloat(clamp(s.r)), CGFloat(clamp(s.g)), CGFloat(clamp(s.b)), CGFloat(clamp(s.a))])
        locs.append(s.loc)
    }
    return CGGradient(colorSpace: cs, colorComponents: comps, locations: locs, count: stops.count)!
}

// Build a per-position luminance function for a plush body: top-left key light
// brightest, bottom-right darkest, clamped to [shadeGray, litGray].
func plushShade(bbox: CGRect, baseGray: Double, litGray: Double, shadeGray: Double) -> (Double, Double) -> Double {
    let minX = Double(bbox.minX), maxX = Double(bbox.maxX)
    let minY = Double(bbox.minY), maxY = Double(bbox.maxY)
    let w = max(1.0, maxX - minX), h = max(1.0, maxY - minY)
    return { px, py in
        // normalized position 0..1
        let u = clamp((px - minX) / w)
        let v = clamp((py - minY) / h)          // v=1 top (CG y up)
        // light from top-left: lit where u small & v large
        let litFactor = clamp(0.5 * (1.0 - u) + 0.5 * v)   // 0..1
        // remap so most of the body sits near baseGray, tails to lit/shade
        let g: Double
        if litFactor >= 0.5 {
            g = lerp(baseGray, litGray, (litFactor - 0.5) * 2.0)
        } else {
            g = lerp(shadeGray, baseGray, litFactor * 2.0)
        }
        return clamp(g, shadeGray, litGray)
    }
}

// =====================================================================
// MARK: - Single-pass plush surface (union mask + alpha-only feather)
//
// The whole part is ONE continuous shaded surface. We build a union
// coverage mask (core shape ∪ all edge lobes) into an offscreen buffer,
// feather ONLY the outer boundary of that union (alpha-only, via a box
// blur of the binary coverage so the interior stays fully opaque), then
// shade the entire masked area in ONE pass from the part's GLOBAL
// geometry (plushShade) — never per-lobe. Lobe "volume" is a subtle
// ±3% luminance modulation with no edges. Feathering only reduces ALPHA;
// RGB luminance always equals the surface luminance at that pixel, and we
// premultiply once when writing. This removes both the inner-contour seam
// (there is no second layer) and the dark halo (no darker edge color).
// =====================================================================

// A lobe used to enlarge the union silhouette outward at the edge.
struct PlushLobe {
    var cx: Double
    var cy: Double
    var ra: Double      // radius along outward normal
    var rc: Double      // radius across
    var ang: Double     // orientation (outward normal angle)
    var bump: Double    // -1..1 subtle volume sign (unused magnitude; ±3% applied)
}

// Rasterize an ellipse (center, radii, rotation) additively into a coverage
// buffer as opaque (1.0) union. `cover` is row-major, size w*h.
func rasterEllipseUnion(_ cover: inout [Float], _ w: Int, _ h: Int,
                        cx: Double, cy: Double, ra: Double, rc: Double, ang: Double) {
    let ca = cos(ang), sa = sin(ang)
    let ext = Int(max(ra, rc)) + 2
    let x0 = max(0, Int(cx) - ext), x1 = min(w - 1, Int(cx) + ext)
    let y0 = max(0, Int(cy) - ext), y1 = min(h - 1, Int(cy) + ext)
    if x0 > x1 || y0 > y1 { return }
    let invRa = 1.0 / max(1e-6, ra), invRc = 1.0 / max(1e-6, rc)
    for y in y0...y1 {
        let dy = Double(y) + 0.5 - cy
        for x in x0...x1 {
            let dx = Double(x) + 0.5 - cx
            // rotate into ellipse frame
            let u = (dx * ca + dy * sa) * invRa
            let v = (-dx * sa + dy * ca) * invRc
            let d = u*u + v*v
            if d <= 1.0 {
                let idx = y*w + x
                if cover[idx] < 1.0 { cover[idx] = 1.0 }
            }
        }
    }
}

// Rasterize a closed polygon (union, opaque) into the coverage buffer using a
// scanline point-in-polygon test at pixel centers.
func rasterPolygonUnion(_ cover: inout [Float], _ w: Int, _ h: Int, _ poly: [CGPoint]) {
    guard poly.count > 2 else { return }
    var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
    var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
    for p in poly {
        minY = min(minY, Double(p.y)); maxY = max(maxY, Double(p.y))
        minX = min(minX, Double(p.x)); maxX = max(maxX, Double(p.x))
    }
    let y0 = max(0, Int(minY)), y1 = min(h - 1, Int(maxY))
    let xL = max(0, Int(minX)), xR = min(w - 1, Int(maxX))
    if y0 > y1 || xL > xR { return }
    let n = poly.count
    for y in y0...y1 {
        let py = Double(y) + 0.5
        // gather intersections of scanline with edges
        var xs: [Double] = []
        var j = n - 1
        for i in 0..<n {
            let yi = Double(poly[i].y), yj = Double(poly[j].y)
            if (yi <= py && yj > py) || (yj <= py && yi > py) {
                let t = (py - yi) / (yj - yi)
                xs.append(Double(poly[i].x) + t * (Double(poly[j].x) - Double(poly[i].x)))
            }
            j = i
        }
        if xs.count < 2 { continue }
        xs.sort()
        var k = 0
        while k + 1 < xs.count {
            let xa = xs[k], xb = xs[k+1]
            let sx = max(xL, Int(xa.rounded())), ex = min(xR, Int(xb.rounded()))
            if sx <= ex {
                for x in sx...ex {
                    let idx = y*w + x
                    if cover[idx] < 1.0 { cover[idx] = 1.0 }
                }
            }
            k += 2
        }
    }
}

// Separable box blur (radius r px) of a coverage buffer, in place-ish.
// Interior 1.0 regions stay 1.0; only the boundary ramps over ~2r px. This is
// the alpha-only OUTER feather.
func boxBlurCoverage(_ src: [Float], _ w: Int, _ h: Int, radius: Int) -> [Float] {
    if radius < 1 { return src }
    let r = radius
    let norm = 1.0 / Float(2*r + 1)
    var tmp = [Float](repeating: 0, count: w*h)
    // horizontal
    for y in 0..<h {
        var acc: Float = 0
        let row = y*w
        // prime the window with clamped-left samples
        for k in -r...r { acc += src[row + min(w-1, max(0, k))] }
        for x in 0..<w {
            tmp[row + x] = acc * norm
            let xout = x - r
            let xin = x + r + 1
            acc -= src[row + min(w-1, max(0, xout))]
            acc += src[row + min(w-1, max(0, xin))]
        }
    }
    var out = [Float](repeating: 0, count: w*h)
    // vertical
    for x in 0..<w {
        var acc: Float = 0
        for k in -r...r { acc += tmp[min(h-1, max(0, k))*w + x] }
        for y in 0..<h {
            out[y*w + x] = acc * norm
            let yout = y - r
            let yin = y + r + 1
            acc -= tmp[min(h-1, max(0, yout))*w + x]
            acc += tmp[min(h-1, max(0, yin))*w + x]
        }
    }
    return out
}

// Feather + shade + composite a PREBUILT union coverage buffer (0/1) into `c`
// as a single continuous, alpha-only-feathered, globally-shaded surface.
// `volume` (optional, same size) adds a subtle ±luminance modulation with no
// edges. Returns the final per-pixel alpha buffer.
func compositeCoverageSurface(_ c: Canvas,
                              coverage: [Float],
                              feather: Double,
                              shade: (Double, Double) -> Double,
                              volume: [Float]? = nil,
                              lift: ((Double, Double) -> Double)? = nil) -> [Float] {
    let w = c.w, h = c.h
    let radius = max(1, Int((feather / 2.0).rounded()))
    let alpha = boxBlurCoverage(coverage, w, h, radius: radius)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    var px = [UInt8](repeating: 0, count: w*h*4)
    for y in 0..<h {
        for x in 0..<w {
            let idx = y*w + x
            let a = alpha[idx]
            if a <= 0 { continue }
            var L = shade(Double(x) + 0.5, Double(y) + 0.5)
            if let volume { L += Double(volume[idx]) }
            if let lift { L += lift(Double(x) + 0.5, Double(y) + 0.5) }
            L = clamp(L)
            let ac = min(1.0, Double(a))
            let v = UInt8(L * ac * 255.0 + 0.5)
            let pi = idx*4
            px[pi+0] = v; px[pi+1] = v; px[pi+2] = v
            px[pi+3] = UInt8(ac * 255.0 + 0.5)
        }
    }
    let img = px.withUnsafeMutableBytes { ptr -> CGImage? in
        guard let bctx = CGContext(data: ptr.baseAddress, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w*4, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        return bctx.makeImage()
    }
    if let img { c.ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h)) }
    return alpha
}

// Build a grayscale mask CGImage that is white (255) only where the surface is
// fully opaque AND at least `erode` px away from any non-opaque pixel. Used to
// clip interior features (e.g., inner-ear tint) strictly inside the opaque core
// so they can never touch the feathered edge (which would create a dark halo).
func erodedOpaqueMask(_ alpha: [Float], _ w: Int, _ h: Int, erode: Int) -> CGImage? {
    // opaque = alpha >= ~0.985
    var op = [Bool](repeating: false, count: w*h)
    for i in 0..<(w*h) { op[i] = alpha[i] >= 0.985 }
    // erode: a pixel stays set only if all pixels within Chebyshev distance `erode`
    // are opaque. Do a separable min (erosion) for speed.
    var tmp = [Bool](repeating: false, count: w*h)
    let r = max(0, erode)
    for y in 0..<h {
        for x in 0..<w {
            var ok = true
            var k = -r
            while k <= r {
                let xx = min(w-1, max(0, x+k))
                if !op[y*w + xx] { ok = false; break }
                k += 1
            }
            tmp[y*w + x] = ok
        }
    }
    var er = [Bool](repeating: false, count: w*h)
    for x in 0..<w {
        for y in 0..<h {
            var ok = true
            var k = -r
            while k <= r {
                let yy = min(h-1, max(0, y+k))
                if !tmp[yy*w + x] { ok = false; break }
                k += 1
            }
            er[y*w + x] = ok
        }
    }
    let cs = CGColorSpaceCreateDeviceGray()
    var m = [UInt8](repeating: 0, count: w*h)
    for i in 0..<(w*h) { m[i] = er[i] ? 255 : 0 }
    return m.withUnsafeMutableBytes { ptr -> CGImage? in
        guard let bctx = CGContext(data: ptr.baseAddress, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w, space: cs,
                                   bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        return bctx.makeImage()
    }
}

// Build the plush surface into `c` as a single continuous, alpha-only-feathered,
// globally-shaded layer.
//   boundary  : the smooth core silhouette (also drives global shading bbox)
//   lobes     : edge lobes to UNION onto the silhouette (their volume adds ±3%
//               luminance modulation only, never an edge)
//   feather   : outer-boundary feather width in px (alpha-only)
//   shade     : global per-pixel luminance field (plushShade)
func compositePlushSurface(_ c: Canvas,
                           boundary: [CGPoint],
                           lobes: [PlushLobe],
                           feather: Double,
                           shade: (Double, Double) -> Double,
                           volumeMod: Bool = true) -> [Float] {
    let w = c.w, h = c.h
    // 1. Union coverage (binary) of core polygon ∪ all lobes.
    var cover = [Float](repeating: 0, count: w*h)
    rasterPolygonUnion(&cover, w, h, boundary)
    for lo in lobes {
        rasterEllipseUnion(&cover, w, h, cx: lo.cx, cy: lo.cy, ra: lo.ra, rc: lo.rc, ang: lo.ang)
    }
    // 2. Per-lobe subtle volume field (±3% max, smooth, no edges).
    var vol: [Float]? = nil
    if volumeMod && !lobes.isEmpty {
        var v = [Float](repeating: 0, count: w*h)
        for lo in lobes {
            let sigma = max(lo.ra, lo.rc) * 0.9
            let inv2s2 = 1.0 / (2.0 * sigma * sigma)
            let ext = Int(sigma * 2.4) + 2
            let x0 = max(0, Int(lo.cx) - ext), x1 = min(w - 1, Int(lo.cx) + ext)
            let y0 = max(0, Int(lo.cy) - ext), y1 = min(h - 1, Int(lo.cy) + ext)
            if x0 > x1 || y0 > y1 { continue }
            let amp: Float = 0.03 * Float(lo.bump)   // ±3% max
            for y in y0...y1 {
                let dy = Double(y) + 0.5 - lo.cy
                for x in x0...x1 {
                    let dx = Double(x) + 0.5 - lo.cx
                    let g = exp(-(dx*dx + dy*dy) * inv2s2)
                    v[y*w + x] += amp * Float(g)
                }
            }
        }
        vol = v
    }
    // 3. Alpha-only outer feather + single-pass shading + composite.
    return compositeCoverageSurface(c, coverage: cover, feather: feather,
                                    shade: shade, volume: vol)
}

// Build edge lobes whose centers sit ON/just-inside the boundary, elongated
// outward, to UNION onto the silhouette. Deterministic from `rng`.
func buildEdgeLobes(_ rng: inout SplitMix64,
                    boundary: [CGPoint],
                    centroid: CGPoint,
                    lobeR: Double,
                    lobeElong: Double,
                    spacing: Double,
                    outwardBias: Double = 0.0,   // 0 = centered on edge; + pushes outward
                    bounds: CGRect? = nil) -> [PlushLobe] {
    guard boundary.count > 3 else { return [] }
    let n = boundary.count
    var perim = 0.0
    for i in 0..<n {
        let a = boundary[i], b = boundary[(i+1)%n]
        perim += hypot(Double(b.x - a.x), Double(b.y - a.y))
    }
    let lobeCount = max(6, Int(perim / max(4.0, spacing)))
    var out: [PlushLobe] = []
    out.reserveCapacity(lobeCount)
    for li in 0..<lobeCount {
        let fpos = (Double(li) + rng.range(-0.28, 0.28)) / Double(lobeCount)
        let idx = ((Int((fpos * Double(n)).rounded(.down)) % n) + n) % n
        let bp = boundary[idx]
        let (nx, ny) = outwardNormal(boundary, idx, centroid: centroid)
        let r = lobeR * rng.range(0.75, 1.25)
        // center slightly inside so the lobe overlaps the core (seamless union),
        // optionally biased outward for fringe overlays.
        let off = -r * 0.30 + outwardBias * r * rng.range(0.0, 1.0)
        let cxp = Double(bp.x) + nx * off
        let cyp = Double(bp.y) + ny * off
        let ra = r * lobeElong, rc = r
        if let b = bounds {
            let ext = max(ra, rc) + 1.0
            if cxp - ext < Double(b.minX) || cxp + ext > Double(b.maxX) ||
               cyp - ext < Double(b.minY) || cyp + ext > Double(b.maxY) { continue }
        }
        let bump = rng.range(-1.0, 1.0)
        out.append(PlushLobe(cx: cxp, cy: cyp, ra: ra, rc: rc, ang: atan2(ny, nx), bump: bump))
    }
    return out
}

// Faint internal strands drawn AFTER the surface, clipped to the surface alpha,
// ALPHA-ONLY: the stroke's RGB luminance equals the surface luminance at that
// point so it can never form a darker fringe; only alpha varies.
func drawSurfaceStrands(_ c: Canvas,
                        _ rng: inout SplitMix64,
                        alpha: [Float],
                        bbox: CGRect,
                        centroid: CGPoint,
                        count: Int,
                        lenMin: Double, lenMax: Double,
                        shade: (Double, Double) -> Double,
                        strandAlpha: Double) {
    let ctx = c.ctx
    let w = c.w
    ctx.saveGState()
    ctx.setLineCap(.round)
    for _ in 0..<count {
        let x = rng.range(Double(bbox.minX), Double(bbox.maxX))
        let y = rng.range(Double(bbox.minY), Double(bbox.maxY))
        // must be inside the surface
        let ix = Int(x), iy = Int(y)
        if ix < 0 || iy < 0 || ix >= w || iy >= c.h { continue }
        if alpha[iy*w + ix] < 0.9 { continue }
        var dx = x - Double(centroid.x)
        var dy = y - Double(centroid.y)
        let d = (dx*dx + dy*dy).squareRoot()
        if d < 1 { continue }
        dx /= d; dy /= d
        let len = rng.range(lenMin, lenMax)
        let curl = rng.range(-0.4, 0.4)
        let px = -dy, py = dx
        let start = pt(x, y)
        let end = pt(x + dx * len, y + dy * len)
        let ctrl = pt((x + Double(end.x)) * 0.5 + px * len * curl,
                      (y + Double(end.y)) * 0.5 + py * len * curl)
        // ALPHA-ONLY: luminance = surface luminance here (no darkening).
        let g = shade(x, y)
        setStrokeGray(ctx, g, strandAlpha)
        ctx.setLineWidth(CGFloat(rng.range(0.8, 1.6)))
        ctx.beginPath()
        ctx.move(to: start)
        ctx.addQuadCurve(to: end, control: ctrl)
        ctx.strokePath()
    }
    ctx.restoreGState()
}

// =====================================================================
// MARK: - High-level plush blob renderer
// =====================================================================

// Renders a soft plush shape with a FEATHERED edge and hundreds of tapered fur
// strands along the silhouette. Geometry is inset (via rx/ry chosen by caller +
// an internal safety inset) so the shape + strands + feather fit within the
// canvas with a clear transparent margin.
@discardableResult
func renderPlushBlob(_ c: Canvas,
                     _ rng: inout SplitMix64,
                     cx: Double, cy: Double,
                     rx: Double, ry: Double,
                     lobes: Int = 5,
                     lobeAmt: Double = 0.06,
                     fluff: Double = 1.0,        // multiplier on lobe radius/density
                     pointy: Double = 0.15,
                     baseGray: Double = 0.86,
                     litGray: Double = 1.0,
                     shadeGray: Double = 0.72,
                     strands: Bool = true,
                     customBoundary: [CGPoint]? = nil,
                     lobeR: Double = 16.0) -> (boundary: [CGPoint], centroid: CGPoint) {
    let W = Double(c.w), H = Double(c.h)

    // Reserve room for feather + clumped lobes (lobes stick out ~lobeR*1.6) + margin.
    let lobeMax = lobeR * fluff * 1.7
    let feather = 8.0
    let margin = lobeMax + feather + 4.0
    let maxRx = W/2 - margin
    let maxRy = H/2 - margin
    let bx = min(rx, maxRx)
    let by = min(ry, maxRy)
    let ccx = min(max(cx, margin + bx), W - margin - bx)
    let ccy = min(max(cy, margin + by), H - margin - by)
    let ctr = pt(ccx, ccy)

    let boundary: [CGPoint]
    if let cb = customBoundary {
        boundary = cb
    } else {
        let bp = BlobParams(cx: ccx, cy: ccy, rx: bx * (1 - lobeAmt), ry: by * (1 - lobeAmt),
                            lobes: lobes, lobeAmt: lobeAmt,
                            tuftCount: 0, tuftLen: 0, tuftJitter: 0, points: 360)
        boundary = fluffyBoundary(&rng, bp)
    }
    let ctrUse = customBoundary != nil ? centroidOf(boundary) : ctr
    let path = cgPath(boundary)
    let bbox = path.boundingBox
    let shade = plushShade(bbox: bbox, baseGray: baseGray, litGray: litGray, shadeGray: shadeGray)

    // ONE continuous surface: union of the core silhouette + edge lobes, shaded
    // globally in a single pass with alpha-only outer feather. No inner contour
    // can exist because there is no second (core-over-lobes) layer, and the
    // feather only reduces alpha so no darker halo forms.
    let safe = CGRect(x: 2, y: 2, width: W - 4, height: H - 4)
    var lobes: [PlushLobe] = []
    if strands {
        var lr = rng
        lobes = buildEdgeLobes(&lr, boundary: boundary, centroid: ctrUse,
                               lobeR: lobeR * fluff,
                               lobeElong: lerp(1.15, 1.7, clamp(pointy)),
                               spacing: lobeR * fluff * 1.15,
                               outwardBias: 0.0, bounds: safe)
    }
    let surfaceAlpha = compositePlushSurface(c, boundary: boundary, lobes: lobes,
                                             feather: feather, shade: shade,
                                             volumeMod: true)

    // Faint internal fur strands, clipped to the surface, ALPHA-ONLY (luminance
    // equals the surface luminance so they never darken the edge).
    if strands {
        drawSurfaceStrands(c, &rng, alpha: surfaceAlpha, bbox: bbox, centroid: ctrUse,
                           count: Int(280 * fluff), lenMin: 8, lenMax: 18,
                           shade: shade, strandAlpha: 0.04)
    }

    return (boundary, ctrUse)
}

// =====================================================================
// MARK: - Per-texture drawing
// =====================================================================

func drawTexture(_ spec: TexSpec) -> CGImage {
    let c = Canvas(spec.w, spec.h)
    let ctx = c.ctx
    var rng = SplitMix64(seed: fnv1a64(spec.name))
    let W = Double(spec.w), H = Double(spec.h)

    switch spec.name {

    // ---- BODIES -------------------------------------------------------
    case "body_round":
        renderPlushBlob(c, &rng, cx: W/2, cy: H/2 - 6, rx: W*0.42, ry: H*0.42,
                        lobes: 5, lobeAmt: 0.04, fluff: 1.0, pointy: 0.10, lobeR: 15)
    case "body_compact":
        renderPlushBlob(c, &rng, cx: W/2, cy: H/2 - 6, rx: W*0.43, ry: H*0.40,
                        lobes: 4, lobeAmt: 0.04, fluff: 0.95, pointy: 0.08, lobeR: 14)
    case "body_pear":
        // narrower top, wider bottom
        renderPlushBlob(c, &rng, cx: W/2, cy: H*0.42, rx: W*0.41, ry: H*0.38,
                        lobes: 5, lobeAmt: 0.05, fluff: 1.0, pointy: 0.10, lobeR: 15)
    case "fallback_body":
        renderPlushBlob(c, &rng, cx: W/2, cy: H/2 - 6, rx: W*0.42, ry: H*0.42,
                        lobes: 4, lobeAmt: 0.03, fluff: 0.7, pointy: 0.08, strands: false)

    // ---- HEAD ---------------------------------------------------------
    // head_base and fallback_head are the generic head; fur_* are COMPLETE
    // head variants rendered with the SAME single-pass plush pipeline, differing
    // only in the edge lobes of the union mask (see drawHead / HeadStyle).
    case "head_base":
        drawHead(c, &rng, style: .generic, fluff: 1.0)
    case "fallback_head":
        drawHead(c, &rng, style: .generic, fluff: 0.7)

    // ---- ABDOMEN (lighter belly patch) --------------------------------
    case "abdomen_soft":
        drawFeatheredPatch(c, &rng, cx: W/2, cy: H/2, rx: W*0.40, ry: H*0.42,
                           baseGray: 0.97, edgeSoft: 0.34, lobes: 4, lobeAmt: 0.05)

    // ---- PAWS ---------------------------------------------------------
    case "paws_round", "fallback_paws":
        drawPaws(c, &rng)

    // ---- HEAD VARIANTS (complete heads, not overlays) -----------------
    // Each fur_* is a full head with the SAME center/inner silhouette as
    // head_base, differing only in the edge lobes of the union mask.
    case "fur_smooth":
        drawHead(c, &rng, style: .smooth, fluff: 1.0)
    case "fur_fluffy":
        drawHead(c, &rng, style: .fluffy, fluff: 1.0)
    case "fur_spiky":
        drawHead(c, &rng, style: .spiky, fluff: 1.0)

    // ---- EARS ---------------------------------------------------------
    case "ear_pointed", "fallback_ear":
        drawEar(c, &rng, style: .pointed)
    case "ear_rounded":
        drawEar(c, &rng, style: .rounded)
    case "ear_long":
        drawEar(c, &rng, style: .long)
    case "ear_floppy":
        drawEar(c, &rng, style: .floppy)

    // ---- TAILS --------------------------------------------------------
    case "tail_short":
        drawTail(c, &rng, style: .short)
    case "tail_long", "fallback_tail":
        drawTail(c, &rng, style: .long)
    case "tail_curled":
        drawTail(c, &rng, style: .curled)
    case "tail_plume":
        drawTail(c, &rng, style: .plume)

    // ---- HEAD TUFTS ---------------------------------------------------
    case "headtuft_curl":
        drawHeadTuft(c, &rng, style: .curl)
    case "headtuft_split":
        drawHeadTuft(c, &rng, style: .split)
    case "headtuft_windswept":
        drawHeadTuft(c, &rng, style: .windswept)

    // ---- CHEST TUFTS --------------------------------------------------
    case "chesttuft_small":
        drawChestTuft(c, &rng, layers: 2, spread: 0.7)
    case "chesttuft_layered":
        drawChestTuft(c, &rng, layers: 3, spread: 0.85)
    case "chesttuft_cloud":
        drawChestTuft(c, &rng, layers: 4, spread: 1.0)

    // ---- PATTERNS -----------------------------------------------------
    case "pattern_spots":
        drawPatternSpots(c, &rng)
    case "pattern_stripes":
        drawPatternStripes(c, &rng)
    case "pattern_socks":
        drawPatternSocks(c, &rng)
    case "pattern_gradient":
        drawPatternGradient(c, &rng)
    case "pattern_mask":
        drawPatternMask(c, &rng)

    // ---- EYELID -------------------------------------------------------
    case "eyelid":
        drawEyelid(c, &rng)

    // ---- IRIS ---------------------------------------------------------
    case "iris_base":
        drawIrisBase(c, &rng)

    // ---- MUZZLES ------------------------------------------------------
    case "muzzle_small":
        drawFeatheredPatch(c, &rng, cx: W/2, cy: H*0.46, rx: W*0.42, ry: H*0.42,
                           baseGray: 0.98, edgeSoft: 0.4, lobes: 3, lobeAmt: 0.04)
    case "muzzle_round":
        drawFeatheredPatch(c, &rng, cx: W/2, cy: H*0.46, rx: W*0.44, ry: H*0.44,
                           baseGray: 0.98, edgeSoft: 0.4, lobes: 3, lobeAmt: 0.05)
    case "muzzle_pronounced":
        drawFeatheredPatch(c, &rng, cx: W/2, cy: H*0.44, rx: W*0.45, ry: H*0.46,
                           baseGray: 0.98, edgeSoft: 0.38, lobes: 4, lobeAmt: 0.06)

    // ---- NOSES --------------------------------------------------------
    case "nose_dot":
        drawNose(c, &rng, style: .dot)
    case "nose_triangle":
        drawNose(c, &rng, style: .triangle)
    case "nose_heart":
        drawNose(c, &rng, style: .heart)

    // ---- CHEEKS -------------------------------------------------------
    case "cheek_blush":
        drawCheek(c, &rng, style: .blush)
    case "cheek_freckles":
        drawCheek(c, &rng, style: .freckles)
    case "cheek_glow":
        drawCheek(c, &rng, style: .glow)

    // ---- MAGIC --------------------------------------------------------
    case "magic_glow":
        drawMagic(c, &rng, style: .glow)
    case "magic_sparkles":
        drawMagic(c, &rng, style: .sparkles)
    case "magic_orbiting_light":
        drawMagic(c, &rng, style: .orbiting)

    // ---- EYES (non-tinted, final color) -------------------------------
    case "eye_round", "fallback_eye":
        drawEye(c, &rng, style: .round)
    case "eye_almond":
        drawEye(c, &rng, style: .almond)
    case "eye_sleepy":
        drawEye(c, &rng, style: .sleepy)

    // ---- PUPILS -------------------------------------------------------
    case "pupil_round":
        drawPupil(c, &rng, style: .round)
    case "pupil_vertical":
        drawPupil(c, &rng, style: .vertical)
    case "pupil_star":
        drawPupil(c, &rng, style: .star)

    // ---- CATCHLIGHT ---------------------------------------------------
    case "eye_catchlight":
        drawCatchlight(c, &rng)

    // ---- SHADOW -------------------------------------------------------
    case "shadow_diffuse":
        drawShadow(c, &rng)

    default:
        // placeholder: transparent, filled later as functions are added
        break
    }

    return c.image
}

// Feathered soft patch (belly, muzzle, cheeks) — soft radial with feather edge.
func drawFeatheredPatch(_ c: Canvas, _ rng: inout SplitMix64,
                        cx: Double, cy: Double, rx: Double, ry: Double,
                        baseGray: Double, edgeSoft: Double,
                        lobes: Int, lobeAmt: Double) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    // Keep the whole feathered ellipse inside the canvas with a margin.
    let margin = 10.0
    let bx = min(rx, W/2 - margin)
    let by = min(ry, H/2 - margin)
    let ccx = min(max(cx, margin + bx), W - margin - bx)
    let ccy = min(max(cy, margin + by), H - margin - by)
    let bp = BlobParams(cx: ccx, cy: ccy, rx: bx, ry: by, lobes: lobes, lobeAmt: lobeAmt,
                        tuftCount: 0, tuftLen: 0, tuftJitter: 0, points: 300)
    let boundary = fluffyBoundary(&rng, bp)
    let path = cgPath(boundary)
    let bbox = path.boundingBox
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    // soft radial: bright center feathering to transparent at edge
    let grad = grayGradient([
        (0.0, baseGray, 0.95),
        (1.0 - edgeSoft, lerp(baseGray, 0.9, 0.5), 0.85),
        (1.0, baseGray, 0.0),
    ])
    let ctr = CGPoint(x: bbox.midX, y: bbox.midY + bbox.height * 0.10)
    ctx.drawRadialGradient(grad, startCenter: ctr, startRadius: 0,
                           endCenter: ctr, endRadius: max(bbox.width, bbox.height) * 0.6,
                           options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}

// Two short rounded front paws side by side.
func drawPaws(_ c: Canvas, _ rng: inout SplitMix64) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let margin = 22.0
    let safe = CGRect(x: 6, y: 6, width: W - 12, height: H - 12)
    for side in [-1.0, 1.0] {
        let cx = W/2 + side * W*0.19
        let cy = H*0.50
        let rx = min(W*0.15, W*0.5 - 0), ry = min(H*0.32, H/2 - margin)
        let bp = BlobParams(cx: cx, cy: cy, rx: rx, ry: ry, lobes: 3, lobeAmt: 0.05,
                            tuftCount: 0, tuftLen: 0, tuftJitter: 0, points: 200)
        var r2 = rng
        let boundary = fluffyBoundary(&r2, bp)
        let bbox = cgPath(boundary).boundingBox
        let ctr = pt(cx, cy)
        let shade = plushShade(bbox: bbox, baseGray: 0.88, litGray: 1.0, shadeGray: 0.76)
        var sr = rng
        let lobes = buildEdgeLobes(&sr, boundary: boundary, centroid: ctr,
                                   lobeR: 7, lobeElong: 1.15, spacing: 11,
                                   outwardBias: 0.15, bounds: safe)
        _ = compositePlushSurface(c, boundary: boundary, lobes: lobes, feather: 5, shade: shade)
    }
    _ = ctx
}

print("generate.swift loaded (foundation section). \(TEXTURES.count) textures registered.")

// =====================================================================
// MARK: - Patterns (soft-edged marking overlays, near-white luminance)
// =====================================================================

// Soft radial spot at (x,y).
func softSpot(_ ctx: CGContext, _ x: Double, _ y: Double, _ r: Double, gray: Double, alpha: Double) {
    let grad = grayGradient([
        (0.0, gray, alpha),
        (0.6, gray, alpha*0.85),
        (1.0, gray, 0.0),
    ])
    ctx.drawRadialGradient(grad, startCenter: pt(x, y), startRadius: 0,
                           endCenter: pt(x, y), endRadius: r, options: [])
}

func drawPatternSpots(_ c: Canvas, _ rng: inout SplitMix64) {
    let W = Double(c.w), H = Double(c.h)
    let n = 14
    for _ in 0..<n {
        let x = rng.range(W*0.18, W*0.82)
        let y = rng.range(H*0.20, H*0.80)
        let r = rng.range(W*0.05, W*0.11)
        softSpot(c.ctx, x, y, r, gray: rng.range(0.78, 0.86), alpha: 0.9)
    }
}

func drawPatternStripes(_ c: Canvas, _ rng: inout SplitMix64) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let count = 6
    // Clip to an inset ellipse so the outer ring stays transparent (the pattern
    // is masked to the body silhouette at runtime anyway).
    ctx.saveGState()
    ctx.beginPath()
    ctx.addEllipse(in: CGRect(x: W*0.07, y: H*0.07, width: W*0.86, height: H*0.86))
    ctx.clip()
    for i in 0..<count {
        let cx = lerp(W*0.20, W*0.80, Double(i)/Double(count-1))
        let w = rng.range(W*0.03, W*0.055)
        let grad = grayGradient([(0.0, 0.82, 0.0), (0.5, 0.80, 0.85), (1.0, 0.82, 0.0)])
        ctx.drawLinearGradient(grad,
                               start: pt(cx - w, H/2), end: pt(cx + w, H/2),
                               options: [])
    }
    ctx.restoreGState()
}

func drawPatternSocks(_ c: Canvas, _ rng: inout SplitMix64) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    // Two darker "sock" bands. Keep the radial fully inside the short paw canvas.
    let r = min(W*0.14, H*0.42)
    for side in [-1.0, 1.0] {
        let cx = W/2 + side * W*0.19
        let cy = H*0.50
        let grad = grayGradient([(0.0, 0.80, 0.9), (0.7, 0.82, 0.7), (1.0, 0.85, 0.0)])
        ctx.drawRadialGradient(grad, startCenter: pt(cx, cy), startRadius: 0,
                               endCenter: pt(cx, cy), endRadius: r, options: [])
    }
    _ = rng
}

func drawPatternGradient(_ c: Canvas, _ rng: inout SplitMix64) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    // Vertical soft gradient darker at bottom (a subtle two-tone belly-to-back).
    let grad = grayGradient([(0.0, 0.78, 0.85), (0.5, 0.86, 0.5), (1.0, 0.95, 0.0)])
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: W*0.06, y: H*0.06, width: W*0.88, height: H*0.88))
    ctx.clip()
    ctx.drawLinearGradient(grad, start: pt(W/2, 0), end: pt(W/2, H), options: [])
    ctx.restoreGState()
    _ = rng
}

func drawPatternMask(_ c: Canvas, _ rng: inout SplitMix64) {
    let W = Double(c.w), H = Double(c.h)
    // Face mask around the upper face / eyes region: soft feathered patch.
    drawFeatheredPatch(c, &rng, cx: W/2, cy: H*0.58, rx: W*0.36, ry: H*0.28,
                       baseGray: 0.80, edgeSoft: 0.5, lobes: 4, lobeAmt: 0.08)
}

// =====================================================================
// MARK: - Eyelid (fur-colored)
// =====================================================================

func drawEyelid(_ c: Canvas, _ rng: inout SplitMix64) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    // A soft dome covering the top; fur-colored (near-white luminance, shaded).
    // Sample the dome outline into points, inset so it fits with a margin, then
    // feather + shade it.
    let baseY = H*0.46
    let apexY = H*0.90
    var boundary: [CGPoint] = []
    let n = 80
    for i in 0...n {
        let t = Double(i)/Double(n)
        let x = lerp(W*0.06, W*0.94, t)
        let y = (1-t)*(1-t)*baseY + 2*(1-t)*t*apexY + t*t*baseY
        boundary.append(pt(x, min(y, H - 6)))
    }
    // close along the base
    boundary.append(pt(W*0.94, baseY))
    boundary.append(pt(W*0.06, baseY))
    let bb = cgPath(boundary).boundingBox
    // Single continuous surface, global shading, alpha-only feather (no halo).
    let shade = plushShade(bbox: bb, baseGray: 0.86, litGray: 1.0, shadeGray: 0.74)
    _ = compositePlushSurface(c, boundary: boundary, lobes: [], feather: 4,
                              shade: shade, volumeMod: false)
    _ = ctx
    _ = rng
}

// =====================================================================
// MARK: - Iris base (colored ring gradient) — non-tinted-ish but neutral bright ring
// =====================================================================

func drawIrisBase(_ c: Canvas, _ rng: inout SplitMix64) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let cx = W/2, cy = H/2
    let half = W*0.5 - 4.0
    // Subtle THIN warm glow ring: fully transparent inside 0.78, ramps up to a
    // low-alpha (~0.35) bright band around 0.86-0.90, fading out by 0.95. Neutral
    // bright luminance so a warm tint colors it. Combined with the eye's own thin
    // rim this must NOT form a thick band. Radius kept a few px inside the canvas
    // so the outer ring stays fully transparent at the border (border-ring check).
    let grad = grayGradient([
        (0.0, 1.0, 0.0),
        (0.78, 1.0, 0.0),
        (0.86, 1.0, 0.28),   // thin ring peak, low alpha
        (0.90, 1.0, 0.35),
        (0.95, 0.92, 0.08),
        (1.0, 0.88, 0.0),
    ])
    ctx.drawRadialGradient(grad, startCenter: pt(cx, cy), startRadius: 0,
                           endCenter: pt(cx, cy), endRadius: half, options: [])
    _ = rng
}

print("generate.swift patterns/eyelid/iris loaded.")

// =====================================================================
// MARK: - Nose (tintable, near-white with a highlight)
// =====================================================================

enum NoseStyle { case dot, triangle, heart }

func drawNose(_ c: Canvas, _ rng: inout SplitMix64, style: NoseStyle) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let cx = W/2, cy = H*0.52
    ctx.saveGState()
    ctx.beginPath()
    switch style {
    case .dot:
        ctx.addEllipse(in: CGRect(x: W*0.16, y: H*0.24, width: W*0.68, height: H*0.56))
    case .triangle:
        ctx.move(to: pt(W*0.14, H*0.72))
        ctx.addLine(to: pt(W*0.86, H*0.72))
        ctx.addQuadCurve(to: pt(W*0.5, H*0.16), control: pt(W*0.62, H*0.30))
        ctx.closePath()
    case .heart:
        // small heart
        ctx.move(to: pt(cx, H*0.20))
        ctx.addCurve(to: pt(W*0.10, H*0.70), control1: pt(W*0.34, H*0.10), control2: pt(W*0.10, H*0.42))
        ctx.addQuadCurve(to: pt(cx, H*0.88), control: pt(W*0.10, H*0.92))
        ctx.addQuadCurve(to: pt(W*0.90, H*0.70), control: pt(W*0.90, H*0.92))
        ctx.addCurve(to: pt(cx, H*0.20), control1: pt(W*0.90, H*0.42), control2: pt(W*0.66, H*0.10))
        ctx.closePath()
    }
    let path = ctx.path!.copy()!
    ctx.clip()
    let bb = path.boundingBox
    // near-white luminance with soft shading + top-left highlight. Keep the
    // form-shadow shallow so the clipped edge never reads >0.06 darker than the
    // surface (alpha-only-feather / no-halo contract for tintable parts).
    let grad = grayGradient([
        (0.0, 1.0, 1.0),
        (0.5, 0.95, 1.0),
        (1.0, 0.90, 1.0),
    ])
    let lit = pt(Double(bb.midX) - bb.width*0.25, Double(bb.midY) + bb.height*0.28)
    ctx.drawRadialGradient(grad, startCenter: lit, startRadius: 0,
                           endCenter: pt(bb.midX, bb.midY), endRadius: Double(max(bb.width, bb.height))*0.7,
                           options: [.drawsAfterEndLocation])
    // crisp small highlight
    setGray(ctx, 1.0, 0.9)
    ctx.fillEllipse(in: CGRect(x: Double(bb.midX)-bb.width*0.28, y: Double(bb.midY)+bb.height*0.06,
                               width: bb.width*0.22, height: bb.height*0.18))
    ctx.restoreGState()
    _ = rng
}

// =====================================================================
// MARK: - Cheeks (very soft blush, tintable)
// =====================================================================

enum CheekStyle { case blush, freckles, glow }

func drawCheek(_ c: Canvas, _ rng: inout SplitMix64, style: CheekStyle) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let cx = W/2, cy = H/2
    // Feathered ellipse that fades to 0 alpha well inside the canvas. Use a CTM
    // scale so a radial (which fades to 0 at its end radius) becomes an ellipse
    // matching the canvas aspect, guaranteeing no rectangular cut.
    func softEllipse(_ rxFrac: Double, _ ryFrac: Double, gray: Double, alpha: Double) {
        let margin = 6.0
        let rx = min(W*0.5 - margin, W * rxFrac)
        let ry = min(H*0.5 - margin, H * ryFrac)
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(cx), y: CGFloat(cy))
        ctx.scaleBy(x: 1.0, y: CGFloat(ry / rx))
        let grad = grayGradient([
            (0.0, gray, alpha),
            (0.55, gray, alpha*0.8),
            (0.85, gray, alpha*0.25),
            (1.0, gray, 0.0),
        ])
        ctx.drawRadialGradient(grad, startCenter: .zero, startRadius: 0,
                               endCenter: .zero, endRadius: CGFloat(rx), options: [])
        ctx.restoreGState()
    }
    switch style {
    case .blush:
        softEllipse(0.40, 0.40, gray: 0.92, alpha: 0.7)
    case .glow:
        softEllipse(0.44, 0.44, gray: 0.96, alpha: 0.8)
        softEllipse(0.26, 0.26, gray: 1.0, alpha: 0.5)
    case .freckles:
        softEllipse(0.40, 0.40, gray: 0.9, alpha: 0.45)
        for _ in 0..<7 {
            let x = rng.range(W*0.30, W*0.70)
            let y = rng.range(H*0.32, H*0.68)
            softSpot(ctx, x, y, min(W, H)*0.06, gray: 0.85, alpha: 0.8)
        }
    }
}

// =====================================================================
// MARK: - Magic effects (white luminance glow, tintable)
// =====================================================================

enum MagicStyle { case glow, sparkles, orbiting }

func star(_ ctx: CGContext, cx: Double, cy: Double, r: Double, points: Int, inner: Double) {
    ctx.beginPath()
    for i in 0..<(points*2) {
        let ang = Double(i) / Double(points*2) * 2 * .pi - .pi/2
        let rr = (i % 2 == 0) ? r : r*inner
        let x = cx + cos(ang)*rr, y = cy + sin(ang)*rr
        if i == 0 { ctx.move(to: pt(x, y)) } else { ctx.addLine(to: pt(x, y)) }
    }
    ctx.closePath()
}

func drawMagic(_ c: Canvas, _ rng: inout SplitMix64, style: MagicStyle) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let cx = W/2, cy = H/2
    let margin = 8.0
    let maxR = min(W, H) * 0.5 - margin
    // central soft glow (fully faded before the border)
    let glow = grayGradient([(0.0, 1.0, 0.85), (0.4, 1.0, 0.4), (0.9, 1.0, 0.03), (1.0, 1.0, 0.0)])
    ctx.drawRadialGradient(glow, startCenter: pt(cx, cy), startRadius: 0,
                           endCenter: pt(cx, cy), endRadius: maxR, options: [])
    switch style {
    case .glow:
        // extra inner bright core
        let core = grayGradient([(0.0, 1.0, 0.9), (1.0, 1.0, 0.0)])
        ctx.drawRadialGradient(core, startCenter: pt(cx, cy), startRadius: 0,
                               endCenter: pt(cx, cy), endRadius: maxR*0.45, options: [])
    case .sparkles:
        for _ in 0..<14 {
            let x = rng.range(W*0.16, W*0.84)
            let y = rng.range(H*0.16, H*0.84)
            let r = rng.range(W*0.02, W*0.055)
            setGray(ctx, 1.0, rng.range(0.6, 1.0))
            star(ctx, cx: x, cy: y, r: r, points: 4, inner: 0.35)
            ctx.fillPath()
        }
    case .orbiting:
        for k in 0..<8 {
            let ang = Double(k)/8.0 * 2 * .pi
            let rr = maxR * 0.62
            let x = cx + cos(ang)*rr, y = cy + sin(ang)*rr
            softSpot(ctx, x, y, min(W, H)*0.055, gray: 1.0, alpha: 0.85)
        }
    }
}

print("generate.swift nose/cheek/magic loaded.")

// =====================================================================
// MARK: - Eyes (NON-TINTED, final color: glossy near-black + warm brown rim)
// =====================================================================

enum EyeStyle { case round, almond, sleepy }

func drawEye(_ c: Canvas, _ rng: inout SplitMix64, style: EyeStyle) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let cx = W/2, cy = H/2
    let inset = 5.0
    // Available half-extents inside the feather margin.
    let hx = W/2 - inset
    let hy = H/2 - inset

    // Build the eye silhouette as a smooth CLOSED rounded shape. No pointed
    // corners: round = near-circle (slightly taller than wide); almond = soft
    // rounded almond whose corner radius is >=20% of height and stays within the
    // iris-sized footprint; sleepy = rounded lower half-disc.
    var boundary: [CGPoint] = []
    let n = 240
    switch style {
    case .round:
        // Ellipse, slightly taller than wide, fills the footprint.
        let rx = hx * 0.92, ry = hy * 0.98
        for i in 0..<n {
            let t = Double(i)/Double(n) * 2 * .pi
            boundary.append(pt(cx + cos(t)*rx, cy + sin(t)*ry))
        }
    case .almond:
        // Rounded almond: superellipse wider than tall, exponent chosen so the
        // horizontal corners are ROUNDED (no wings). Contained inside footprint.
        let rx = hx * 0.96, ry = hy * 0.80
        let e = 2.0 / 2.6   // exponent 2.6 -> rounded, no points
        for i in 0..<n {
            let t = Double(i)/Double(n) * 2 * .pi
            let ct = cos(t), st = sin(t)
            let sx = (ct >= 0 ? 1.0 : -1.0) * pow(abs(ct), e)
            let sy = (st >= 0 ? 1.0 : -1.0) * pow(abs(st), e)
            boundary.append(pt(cx + sx*rx, cy + sy*ry))
        }
    case .sleepy:
        // Rounded lower half-disc: flat-ish top (droopy lid), round bottom.
        let rx = hx * 0.96, ry = hy * 0.92
        let topY = cy + ry * 0.30      // lid line
        // bottom half arc left->right along the bottom
        let half = 160
        for i in 0...half {
            let t = Double(i)/Double(half)
            let ang = .pi - t * .pi     // pi (left) -> 0 (right), lower semicircle uses sin<0
            let x = cx + cos(ang) * rx
            let y = cy - abs(sin(ang)) * ry
            boundary.append(pt(x, y))
        }
        // top lid: gentle downward-bowed line right->left (slightly convex)
        let topN = 80
        for i in 0...topN {
            let t = Double(i)/Double(topN)
            let x = cx + rx - 2*rx*t
            let bow = sin(.pi * t) * ry * 0.12
            boundary.append(pt(x, topY + bow))
        }
    }
    let path = cgPath(boundary)
    let bb = path.boundingBox
    let ctr = pt(bb.midX, bb.midY)

    // 1. Feathered eye disk edge (warm-dark), soft ~2px ramp — no outline stroke.
    fillFeatheredColor(ctx, boundary: boundary, centroid: ctr, feather: 2.0, rings: 3,
                       r: 0.24, g: 0.16, b: 0.11, coreAlpha: 1.0)

    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    // 2. Base: predominantly DARK glossy near-black across the whole eye. A very
    //    gentle vertical lift keeps the lower area a touch less black (glossy).
    let baseDark = colorGradient([
        (0.0, 0.055, 0.045, 0.070, 1.0),   // top: darkest (upper-lid shadow)
        (0.5, 0.070, 0.058, 0.088, 1.0),
        (1.0, 0.090, 0.072, 0.105, 1.0),   // bottom: slightly lifted near-black
    ])
    ctx.drawLinearGradient(baseDark,
                           start: pt(bb.midX, bb.maxY),
                           end: pt(bb.midX, bb.minY),
                           options: [])
    // 3. THIN warm-brown rim: only the outer ~12-16% of the radius, achieved by
    //    a radial gradient that stays fully transparent until 0.84 then ramps to
    //    warm brown at the very edge. Combined with a vertical mask it is
    //    strongest at the BOTTOM and fades toward the top.
    let bw = Double(bb.width), bh = Double(bb.height)
    let radMax = max(bw, bh) * 0.5
    // Draw the rim as a soft annulus using CTM-scaled circular radial so it
    // hugs the (possibly non-circular) eye shape.
    ctx.saveGState()
    ctx.translateBy(x: bb.midX, y: bb.midY)
    ctx.scaleBy(x: 1.0, y: CGFloat(bh / bw))
    // Vertical clip-free approach: we bake the top-fade into two passes.
    let rimGrad = colorGradient([
        (0.0,  0.30, 0.20, 0.13, 0.0),
        (0.85, 0.32, 0.21, 0.14, 0.0),
        (0.92, 0.52, 0.34, 0.22, 0.88),  // warm brown thin band (outer ~14%)
        (1.0,  0.60, 0.40, 0.26, 1.0),   // #9A6642-ish at very edge
    ])
    ctx.drawRadialGradient(rimGrad, startCenter: .zero, startRadius: 0,
                           endCenter: .zero, endRadius: CGFloat(bw * 0.5),
                           options: [])
    ctx.restoreGState()
    // 4. Darken the TOP portion of the rim (upper-lid shadow) so the warm brown
    //    is strongest at the bottom and fades toward the top.
    let topDark = colorGradient([
        (0.0, 0.045, 0.036, 0.058, 0.0),   // bottom: no darkening
        (0.45, 0.045, 0.036, 0.058, 0.10),
        (0.80, 0.040, 0.030, 0.052, 0.70),
        (1.0, 0.035, 0.026, 0.048, 0.92),  // top: darkest
    ])
    ctx.drawLinearGradient(topDark,
                           start: pt(bb.midX, bb.minY),
                           end: pt(bb.midX, bb.maxY),
                           options: [])
    // 5. Subtle lighter reflection band in the lower third (cool sheen).
    let refl = colorGradient([
        (0.0, 0.42, 0.50, 0.64, 0.26),
        (0.30, 0.28, 0.34, 0.48, 0.07),
        (0.55, 0.20, 0.24, 0.34, 0.0),
        (1.0, 0.20, 0.24, 0.34, 0.0),
    ])
    ctx.drawLinearGradient(refl,
                           start: pt(bb.midX, bb.minY),
                           end: pt(bb.midX, bb.maxY),
                           options: [])
    _ = radMax
    ctx.restoreGState()
    _ = rng
}

// =====================================================================
// MARK: - Pupils (NON-TINTED near-black)
// =====================================================================

enum PupilStyle { case round, vertical, star }

func drawPupil(_ c: Canvas, _ rng: inout SplitMix64, style: PupilStyle) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let cx = W/2, cy = H/2
    setRGBA(ctx, 0.03, 0.03, 0.05, 1.0)
    ctx.beginPath()
    switch style {
    case .round:
        ctx.addEllipse(in: CGRect(x: W*0.06, y: H*0.06, width: W*0.88, height: H*0.88))
        ctx.fillPath()
    case .vertical:
        ctx.addEllipse(in: CGRect(x: W*0.22, y: H*0.05, width: W*0.56, height: H*0.90))
        ctx.fillPath()
    case .star:
        star(ctx, cx: cx, cy: cy, r: W*0.46, points: 5, inner: 0.45)
        ctx.fillPath()
    }
    _ = rng
}

// =====================================================================
// MARK: - Catchlight (two white catchlights)
// =====================================================================

func drawCatchlight(_ c: Canvas, _ rng: inout SplitMix64) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    // Large upper-left catchlight
    let g1 = grayGradient([(0.0, 1.0, 1.0), (0.6, 1.0, 0.95), (1.0, 1.0, 0.0)])
    ctx.drawRadialGradient(g1, startCenter: pt(W*0.36, H*0.66), startRadius: 0,
                           endCenter: pt(W*0.36, H*0.66), endRadius: W*0.22, options: [])
    // Small lower-right catchlight
    let g2 = grayGradient([(0.0, 1.0, 1.0), (0.6, 1.0, 0.9), (1.0, 1.0, 0.0)])
    ctx.drawRadialGradient(g2, startCenter: pt(W*0.64, H*0.34), startRadius: 0,
                           endCenter: pt(W*0.64, H*0.34), endRadius: W*0.11, options: [])
    _ = rng
}

// =====================================================================
// MARK: - Shadow (soft elliptical contact shadow, black low alpha)
// =====================================================================

func drawShadow(_ c: Canvas, _ rng: inout SplitMix64) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    ctx.saveGState()
    // Scale CTM so a circular radial becomes a wide ellipse matching the canvas.
    ctx.translateBy(x: CGFloat(W/2), y: CGFloat(H/2))
    ctx.scaleBy(x: CGFloat(W/H), y: 1.0)
    let grad = colorGradient([
        (0.0, 0.0, 0.0, 0.0, 0.35),
        (0.5, 0.0, 0.0, 0.0, 0.22),
        (0.85, 0.0, 0.0, 0.0, 0.05),
        (1.0, 0.0, 0.0, 0.0, 0.0),
    ])
    ctx.drawRadialGradient(grad, startCenter: .zero, startRadius: 0,
                           endCenter: .zero, endRadius: CGFloat(H*0.5),
                           options: [])
    ctx.restoreGState()
    _ = rng
}

print("generate.swift eyes/pupils/catchlight/shadow loaded.")

// =====================================================================
// MARK: - Head fur fringe overlays
// =====================================================================

enum HeadStyle { case generic, smooth, fluffy, spiky }

// Render a COMPLETE head as ONE continuous plush surface (union mask + alpha-only
// feather + single-pass global shading), identical pipeline to head_base. The
// only difference between styles is the edge lobes UNIONed onto the shared inner
// silhouette:
//   .generic : head_base look (subtle edge lobes)
//   .smooth  : small tight lobes (~= head_base)
//   .fluffy  : larger, more numerous cloudy lobes reaching further out
//   .spiky   : fewer, elongated, softly-pointed locks (rounded tips)
// Same center (W/2, H*0.49) and same inner superellipse silhouette for all.
func drawHead(_ c: Canvas, _ rng: inout SplitMix64, style: HeadStyle, fluff: Double) {
    let W = Double(c.w), H = Double(c.h)
    // Reserve room for the widest style's edge lobes + feather + margin so the
    // shape (including fluffy lobes) fits with a transparent border ring.
    let feather = 8.0
    // Max outward reach across all styles (fluffy is the largest). Keep the
    // inner silhouette IDENTICAL regardless of style by using the same envelope.
    let maxLobeReach = 26.0 * 1.6 * fluff        // fluffy lobeR*elong worst case
    let margin = maxLobeReach + feather + 4.0 + W*0.045
    let bx = min(W*0.44, W/2 - margin)
    let by = min(H*0.43, H/2 - margin)
    // Shared inner silhouette (same as the original head_base superellipse).
    let boundary = superellipseBoundary(cx: W/2, cy: H*0.49, rx: bx, ry: by,
                                        exponent: 2.4, points: 360,
                                        cheekBulge: 0.10, cheekY: -0.28,
                                        topFlatten: 0.06)
    let centroid = centroidOf(boundary)
    let bbox = cgPath(boundary).boundingBox
    // IDENTICAL shading contract to head_base.
    let shade = plushShade(bbox: bbox, baseGray: 0.86, litGray: 1.0, shadeGray: 0.72)
    let safe = CGRect(x: 2, y: 2, width: W - 4, height: H - 4)

    // Style-specific edge lobes. All sit slightly INSIDE the boundary and
    // elongate outward (outwardBias small so the interior stays a solid,
    // continuous surface with no inner contour — the lobes only shape the edge).
    let (lobeR, elong, spacing, bias): (Double, Double, Double, Double)
    switch style {
    case .generic: (lobeR, elong, spacing, bias) = (18, 1.15, 20, 0.0)
    case .smooth:  (lobeR, elong, spacing, bias) = (14, 1.12, 16, 0.10)
    case .fluffy:  (lobeR, elong, spacing, bias) = (24, 1.30, 15, 0.35)
    case .spiky:   (lobeR, elong, spacing, bias) = (20, 1.75, 26, 0.30)
    }
    var lobes: [PlushLobe] = []
    var r1 = rng
    lobes += buildEdgeLobes(&r1, boundary: boundary, centroid: centroid,
                            lobeR: lobeR * fluff, lobeElong: elong,
                            spacing: spacing, outwardBias: bias, bounds: safe)
    if style == .fluffy {
        // second, denser cloudy pass for the fuller look
        var r2 = rng
        lobes += buildEdgeLobes(&r2, boundary: boundary, centroid: centroid,
                                lobeR: lobeR * 0.72 * fluff, lobeElong: elong,
                                spacing: spacing * 1.1, outwardBias: bias, bounds: safe)
    }

    // ONE continuous surface (core silhouette ∪ edge lobes), single-pass global
    // shading, alpha-only outer feather. No overlay, no inward fade, no seam.
    let surfaceAlpha = compositePlushSurface(c, boundary: boundary, lobes: lobes,
                                             feather: feather, shade: shade,
                                             volumeMod: true)
    // Faint interior strands (alpha-only) for the generic/fur heads (not the
    // low-detail fallback which passes fluff 0.7 but still fine).
    drawSurfaceStrands(c, &rng, alpha: surfaceAlpha, bbox: bbox, centroid: centroid,
                       count: Int(280 * fluff), lenMin: 8, lenMax: 18,
                       shade: shade, strandAlpha: 0.04)
}

// =====================================================================
// MARK: - Ears (left only, with darker inner region)
// =====================================================================

enum EarStyle { case pointed, rounded, long, floppy }

func drawEar(_ c: Canvas, _ rng: inout SplitMix64, style: EarStyle) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let cx = W * 0.5
    // Reserve room for edge fur lobes + feather + margin so the WHOLE ear
    // (including the top tip tuft) fits with a transparent border ring. We do
    // NOT clamp the tip to a rect: instead we build the ear at a natural size
    // and then uniformly SCALE + INSET it so its bounding box sits inside the
    // safe area. This keeps the tip a soft rounded silhouette (never a straight
    // horizontal cut).
    let lobeReach = 12.0        // outward reach of edge lobes (lobeR*elong-ish)
    let feather = 6.0
    let margin = lobeReach + feather + 6.0

    // Ear profile parameters (natural, in normalized 0..1 canvas fractions
    // BEFORE fit-scaling). tipXr biases the tip sideways; tipYr the height;
    // baseWr is the WIDE flat-base half-width envelope; tipWr the (small) cap
    // half-width near the tip; `shape` controls the taper curvature (>1 =
    // convex teardrop with continuously curving sides — never a vertical wall).
    // For every style the flat BASE is the WIDEST part of the silhouette
    // (baseWr > tipWr) so that, after the vertical flip, the widest opaque row
    // sits at the BOTTOM of the image (base) and the narrow TIP at the TOP —
    // matching the orientation self-check. The half-width taper is a single
    // smooth convex curve from base to cap (no constant-width mid-section), so
    // BOTH sides read as a curved taper (no straight vertical cut) — guarded by
    // the extended straight-clip check on the ear LEFT/RIGHT sides.
    let (tipXr, tipYr, baseWr, tipWr, shape): (Double, Double, Double, Double, Double)
    switch style {
    case .pointed:  (tipXr, tipYr, baseWr, tipWr, shape) = (0.03, 0.92, 0.44, 0.055, 1.55)
    case .rounded:  (tipXr, tipYr, baseWr, tipWr, shape) = (0.0,  0.82, 0.60, 0.16,  1.35)
    case .long:     (tipXr, tipYr, baseWr, tipWr, shape) = (0.02, 0.96, 0.38, 0.05,  1.70)
    case .floppy:   (tipXr, tipYr, baseWr, tipWr, shape) = (-0.30, 0.74, 0.52, 0.13,  1.45)
    }

    // Build the ear outline in a NATURAL local frame (base at y=0, growing up),
    // then measure its bbox and uniformly scale/translate it to fit the safe
    // rect. The tip is a rounded cap, so the extreme touches the top over only a
    // few pixels — satisfying the no-straight-clip rule.
    let steps = 120
    let baseW0 = baseWr * W
    let height0 = tipYr * H
    let tipDX  = tipXr * W          // sideways bias of the tip
    let tipR   = max(8.0, tipWr * W)          // rounded-cap radius (small)

    // Half-width profile as a function of height fraction u in [0,1]:
    //   u=0  -> baseW0/2   (wide flat base — widest row)
    //   u=1  -> tipR       (narrow rounded cap)
    // A single CONVEX taper: hw(u) = tipR + (baseHW - tipR) * (1-u)^shape.
    // Its slope is strictly negative for all u in (0,1) (never flat), so the
    // silhouette sides are a smooth continuous curve with NO vertical wall.
    // The cap (top tipR band) is a semicircle of radius tipR that blends onto
    // hw(1)=tipR. The spine biases sideways toward tipDX (so floppy bends out).
    let baseHW = baseW0 * 0.5
    func spineX(_ u: Double) -> Double {
        // base centered at 0, drifting toward tipDX near the top.
        return tipDX * smoothstep(0.20, 1.0, u)
    }
    func halfWidth(_ u: Double) -> Double {
        let uu = clamp(u)
        return tipR + (baseHW - tipR) * pow(1.0 - uu, shape)
    }
    // The straight sides run from u=0 up to where they meet the cap. The cap
    // occupies the top tipR of height. Sides go up to yCapBase = height0 - tipR.
    let yCapBase = height0 - tipR
    // FLOPPY droop: for the floppy style the tip flops OUTWARD (leftward, since
    // these are LEFT ears — driven by the negative tipXr in spineX) AND slightly
    // DOWN. `spineDrop(u)` lowers the local height of the upper portion (u near 1)
    // so the tip curls back down; it is zero for all other styles (tipDropAmt=0).
    let tipDropAmt: Double = (style == .floppy) ? (0.16 * height0) : 0.0
    func spineDrop(_ u: Double) -> Double {
        // 0 below u=0.45, ramping to full droop at the tip.
        return tipDropAmt * smoothstep(0.45, 1.0, u)
    }
    // Left side going UP, then the cap over the top, then right side going DOWN.
    var left: [CGPoint] = []
    var right: [CGPoint] = []
    let sideSteps = steps
    for i in 0...sideSteps {
        let yy = Double(i)/Double(sideSteps) * yCapBase
        let u = yy / max(1.0, height0)
        let hw = halfWidth(u)
        let sx = spineX(u)
        let dy = spineDrop(u)
        left.append(pt(sx - hw, yy - dy))
        right.append(pt(sx + hw, yy - dy))
    }
    // Cap: semicircle (over the top) from the left side's top point, over the
    // apex, to the right side's top point. Center at (spineX(top), yCapBase).
    let capU = yCapBase / max(1.0, height0)
    let capCX = spineX(capU)
    let capCY = yCapBase - spineDrop(capU)
    var cap: [CGPoint] = []
    let capSteps = 60
    // Sweep from angle pi (left) down to 0 (right) THROUGH pi/2 (apex, top).
    for i in 0...capSteps {
        let t = Double(i)/Double(capSteps)
        let ang = Double.pi * (1.0 - t)     // pi -> 0, passing through pi/2
        cap.append(pt(capCX + cos(ang)*tipR, capCY + sin(ang)*tipR))
    }
    // Assemble: up the left side, over the cap, down the right side (reversed).
    var local = left + cap + right.reversed()

    // Measure local bbox and fit into the safe rect uniformly.
    var lminX = Double.greatestFiniteMagnitude, lmaxX = -Double.greatestFiniteMagnitude
    var lminY = Double.greatestFiniteMagnitude, lmaxY = -Double.greatestFiniteMagnitude
    for p in local {
        lminX = min(lminX, Double(p.x)); lmaxX = max(lmaxX, Double(p.x))
        lminY = min(lminY, Double(p.y)); lmaxY = max(lmaxY, Double(p.y))
    }
    let localW = max(1.0, lmaxX - lminX), localH = max(1.0, lmaxY - lminY)
    let availW = W - 2*margin, availH = H - 2*margin
    let fit = min(availW / localW, availH / localH, 1.0)
    // Center horizontally on cx.
    let drawW = localW * fit, drawH = localH * fit
    let offX = cx - (Double(lminX) + localW*0.5) * fit
    // ORIENTATION: the local frame is built base-at-y=0 growing UP (tip at high
    // local y). In the SAVED PNG viewed normally (row 0 = top), a LOW draw-y maps
    // to the TOP of the image. So to make the TIP appear at the TOP and the flat
    // BASE at the BOTTOM, we FLIP local y: tip (high local y) -> low draw-y (top),
    // base (local y=0) -> high draw-y (bottom). This is the whole fix for the
    // "ears upside down" bug — everything downstream derives from `fpts`.
    let offY = margin
    let fpts: [CGPoint] = local.map {
        pt(Double($0.x)*fit + offX, (lmaxY - Double($0.y))*fit + offY)
    }
    _ = drawW; _ = drawH
    local = []

    let bbox = cgPath(fpts).boundingBox
    // After the vertical flip: the ear TIP is at the TOP of the image, which in
    // draw-y is the SMALLER y (bbox.minY); the flat BASE is at the BOTTOM
    // (bbox.maxY). Name these by MEANING so downstream feature placement reads
    // correctly in display orientation.
    let tipY  = Double(bbox.minY)      // display TOP  (soft rounded tip)
    let baseY = Double(bbox.maxY)      // display BOTTOM (flat/feathered base)
    let apexX = capCX*fit + offX
    // Representative ear width (fitted full base width) for sizing the inner-ear
    // region. The inner region is kept well inside via an eroded mask + a
    // gradient that fades to alpha 0 before its edge (its own feather).
    let midW = baseW0 * fit
    let centroid = pt(bbox.midX, lerp(baseY, tipY, 0.5))
    let shade = plushShade(bbox: bbox, baseGray: 0.90, litGray: 1.0, shadeGray: 0.84)
    let safe = CGRect(x: 2, y: 2, width: W - 4, height: H - 4)

    // ONE continuous surface: ear silhouette ∪ outer-edge fur lobes, shaded
    // globally in a single pass with alpha-only outer feather (no seam, no halo).
    // Edge lobes only on the upper/outer boundary (the TIP and SIDES) so the flat
    // attachment base stays clean. In display orientation the tip is at the TOP
    // (smaller draw-y) and the base at the BOTTOM (larger draw-y): keep only the
    // boundary points that are ABOVE the bottom 12% band (i.e. draw-y strictly
    // less than the base band).
    let baseBandY = baseY - (baseY - tipY) * 0.12
    let outerBoundary = fpts.filter { Double($0.y) < baseBandY }
    var sr = rng
    let earLobes = buildEdgeLobes(&sr, boundary: outerBoundary.isEmpty ? fpts : outerBoundary,
                                  centroid: centroid, lobeR: 7, lobeElong: 1.25,
                                  spacing: 13, outwardBias: 0.25, bounds: safe)
    let earAlpha = compositePlushSurface(c, boundary: fpts, lobes: earLobes, feather: feather, shade: shade)

    // Inner ear: soft darker gradient (reads as soft pink after tint). Clip it to
    // an ERODED opaque mask of the ear surface so the darker tone physically
    // cannot touch any semi-transparent (feathered) pixel → no dark halo.
    // Inner ear: soft darker gradient (reads as soft pink after tint). Clip it to
    // an ERODED opaque mask of the ear surface so the darker tone physically
    // cannot touch any semi-transparent (feathered) pixel → no dark halo. The
    // region is kept SMALL and centered in the ear body, with its OWN feathered
    // edge (the gradient fades to alpha 0 before its end radius) so it stays a
    // soft island strictly inside the ear — never a straight cut.
    guard let innerMask = erodedOpaqueMask(earAlpha, c.w, c.h, erode: 10) else { _ = rng; return }
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: W, height: H), mask: innerMask)
    let innerCx = lerp(cx, apexX, 0.30)
    let innerCy = lerp(baseY, tipY, 0.50)
    let innerRx = midW * 0.24, innerRy = abs(tipY - baseY) * 0.28
    let innerGrad = grayGradient([
        (0.0, 0.62, 0.90),
        (0.45, 0.70, 0.62),
        (0.80, 0.82, 0.20),
        (1.0, 0.85, 0.0),
    ])
    ctx.drawRadialGradient(innerGrad, startCenter: pt(innerCx, innerCy), startRadius: 0,
                           endCenter: pt(innerCx, innerCy), endRadius: max(innerRx, innerRy),
                           options: [])
    ctx.restoreGState()
}

// =====================================================================
// MARK: - Tails (very fluffy, base at bottom-left)
// =====================================================================

enum TailStyle { case short, long, curled, plume }

func drawTail(_ c: Canvas, _ rng: inout SplitMix64, style: TailStyle) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let margin = 28.0
    // Spine in normalized coords. base near bottom-left, sweeping per style.
    let spineN: [(Double, Double)]
    switch style {
    case .short:
        // round puff — short compact spine
        spineN = [(0.42, 0.28), (0.50, 0.46), (0.56, 0.62)]
    case .long:
        // S-sweep
        spineN = [(0.32, 0.16), (0.40, 0.36), (0.56, 0.52), (0.66, 0.72), (0.58, 0.88)]
    case .curled:
        // Single continuous C-curl: ONE smooth circular spine arc of ~240°
        // (open C) opening toward the body (left). Sampled densely (many points)
        // so the Catmull-Rom spine is smooth with no lumps — the tube then reads
        // as one continuous thick fluffy coil (never separated petals/blobs).
        var arc: [(Double, Double)] = []
        let cxN = 0.54, cyN = 0.50, rad = 0.27
        // Sweep 240° with the OPENING centered on the LEFT (toward the body): the
        // arc covers the right/top/bottom (from -120° up through 0° to +120°),
        // leaving the left ~120° open. Sampled densely so the Catmull-Rom spine
        // is smooth — the tube reads as one continuous thick fluffy coil.
        let a0 = -120.0 * .pi/180.0
        let a1 =  120.0 * .pi/180.0    // -120 -> +120 through 0° = 240° sweep, gap on left
        let n = 28
        for i in 0..<n {
            let t = Double(i)/Double(n-1)
            let a = a0 + (a1 - a0) * t
            arc.append((cxN + cos(a)*rad, cyN + sin(a)*rad))
        }
        spineN = arc
    case .plume:
        // wide fan — a bushy tail that broadens strongly toward the tip
        spineN = [(0.32, 0.16), (0.40, 0.38), (0.50, 0.58), (0.56, 0.82)]
    }
    func radiusAt(_ t: Double) -> Double {
        let m = min(W, H)
        // Fuller, bushier tails: wider bodies overall + a slightly fluffier
        // (not tapering to nothing) tip.
        switch style {
        case .plume:  return lerp(m*0.13, m*0.30, smoothstep(0, 0.85, t))   // wide fan
        case .curled: return lerp(m*0.155, m*0.085, smoothstep(0, 1, t))    // thick base -> thinner fluffy tip
        case .long:   return lerp(m*0.12, m*0.22, smoothstep(0, 0.8, t))
        case .short:  return lerp(m*0.18, m*0.24, t)
        }
    }
    let spine: [CGPoint] = spineN.map { pt($0.0 * W, $0.1 * H) }
    func spineAt(_ t: Double) -> CGPoint {
        let n = spine.count
        if n < 2 { return spine[0] }
        let seg = t * Double(n - 1)
        let i = min(Int(seg), n - 2)
        let lt = seg - Double(i)
        let p0 = spine[max(0, i-1)], p1 = spine[i], p2 = spine[i+1], p3 = spine[min(n-1, i+2)]
        func cr(_ a: Double, _ b: Double, _ cc: Double, _ d: Double, _ u: Double) -> Double {
            let u2 = u*u, u3 = u2*u
            return 0.5 * ((2*b) + (-a+cc)*u + (2*a-5*b+4*cc-d)*u2 + (-a+3*b-3*cc+d)*u3)
        }
        return pt(cr(Double(p0.x),Double(p1.x),Double(p2.x),Double(p3.x),lt),
                  cr(Double(p0.y),Double(p1.y),Double(p2.y),Double(p3.y),lt))
    }
    // Rough bbox for shading light placement.
    let bbox = CGRect(x: margin, y: margin, width: W-2*margin, height: H-2*margin)
    let shade = plushShade(bbox: bbox, baseGray: 0.86, litGray: 1.0, shadeGray: 0.74)

    // Build ONE union coverage: dense overlapping spine lobes (the plume body)
    // rasterized as opaque circles. No per-lobe feathered edges -> no halo.
    let w = c.w, h = c.h
    var cover = [Float](repeating: 0, count: w*h)
    let steps = 120
    for s in 0...steps {
        let t = Double(s)/Double(steps)
        let ctr = spineAt(t)
        let r = radiusAt(t)
        let jx = rng.range(-r*0.12, r*0.12)
        let jy = rng.range(-r*0.12, r*0.12)
        let px = Double(ctr.x) + jx, py = Double(ctr.y) + jy
        if px - r < margin-2 || px + r > W - margin+2 ||
           py - r < margin-2 || py + r > H - margin+2 { continue }
        rasterEllipseUnion(&cover, w, h, cx: px, cy: py, ra: r, rc: r, ang: 0)
    }
    // DENSE edge locks (cotton-candy scallops) placed along BOTH sides of the
    // spine, perpendicular to the spine tangent. This follows ANY spine shape
    // (C-coil, S-sweep, fan) correctly — unlike a single-center polar hull which
    // distorts a concave C. Each lock is UNIONed onto the plume; no per-lobe
    // feathered edges -> no halo. Deterministic from `rng`.
    let safe = CGRect(x: 6, y: 6, width: W - 12, height: H - 12)
    let m = min(W, H)
    func spineTangent(_ t: Double) -> (Double, Double) {
        let a = spineAt(max(0, t - 0.01)), b = spineAt(min(1, t + 0.01))
        var tx = Double(b.x - a.x), ty = Double(b.y - a.y)
        let l = hypot(tx, ty); if l > 1e-6 { tx/=l; ty/=l } else { tx = 0; ty = 1 }
        return (tx, ty)
    }
    var locks: [PlushLobe] = []
    // Number of scallops along the tail: denser = fluffier.
    let lockSteps = 46
    for s in 0...lockSteps {
        let t = Double(s)/Double(lockSteps)
        let ctr = spineAt(t)
        let r = radiusAt(t)
        let (tx, ty) = spineTangent(t)
        // outward normal on each side
        let nxL = -ty, nyL = tx
        let lobeR = r * rng.range(0.42, 0.62)
        let elong = 1.3
        for sign in [1.0, -1.0] {
            let nx = nxL * sign, ny = nyL * sign
            // place the lobe center just inside the plume edge (r - ~0.35 lobeR),
            // biased slightly outward so the scallop reads on the silhouette.
            let off = (r - lobeR*0.35) + lobeR*0.35*rng.range(0.0, 1.0)
            let cxp = Double(ctr.x) + nx*off + rng.range(-r*0.06, r*0.06)
            let cyp = Double(ctr.y) + ny*off + rng.range(-r*0.06, r*0.06)
            let ra = lobeR*elong, rc = lobeR
            let ext = max(ra, rc) + 1.0
            if cxp - ext < Double(safe.minX) || cxp + ext > Double(safe.maxX) ||
               cyp - ext < Double(safe.minY) || cyp + ext > Double(safe.maxY) { continue }
            locks.append(PlushLobe(cx: cxp, cy: cyp, ra: ra, rc: rc,
                                   ang: atan2(ny, nx), bump: rng.range(-1.0, 1.0)))
        }
    }
    _ = m
    var volume = [Float](repeating: 0, count: w*h)
    for lo in locks {
        rasterEllipseUnion(&cover, w, h, cx: lo.cx, cy: lo.cy, ra: lo.ra, rc: lo.rc, ang: lo.ang)
        // subtle ±3% lobe volume, no edge
        let sigma = max(lo.ra, lo.rc) * 0.9
        let inv2s2 = 1.0 / (2.0 * sigma * sigma)
        let ext = Int(sigma * 2.4) + 2
        let x0 = max(0, Int(lo.cx) - ext), x1 = min(w - 1, Int(lo.cx) + ext)
        let y0 = max(0, Int(lo.cy) - ext), y1 = min(h - 1, Int(lo.cy) + ext)
        if x0 > x1 || y0 > y1 { continue }
        let amp: Float = 0.03 * Float(lo.bump)  // subtle ±3% volume, no edge
        for y in y0...y1 {
            let dy = Double(y) + 0.5 - lo.cy
            for x in x0...x1 {
                let dx = Double(x) + 0.5 - lo.cx
                let g = exp(-(dx*dx + dy*dy) * inv2s2)
                volume[y*w + x] += amp * Float(g)
            }
        }
    }
    // Fluffy tip: a BROAD, gentle BRIGHTENING lift (never darkens). The sigma is
    // large so the lift barely changes across any 12px window — this keeps a
    // feathered edge pixel within 0.06 of its opaque neighbors (halo-safe).
    let tip = spineAt(1.0)
    let tr = radiusAt(1.0)
    let tipX = Double(tip.x), tipY = Double(tip.y)
    let tipSigma = tr * 2.4
    let tipInv2s2 = 1.0 / (2.0 * tipSigma * tipSigma)
    let lift: (Double, Double) -> Double = { x, y in
        let dx = x - (tipX - tr*0.2), dy = y - (tipY + tr*0.2)
        return 0.11 * exp(-(dx*dx + dy*dy) * tipInv2s2)
    }
    // Single-pass: alpha-only outer feather + global shading + volume + tip lift.
    _ = compositeCoverageSurface(c, coverage: cover, feather: 8,
                                 shade: shade, volume: volume, lift: lift)
    _ = ctx
}

// =====================================================================
// MARK: - Head tufts (crown fur)
// =====================================================================

enum TuftStyle { case curl, split, windswept }

func drawHeadTuft(_ c: Canvas, _ rng: inout SplitMix64, style: TuftStyle) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let margin = 14.0
    let baseY = margin + 6
    let usableH = H - 2*margin

    // ORIENTATION: this function builds the tuft with its BASE at low draw-y and
    // the locks emitting toward HIGH draw-y ("up" in the author's y-up mental
    // model). In the SAVED PNG that placed the base at the TOP and the tips at
    // the BOTTOM (crown fur pointing DOWN — upside down). Flip the whole surface
    // vertically here so the BASE sits at the BOTTOM of the image as viewed and
    // the lock TIPS point UP. This makes the widest (base) row land in the bottom
    // half, matching the orientation self-check. All drawing below goes through
    // `ctx`, so a single CTM flip re-orients everything (surfaces + strands).
    ctx.saveGState()
    ctx.translateBy(x: 0, y: CGFloat(H))
    ctx.scaleBy(x: 1, y: -1)
    defer { ctx.restoreGState() }

    // Each lock is a strongly TAPERED curved wisp: WIDE at the base (~40-60px at
    // 1x), narrowing to a soft point, varying lengths (longest in the middle),
    // fanned across a spread of ~50-80 degrees, overlapping, feathered, with a
    // few grouped fine strands at each tip. The base feathers to transparent so
    // it sinks into the head.
    //   angDeg  : emission angle from vertical (deg; +right, -left)
    //   lenF    : length fraction (longest in the middle)
    //   baseW   : base width in px at 1x (40-60 typical)
    //   curl    : sideways bow of the tip (+ curls right)
    struct Lock { var dx: Double; var angDeg: Double; var lenF: Double; var baseW: Double; var curl: Double }
    let locks: [Lock]
    switch style {
    case .curl:
        // tips all curl to one side (right); fanned right-of-center
        locks = [
            Lock(dx: -0.16, angDeg: -10, lenF: 0.58, baseW: 40, curl:  0.40),
            Lock(dx: -0.05, angDeg:  -2, lenF: 0.74, baseW: 48, curl:  0.52),
            Lock(dx:  0.06, angDeg:   9, lenF: 0.68, baseW: 44, curl:  0.62),
            Lock(dx:  0.17, angDeg:  19, lenF: 0.52, baseW: 38, curl:  0.70),
        ]
    case .split:
        // two groups parting from center (left group sweeps left, right sweeps right)
        locks = [
            Lock(dx: -0.19, angDeg: -25, lenF: 0.58, baseW: 40, curl: -0.42),
            Lock(dx: -0.08, angDeg: -12, lenF: 0.74, baseW: 46, curl: -0.22),
            Lock(dx:  0.08, angDeg:  12, lenF: 0.74, baseW: 46, curl:  0.22),
            Lock(dx:  0.19, angDeg:  25, lenF: 0.58, baseW: 40, curl:  0.42),
        ]
    case .windswept:
        // all sweeping one direction (right), progressively stronger
        locks = [
            Lock(dx: -0.18, angDeg:   8, lenF: 0.54, baseW: 40, curl: 0.34),
            Lock(dx: -0.06, angDeg:  17, lenF: 0.74, baseW: 48, curl: 0.48),
            Lock(dx:  0.06, angDeg:  26, lenF: 0.66, baseW: 44, curl: 0.60),
            Lock(dx:  0.18, angDeg:  34, lenF: 0.50, baseW: 38, curl: 0.70),
        ]
    }

    // Clamp a point into the safe rect (keeps geometry inside the canvas so the
    // 2px border ring stays transparent).
    let safeMinX = margin, safeMaxX = W - margin
    let safeMinY = margin, safeMaxY = H - margin
    func clampPt(_ p: CGPoint) -> CGPoint {
        pt(min(max(Double(p.x), safeMinX), safeMaxX),
           min(max(Double(p.y), safeMinY), safeMaxY))
    }

    let safe = CGRect(x: 2, y: 2, width: W - 4, height: H - 4)
    // Draw longest locks first (behind) so shorter ones overlap on top.
    let order = locks.indices.sorted { locks[$0].lenF > locks[$1].lenF }
    for li in order {
        let lk = locks[li]
        let bx = W*0.5 + lk.dx * W
        let len = lk.lenF * usableH
        let ang = lk.angDeg * .pi / 180.0
        // emission direction (mostly up, tilted by ang). CG y is up.
        let dirX = sin(ang), dirY = cos(ang)
        // perpendicular
        let perpX = dirY, perpY = -dirX
        // centerline as a quadratic bowed sideways by curl
        let tipBaseX = bx + dirX * len
        let tipBaseY = baseY + dirY * len
        let bow = lk.curl * lk.baseW * 1.2
        let tipX = tipBaseX + perpX * bow
        let tipY = min(tipBaseY + perpY * bow, H - margin)
        let ctrlX = bx + dirX * len * 0.5 + perpX * bow * 0.55
        let ctrlY = baseY + dirY * len * 0.5 + perpY * bow * 0.55
        func center(_ t: Double) -> CGPoint {
            let x = (1-t)*(1-t)*bx + 2*(1-t)*t*ctrlX + t*t*tipX
            let y = (1-t)*(1-t)*baseY + 2*(1-t)*t*ctrlY + t*t*tipY
            return pt(x, y)
        }
        // Strongly tapered half-width: near-full at the base, tapering to a soft
        // point at the tip. widest slightly above the base.
        func halfW(_ t: Double) -> Double {
            // profile: 1.0 near base (t~0.12), smoothly -> ~0.02 at tip.
            let rise = smoothstep(0.0, 0.14, t)          // ramp up from the very root
            let taper = pow(1.0 - t, 1.35)               // strong taper to a point
            return (lk.baseW * 0.5) * clamp(rise * 0.35 + taper, 0.02, 1.0)
        }
        let n = 48
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...n {
            let t = Double(i)/Double(n)
            let c0 = center(t)
            let c1 = center(min(1.0, t + 0.02))
            var tx = Double(c1.x - c0.x), ty = Double(c1.y - c0.y)
            let l = hypot(tx, ty); if l > 1e-6 { tx/=l; ty/=l }
            let nx = -ty, ny = tx
            let hw = halfW(t)
            left.append(clampPt(pt(Double(c0.x) + nx*hw, Double(c0.y) + ny*hw)))
            right.append(clampPt(pt(Double(c0.x) - nx*hw, Double(c0.y) - ny*hw)))
        }
        let boundary = left + right.reversed()
        let path = cgPath(boundary)
        let bb = path.boundingBox
        let shade = plushShade(bbox: bb, baseGray: 0.90, litGray: 1.0, shadeGray: 0.80)
        // Single continuous surface, global shading, alpha-only feather (no halo).
        _ = compositePlushSurface(c, boundary: boundary, lobes: [], feather: 4,
                                  shade: shade, volumeMod: false)
        // Base feathers to transparent into the head (destinationOut ramp). This
        // reduces ALPHA only; the surviving pixels keep their surface luminance.
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        ctx.setBlendMode(.destinationOut)
        let fade = grayGradient([(0.0, 0.0, 1.0), (0.20, 0.0, 0.0), (1.0, 0.0, 0.0)])
        ctx.drawLinearGradient(fade, start: pt(bb.midX, baseY - 4), end: pt(bb.midX, baseY + len*0.30),
                               options: [])
        ctx.setBlendMode(.normal)
        ctx.restoreGState()
        // A few grouped fine strands at the tip (frayed wisp).
        let tip = center(1.0)
        var sr = rng
        let strandCount = 5 + Int(sr.range(0, 3))
        ctx.setLineCap(.round)
        for _ in 0..<strandCount {
            let jit = sr.range(-0.22, 0.22)
            let ca = cos(jit), sa = sin(jit)
            let sdx = dirX * ca - dirY * sa
            let sdy = dirX * sa + dirY * ca
            var slen = lk.baseW * sr.range(0.35, 0.75)
            let rootX = Double(tip.x) - sdx * lk.baseW * 0.12
            let rootY = Double(tip.y) - sdy * lk.baseW * 0.12
            var ex = rootX + sdx * slen, ey = rootY + sdy * slen
            if ex < Double(safe.minX)+1 || ex > Double(safe.maxX)-1 ||
               ey < Double(safe.minY)+1 || ey > Double(safe.maxY)-1 {
                slen *= 0.4
                ex = rootX + sdx * slen; ey = rootY + sdy * slen
                if ex < Double(safe.minX)+1 || ex > Double(safe.maxX)-1 ||
                   ey < Double(safe.minY)+1 || ey > Double(safe.maxY)-1 { continue }
            }
            let pxn = -sdy, pyn = sdx
            let w = 2.0
            let midX = (rootX+ex)*0.5, midY = (rootY+ey)*0.5
            ctx.beginPath()
            ctx.move(to: pt(rootX + pxn*w*0.5, rootY + pyn*w*0.5))
            ctx.addQuadCurve(to: pt(ex, ey), control: pt(midX + pxn*w*0.3, midY + pyn*w*0.3))
            ctx.addQuadCurve(to: pt(rootX - pxn*w*0.5, rootY - pyn*w*0.5), control: pt(midX - pxn*w*0.3, midY - pyn*w*0.3))
            ctx.closePath()
            setGray(ctx, shade(rootX, rootY), clamp(sr.range(0.5, 0.82)))
            ctx.fillPath()
        }
    }
}

// =====================================================================
// MARK: - Chest tufts (fluffy ruff)
// =====================================================================

func drawChestTuft(_ c: Canvas, _ rng: inout SplitMix64, layers: Int, spread: Double) {
    let ctx = c.ctx
    let W = Double(c.w), H = Double(c.h)
    let margin = 12.0
    // ORIENTATION: the bib is built widest toward HIGH draw-y (topY) tapering to
    // a point at LOW draw-y. Direct fills put HIGH draw-y near the TOP of the
    // image as viewed, so the widest band landed in the TOP third. Flip the
    // surface vertically so the widest band sits in the BOTTOM half (matching the
    // orientation self-check); the shape is a near-symmetric rounded cloud so the
    // flip only re-seats the wide band low.
    ctx.saveGState()
    ctx.translateBy(x: 0, y: CGFloat(H))
    ctx.scaleBy(x: 1, y: -1)
    defer { ctx.restoreGState() }
    // A fluffy BIB: a rounded downward-pointing cloud built from overlapping
    // soft lobes. BOTH the top and bottom edges feather to transparent so it
    // blends into the neck (above) and the belly (below). Near-white luminance.
    let cx = W*0.5
    let halfW = min(W*0.5 - margin, W * spread * 0.5)
    let topY = H - margin                      // top of bib (feathers up into neck)
    let botY = margin                          // bottom point (feathers into belly)
    let span = topY - botY

    // Build overlapping lobe rows following a downward-pointing bib outline:
    // wide at top, tapering to a rounded point at the bottom. Each lobe is a
    // soft feathered ellipse; luminance top-left lighter.
    let shade = plushShade(bbox: CGRect(x: cx-halfW, y: botY, width: halfW*2, height: span),
                           baseGray: 0.95, litGray: 1.0, shadeGray: 0.90)
    // rows from bottom (narrow) to top (wide)
    let rows = max(3, layers + 2)
    for row in 0..<rows {
        let rt = Double(row) / Double(rows - 1)          // 0 bottom .. 1 top
        // bib width profile: narrow at bottom, wide at top, rounded
        let rowW = halfW * (0.25 + 0.75 * pow(rt, 0.7))
        let rowY = botY + span * (0.10 + 0.82 * rt)
        // vertical alpha fade: transparent at very top and very bottom
        let topFade = smoothstep(1.0, 0.72, rt)          // fade near top
        let botFade = smoothstep(0.0, 0.16, rt)          // fade near bottom
        let rowAlpha = clamp(topFade * botFade) * 0.95 + 0.05
        // number of lobes across this row
        let lobesAcross = max(2, Int(rowW / (W*0.09)) + 1 + layers)
        for k in 0..<lobesAcross {
            let kt = lobesAcross == 1 ? 0.5 : Double(k)/Double(lobesAcross - 1)
            let lx = cx - rowW + 2*rowW*kt + rng.range(-4, 4)
            let ly = rowY + rng.range(-6, 6)
            let lr = (W*0.055 + halfW*0.10) * rng.range(0.85, 1.15)
            // feathered lobe rings
            let rr = 4
            for ring in stride(from: rr, through: 0, by: -1) {
                let frac = Double(ring)/Double(rr)
                let sc = 1.0 + frac*0.5
                let a = (ring == 0 ? rowAlpha : rowAlpha * pow(1.0 - frac, 1.5))
                let rad = lr * sc
                if lx - rad < margin || lx + rad > W - margin ||
                   ly - rad < margin || ly + rad > H - margin { continue }
                setGray(ctx, shade(lx, ly), clamp(a))
                ctx.fillEllipse(in: CGRect(x: lx-rad, y: ly-rad*1.05, width: rad*2, height: rad*2.1))
            }
        }
    }
    _ = spread
}

// =====================================================================
// MARK: - Tint helpers for previews
// =====================================================================

struct RGB { var r: Double; var g: Double; var b: Double }
func hexRGB(_ hex: UInt32) -> RGB {
    RGB(r: Double((hex >> 16) & 0xff)/255.0,
        g: Double((hex >> 8) & 0xff)/255.0,
        b: Double(hex & 0xff)/255.0)
}

// Multiply-tint a CGImage by an RGB color (simulates SKSpriteNode color blend factor 1.0).
func tinted(_ img: CGImage, _ color: RGB) -> CGImage {
    let w = img.width, h = img.height
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setBlendMode(.multiply)
    ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: h), mask: img)
    ctx.setFillColor(red: CGFloat(color.r), green: CGFloat(color.g), blue: CGFloat(color.b), alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

// =====================================================================
// MARK: - Main driver
// =====================================================================

let fm = FileManager.default
let repoRoot = URL(fileURLWithPath: fm.currentDirectoryPath)
let phoneDir = repoRoot.appendingPathComponent("app", isDirectory: true)
let watchDir = repoRoot.appendingPathComponent("LumiWatch Watch App", isDirectory: true)
let previewDir2 = repoRoot.appendingPathComponent("Tools/TextureGenerator/preview", isDirectory: true)

let phoneAtlas = phoneDir.appendingPathComponent("LumiPet.atlas", isDirectory: true)
let watchAtlas = watchDir.appendingPathComponent("LumiPetWatch.atlas", isDirectory: true)

// Old (pre-.atlas) output directories that must be removed.
let oldPhoneDir = phoneDir.appendingPathComponent("LumiTextures", isDirectory: true)
let oldWatchDir = watchDir.appendingPathComponent("LumiTextures", isDirectory: true)

func clearAndMake(_ dir: URL) {
    if fm.fileExists(atPath: dir.path) { try? fm.removeItem(at: dir) }
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
}
// Remove legacy folders (untracked generated output).
if fm.fileExists(atPath: oldPhoneDir.path) { try? fm.removeItem(at: oldPhoneDir) }
if fm.fileExists(atPath: oldWatchDir.path) { try? fm.removeItem(at: oldWatchDir) }
clearAndMake(phoneAtlas)
clearAndMake(watchAtlas)
try? fm.createDirectory(at: previewDir2, withIntermediateDirectories: true)

let TINTABLE: Set<String> = [
    "body_round","body_compact","body_pear","abdomen_soft","paws_round","head_base",
    "fur_smooth","fur_fluffy","fur_spiky",
    "pattern_spots","pattern_stripes","pattern_socks","pattern_gradient","pattern_mask",
    "eyelid","iris_base",
    "ear_pointed","ear_rounded","ear_long","ear_floppy",
    "tail_short","tail_long","tail_curled","tail_plume",
    "headtuft_curl","headtuft_split","headtuft_windswept",
    "chesttuft_small","chesttuft_layered","chesttuft_cloud",
    "muzzle_small","muzzle_round","muzzle_pronounced",
    "nose_dot","nose_triangle","nose_heart",
    "cheek_blush","cheek_freckles","cheek_glow",
    "magic_glow","magic_sparkles","magic_orbiting_light",
    "fallback_body","fallback_head","fallback_ear","fallback_tail","fallback_paws",
]

func scaledImage(_ img: CGImage, toW: Int, toH: Int) -> CGImage {
    if img.width == toW && img.height == toH { return img }
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: toW, height: toH, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: toW, height: toH))
    return ctx.makeImage()!
}

var designImages: [String: CGImage] = [:]
for spec in TEXTURES {
    let img = drawTexture(spec)
    designImages[spec.name] = img
    savePNG(img, to: phoneAtlas.appendingPathComponent("\(spec.name).png"))
    let ww = Int((Double(spec.w) * 0.5).rounded())
    let wh = Int((Double(spec.h) * 0.5).rounded())
    savePNG(scaledImage(img, toW: ww, toH: wh), to: watchAtlas.appendingPathComponent("\(spec.name).png"))
}
print("Rendered \(TEXTURES.count) textures to phone + watch atlases.")

// ---- RigAnchors.json -------------------------------------------------
struct Anchor { let x: Double; let y: Double }
let anchors: [(String, Anchor)] = [
    ("shadow",     Anchor(x: 0.500, y: 0.128)),
    ("paws",       Anchor(x: 0.500, y: 0.160)),
    ("body",       Anchor(x: 0.500, y: 0.315)),
    ("abdomen",    Anchor(x: 0.500, y: 0.298)),
    ("chest",      Anchor(x: 0.500, y: 0.372)),
    ("tail",       Anchor(x: 0.705, y: 0.330)),
    ("head",       Anchor(x: 0.500, y: 0.647)),
    ("leftEar",    Anchor(x: 0.335, y: 0.805)),
    ("rightEar",   Anchor(x: 0.665, y: 0.805)),
    ("headTuft",   Anchor(x: 0.500, y: 0.817)),
    ("leftEye",    Anchor(x: 0.415, y: 0.617)),
    ("rightEye",   Anchor(x: 0.585, y: 0.617)),
    ("muzzle",     Anchor(x: 0.500, y: 0.542)),
    ("nose",       Anchor(x: 0.500, y: 0.567)),
    ("leftCheek",  Anchor(x: 0.372, y: 0.567)),
    ("rightCheek", Anchor(x: 0.628, y: 0.567)),
    ("magic",      Anchor(x: 0.500, y: 0.500)),
]

func writeRigAnchors(to dir: URL) {
    var s = "{\n"
    s += "  \"version\": 1,\n"
    s += "  \"canvas\": { \"width\": 1024, \"height\": 1024 },\n"
    s += "  \"anchors\": {\n"
    for (i, a) in anchors.enumerated() {
        let comma = i == anchors.count - 1 ? "" : ","
        s += String(format: "    \"%@\": { \"x\": %.3f, \"y\": %.3f }%@\n", a.0, a.1.x, a.1.y, comma)
    }
    s += "  },\n"
    s += "  \"relativeSizes\": { \"iris\": 0.820, \"pupil\": 0.460, \"catchlight\": 0.420 },\n"
    s += "  \"headVariants\": { \"smooth\": \"fur_smooth\", \"fluffy\": \"fur_fluffy\", \"spiky\": \"fur_spiky\" },\n"
    s += "  \"textures\": {\n"
    for (i, spec) in TEXTURES.enumerated() {
        let comma = i == TEXTURES.count - 1 ? "" : ","
        s += "    \"\(spec.name)\": { \"width\": \(spec.w), \"height\": \(spec.h) }\(comma)\n"
    }
    s += "  }\n}\n"
    try? s.write(to: dir.appendingPathComponent("RigAnchors.json"), atomically: true, encoding: .utf8)
}
writeRigAnchors(to: phoneDir)
writeRigAnchors(to: watchDir)
print("Wrote RigAnchors.json to both output folders.")

print("generate.swift main driver loaded.")

// =====================================================================
// MARK: - Text drawing (CoreText) for labels
// =====================================================================

import CoreText

func drawText(_ ctx: CGContext, _ text: String, x: Double, y: Double, size: Double, gray: Double = 1.0) {
    let font = CTFontCreateWithName("Helvetica" as CFString, CGFloat(size), nil)
    let color = CGColor(red: CGFloat(gray), green: CGFloat(gray), blue: CGFloat(gray), alpha: 1.0)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorAttributeName: color,
    ]
    let astr = CFAttributedStringCreate(kCFAllocatorDefault, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(astr)
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, ctx)
}

// =====================================================================
// MARK: - Contact sheet
// =====================================================================

func buildContactSheet() {
    let lilac = hexRGB(0xD9C8F0)
    let cols = 8
    let rows = (TEXTURES.count + cols - 1) / cols
    let cell = 150
    let pad = 14
    let labelH = 16
    let W = cols * cell
    let H = rows * cell
    let c = Canvas(W, H)
    let ctx = c.ctx
    // mid-dark blue-gray background
    setRGBA(ctx, 0.16, 0.18, 0.22, 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (idx, spec) in TEXTURES.enumerated() {
        let col = idx % cols
        let row = idx / cols
        // top-left origin visually: flip row since CG y is up
        let cellX = col * cell
        let cellY = H - (row + 1) * cell
        guard let img = designImages[spec.name] else { continue }
        let display = TINTABLE.contains(spec.name) ? tinted(img, lilac) : img
        // fit into cell with padding, keep aspect
        let availW = Double(cell - pad*2)
        let availH = Double(cell - pad*2 - labelH)
        let scale = min(availW / Double(img.width), availH / Double(img.height), 1.0)
        let dw = Double(img.width) * scale
        let dh = Double(img.height) * scale
        let dx = Double(cellX) + (Double(cell) - dw)/2
        let dy = Double(cellY) + Double(labelH) + (availH - dh)/2 + Double(pad)
        ctx.draw(display, in: CGRect(x: dx, y: dy, width: dw, height: dh))
        // label at bottom of cell
        drawText(ctx, spec.name, x: Double(cellX) + 6, y: Double(cellY) + 4, size: 10, gray: 0.9)
    }
    savePNG(c.image, to: previewDir2.appendingPathComponent("contact-sheet.png"))
    // sidecar text of grid order too
    var t = "Contact sheet grid order (row-major, \(cols) cols):\n"
    for (i, s) in TEXTURES.enumerated() { t += String(format: "%2d. %@\n", i, s.name) }
    try? t.write(to: previewDir2.appendingPathComponent("contact-sheet.txt"), atomically: true, encoding: .utf8)
    print("Wrote contact-sheet.png")
}
buildContactSheet()

// Isolation preview: head_base, fur_fluffy, body_round, tail_plume each drawn
// ALONE at 1x on a dark #1F2433 background so any inner contour or dark lobe
// fringe would be obvious. Tinted with the lilac palette (as they appear).
func buildIsolate() {
    let names = ["ear_pointed", "ear_rounded", "ear_long", "ear_floppy",
                 "fur_fluffy", "tail_plume", "tail_curled", "headtuft_windswept"]
    let tint = hexRGB(0xD9C8F0)
    let pad = 40
    var cellW = 0, cellH = 0
    for n in names {
        if let s = TEXTURES.first(where: { $0.name == n }) {
            cellW = max(cellW, s.w); cellH = max(cellH, s.h)
        }
    }
    let cols = 4
    let rows = (names.count + cols - 1) / cols
    let W = cols * (cellW + pad) + pad
    let H = rows * (cellH + pad) + pad
    let c = Canvas(W, H)
    let ctx = c.ctx
    setRGBA(ctx, Double(0x1F)/255.0, Double(0x24)/255.0, Double(0x33)/255.0, 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    for (i, n) in names.enumerated() {
        guard let img = designImages[n] else { continue }
        let col = i % cols, row = i / cols
        let cellX = pad + col * (cellW + pad)
        // CG y up: top row should be visually on top
        let cellY = H - (pad + (row + 1) * (cellH + pad)) + pad
        let display = tinted(img, tint)
        let dx = cellX + (cellW - img.width)/2
        let dy = cellY + (cellH - img.height)/2
        ctx.draw(display, in: CGRect(x: Double(dx), y: Double(dy),
                                     width: Double(img.width), height: Double(img.height)))
    }
    savePNG(c.image, to: previewDir2.appendingPathComponent("isolate.png"))
    print("Wrote isolate.png")
}
buildIsolate()

print("generate.swift previews section loaded.")

// =====================================================================
// MARK: - Assembled pet preview
// =====================================================================

let anchorMap: [String: Anchor] = Dictionary(uniqueKeysWithValues: anchors)

struct Palette {
    var base: RGB      // primary fur
    var secondary: RGB // belly/muzzle/light
    var accent: RGB    // ears inner / tuft accents
    var irisRim: RGB
    var nose: RGB
    var cheek: RGB
}

// Draw one part into the assembled canvas at its anchor, sized to design size, optional mirror.
func placePart(_ ctx: CGContext, name: String, anchorKey: String,
               tint: RGB?, mirror: Bool = false, dxN: Double = 0, dyN: Double = 0,
               scale: Double = 1.0) {
    guard let img = designImages[name], let a = anchorMap[anchorKey],
          let spec = TEXTURES.first(where: { $0.name == name }) else { return }
    let root = 1024.0
    let cxN = a.x + dxN, cyN = a.y + dyN
    let cx = cxN * root
    let cy = cyN * root
    let w = Double(spec.w) * scale, h = Double(spec.h) * scale
    let display = tint != nil ? tinted(img, tint!) : img
    ctx.saveGState()
    ctx.translateBy(x: CGFloat(cx), y: CGFloat(cy))
    if mirror { ctx.scaleBy(x: -1, y: 1) }
    ctx.draw(display, in: CGRect(x: -w/2, y: -h/2, width: w, height: h))
    ctx.restoreGState()
}

func buildAssembled(filename: String, palette: Palette,
                    bodyName: String, furName: String, earName: String,
                    tailName: String, eyeName: String, headtuftName: String,
                    bgTop: RGB, bgBottom: RGB) {
    let root = 1024
    let c = Canvas(root, root)
    let ctx = c.ctx
    // soft vertical gradient background
    let bg = colorGradient([
        (0.0, bgBottom.r, bgBottom.g, bgBottom.b, 1.0),
        (1.0, bgTop.r, bgTop.g, bgTop.b, 1.0),
    ])
    ctx.drawLinearGradient(bg, start: pt(0, 0), end: pt(0, Double(root)), options: [])

    let base = palette.base
    let sec = palette.secondary
    _ = palette.accent

    // Layer order back-to-front:
    // shadow, tail, body, abdomen, chest tuft, paws, ears, head (= fur_<style>),
    // head tuft, cheeks, muzzle, nose, eyes (base, iris, pupil, catchlight)
    placePart(ctx, name: "shadow_diffuse", anchorKey: "shadow", tint: nil)
    placePart(ctx, name: tailName, anchorKey: "tail", tint: base)
    placePart(ctx, name: bodyName, anchorKey: "body", tint: base)
    placePart(ctx, name: "abdomen_soft", anchorKey: "abdomen", tint: sec)
    placePart(ctx, name: (headtuftName == "headtuft_windswept" ? "chesttuft_cloud" : "chesttuft_layered"),
              anchorKey: "chest", tint: sec)
    placePart(ctx, name: "paws_round", anchorKey: "paws", tint: base)
    placePart(ctx, name: earName, anchorKey: "leftEar", tint: base)
    placePart(ctx, name: earName, anchorKey: "rightEar", tint: base, mirror: true)
    // fur_<style> IS the head (complete head variant); no separate overlay.
    placePart(ctx, name: furName, anchorKey: "head", tint: base)
    placePart(ctx, name: headtuftName, anchorKey: "headTuft", tint: base)
    placePart(ctx, name: "cheek_blush", anchorKey: "leftCheek", tint: palette.cheek)
    placePart(ctx, name: "cheek_blush", anchorKey: "rightCheek", tint: palette.cheek)
    placePart(ctx, name: "muzzle_small", anchorKey: "muzzle", tint: sec)
    placePart(ctx, name: "nose_heart", anchorKey: "nose", tint: palette.nose)
    // Eyes: base (non-tinted), iris (tint rim color), pupil, catchlight.
    // iris/pupil/catchlight are sized RELATIVE to the eye so the iris fits INSIDE
    // the eye (<= 0.9x eye width) and no thick outer band forms.
    let eyeSpec = TEXTURES.first(where: { $0.name == eyeName })!
    let eyeW = Double(eyeSpec.w)
    let irisFrac = 0.82, pupilFrac = 0.46, catchFrac = 0.42
    let irisScale = (eyeW * irisFrac) / 128.0        // iris_base is 128 wide
    let pupilScale = (eyeW * pupilFrac) / 80.0       // pupil_round is 80 wide
    let catchScale = (eyeW * catchFrac) / 90.0       // eye_catchlight is 90 wide
    for (eyeKey) in ["leftEye", "rightEye"] {
        let mir = eyeKey == "rightEye"
        placePart(ctx, name: eyeName, anchorKey: eyeKey, tint: nil, mirror: mir)
        placePart(ctx, name: "iris_base", anchorKey: eyeKey, tint: palette.irisRim, mirror: mir, scale: irisScale)
        placePart(ctx, name: "pupil_round", anchorKey: eyeKey, tint: nil, mirror: mir, scale: pupilScale)
        placePart(ctx, name: "eye_catchlight", anchorKey: eyeKey, tint: nil, mirror: mir, scale: catchScale)
    }
    savePNG(c.image, to: previewDir2.appendingPathComponent(filename))
    print("Wrote \(filename)")
}

let lilacPal = Palette(
    base: hexRGB(0xD9C8F0), secondary: hexRGB(0xFBF7FF), accent: hexRGB(0x9FD4F0),
    irisRim: hexRGB(0x8A5A3C), nose: hexRGB(0xE79AB0), cheek: hexRGB(0xF7C6D4))
let creamPal = Palette(
    base: hexRGB(0xF2E3CF), secondary: hexRGB(0xFBF7FF), accent: hexRGB(0xF0B8C8),
    irisRim: hexRGB(0x8A5A3C), nose: hexRGB(0xE79AB0), cheek: hexRGB(0xF0B8C8))

buildAssembled(filename: "assembled-lilac.png", palette: lilacPal,
               bodyName: "body_round", furName: "fur_fluffy", earName: "ear_pointed",
               tailName: "tail_plume", eyeName: "eye_round", headtuftName: "headtuft_windswept",
               bgTop: hexRGB(0xEBE3FA), bgBottom: hexRGB(0xC9BBE8))
buildAssembled(filename: "assembled-cream.png", palette: creamPal,
               bodyName: "body_compact", furName: "fur_smooth", earName: "ear_floppy",
               tailName: "tail_curled", eyeName: "eye_almond", headtuftName: "headtuft_curl",
               bgTop: hexRGB(0xFBF3E6), bgBottom: hexRGB(0xEAD8BE))

print("generate.swift assembled previews loaded.")

// =====================================================================
// MARK: - Self-check (exit non-zero on failure)
// =====================================================================

func loadPixels(_ url: URL) -> (w: Int, h: Int, data: [UInt8])? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
          let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
    let w = img.width, h = img.height
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    var data = [UInt8](repeating: 0, count: w*h*4)
    let ctx = data.withUnsafeMutableBytes { ptr -> CGContext? in
        CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8,
                  bytesPerRow: w*4, space: cs,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
    guard let ctx else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return (w, h, data)
}

// ---------------------------------------------------------------------
// DISPLAY-ORIENTATION pixel access — the SINGLE source of truth for every
// self-check that reasons about top/bottom/left/right.
//
// `loadPixels` decodes the PNG and re-draws it into an RGBA buffer via
// `ctx.draw(img, in:)`. Empirically verified against the actual generator
// pipeline (build a shape whose wide base sits at the bottom of the drawing,
// save via savePNG, reload here): in the resulting buffer ROW 0 IS THE TOP OF
// THE IMAGE AS VIEWED and row (h-1) is the bottom; column 0 is the left edge and
// column (w-1) is the right. i.e. buffer indices already match display
// orientation directly. Every check below MUST go through `DisplayPixels` so
// "top"/"bottom"/"left"/"right" always mean what a human sees.
struct DisplayPixels {
    let w: Int
    let h: Int
    let data: [UInt8]      // RGBA, row-major, ROW 0 = TOP (display orientation)
    init?(_ url: URL) {
        guard let px = loadPixels(url) else { return nil }
        w = px.w; h = px.h; data = px.data
    }
    // Alpha at display coordinate (x from left, y from top).
    @inline(__always) func alpha(_ x: Int, _ y: Int) -> UInt8 { data[(y*w + x)*4 + 3] }
    // Red channel (premultiplied) at display coordinate.
    @inline(__always) func red(_ x: Int, _ y: Int) -> UInt8 { data[(y*w + x)*4 + 0] }
    @inline(__always) func solid(_ x: Int, _ y: Int) -> Bool { alpha(x, y) > 128 }
    // Number of opaque (alpha>128) pixels in display row y, and its [minX,maxX].
    func rowExtent(_ y: Int) -> (count: Int, minX: Int, maxX: Int) {
        var n = 0, mn = w, mx = -1
        for x in 0..<w where solid(x, y) { n += 1; if x < mn { mn = x }; if x > mx { mx = x } }
        return (n, mn, mx)
    }
    func rowWidth(_ y: Int) -> Int { let e = rowExtent(y); return e.maxX < 0 ? 0 : (e.maxX - e.minX + 1) }
}

var failures: [String] = []

func checkAtlas(_ dir: URL, scale: Double, label: String) {
    // count PNGs
    let files = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
    let pngs = files.filter { $0.hasSuffix(".png") }
    if pngs.count != TEXTURES.count {
        failures.append("[\(label)] expected \(TEXTURES.count) PNGs, found \(pngs.count)")
    }
    for spec in TEXTURES {
        let url = dir.appendingPathComponent("\(spec.name).png")
        guard fm.fileExists(atPath: url.path) else {
            failures.append("[\(label)] missing \(spec.name).png"); continue
        }
        guard let px = loadPixels(url) else {
            failures.append("[\(label)] cannot read \(spec.name).png"); continue
        }
        let expW = Int((Double(spec.w) * scale).rounded())
        let expH = Int((Double(spec.h) * scale).rounded())
        if px.w != expW || px.h != expH {
            failures.append("[\(label)] \(spec.name): size \(px.w)x\(px.h) != expected \(expW)x\(expH)")
        }
        // at least one fully transparent corner + some visible (opaque-ish) pixels.
        // Soft parts (blush, shadow) are intentionally semi-transparent, so we
        // require meaningful coverage rather than fully-opaque alpha.
        func alphaAt(_ x: Int, _ y: Int) -> UInt8 { px.data[(y*px.w + x)*4 + 3] }
        let corners = [alphaAt(0,0), alphaAt(px.w-1,0), alphaAt(0,px.h-1), alphaAt(px.w-1,px.h-1)]
        if !corners.contains(0) {
            failures.append("[\(label)] \(spec.name): no fully-transparent corner")
        }
        // scan all alpha channels; count visible pixels and track max alpha.
        var visible = 0
        var maxA: UInt8 = 0
        var i = 3
        while i < px.data.count {
            let a = px.data[i]
            if a > maxA { maxA = a }
            if a > 40 { visible += 1 }
            i += 4
        }
        // require a reasonable amount of visible content (>0.2% of pixels)
        let minVisible = max(20, (px.w * px.h) / 500)
        if visible < minVisible {
            failures.append("[\(label)] \(spec.name): too little visible content (\(visible) px, maxAlpha \(maxA))")
        }
        // NEW RULE: every pixel in the outer 2-pixel ring must be nearly transparent
        // (alpha <= 8). This guarantees no shape is clipped at the canvas bounds.
        var maxBorderA: UInt8 = 0
        var borderBadX = -1, borderBadY = -1
        for y in 0..<px.h {
            for x in 0..<px.w {
                let onRing = (x < 2 || x >= px.w - 2 || y < 2 || y >= px.h - 2)
                if !onRing { continue }
                let a = alphaAt(x, y)
                if a > maxBorderA { maxBorderA = a; borderBadX = x; borderBadY = y }
            }
        }
        if maxBorderA > 8 {
            failures.append("[\(label)] \(spec.name): border pixel alpha \(maxBorderA) > 8 at (\(borderBadX),\(borderBadY)) — clipped at bounds")
        }
    }
}

checkAtlas(phoneAtlas, scale: 1.0, label: "phone")
checkAtlas(watchAtlas, scale: 0.5, label: "watch")

// HALO CHECK (phone atlas, tintable parts only). A feather must only reduce
// ALPHA; it must never darken luminance. For each semi-transparent edge pixel
// (10 < alpha < 200), its un-premultiplied luminance must be >= (median
// un-premultiplied luminance of fully-opaque pixels within a 12px window) - 0.06.
// Non-tinted eye/pupil/shadow parts are exempt (they are legitimately dark at
// their edges). Returns count of offending pixels per texture.
func checkHalo(_ dir: URL, label: String) {
    let win = 12
    for spec in TEXTURES {
        guard TINTABLE.contains(spec.name) else { continue }
        let url = dir.appendingPathComponent("\(spec.name).png")
        guard let px = loadPixels(url) else { continue }
        let w = px.w, h = px.h
        let d = px.data
        // Precompute un-premultiplied luminance and opacity class per pixel.
        // lum in 0..1 (gray parts: R==G==B). For opaque pixels, store lum; else -1.
        var opaqueLum = [Float](repeating: -1, count: w*h)
        for i in 0..<(w*h) {
            let a = d[i*4+3]
            if a >= 250 {
                opaqueLum[i] = Float(d[i*4+0]) / Float(a)   // R/alpha (both 0..255) -> 0..1
            }
        }
        var worst: Double = 1.0
        var worstX = -1, worstY = -1, badCount = 0
        for y in 0..<h {
            for x in 0..<w {
                let i = y*w + x
                let a = d[i*4+3]
                if a <= 10 || a >= 200 { continue }
                let lum = Double(d[i*4+0]) / Double(a)      // un-premultiplied 0..1
                // median opaque luminance within a 12px window
                var samples: [Float] = []
                let y0 = max(0, y-win), y1 = min(h-1, y+win)
                let x0 = max(0, x-win), x1 = min(w-1, x+win)
                var yy = y0
                while yy <= y1 {
                    var xx = x0
                    while xx <= x1 {
                        let ol = opaqueLum[yy*w + xx]
                        if ol >= 0 { samples.append(ol) }
                        xx += 1
                    }
                    yy += 1
                }
                if samples.isEmpty { continue }   // no opaque neighbor: nothing to compare
                samples.sort()
                let med = Double(samples[samples.count/2])
                let deficit = med - 0.06 - lum
                if deficit > 0 {
                    badCount += 1
                    if lum < worst { worst = lum; worstX = x; worstY = y }
                }
            }
        }
        // Allow a tiny tolerance count (a few stray AA pixels) — the rule is about
        // systematic darker fringes, not one-off subpixels. Threshold 0.1% of area.
        let tol = max(8, (w*h)/1000)
        if badCount > tol {
            failures.append("[\(label) HALO] \(spec.name): \(badCount) edge px darker than surface-0.06 (worst lum \(String(format: "%.3f", worst)) at (\(worstX),\(worstY)), tol \(tol))")
        }
    }
}
checkHalo(phoneAtlas, label: "phone")

// STRAIGHT-CLIP CHECK (phone atlas). A genuine rounded silhouette only grazes
// its extreme row/column with a few pixels. For each side (top/bottom/left/
// right) we find the OUTERMOST row/column that contains any solid pixel
// (alpha > 128), then measure what fraction of that line's pixels — WITHIN the
// shape's extent on the perpendicular axis — are solid. If > 35% are solid, the
// edge is a straight (clipped) line and we fail.
// Exemptions are PER-SIDE and stated in DISPLAY orientation (top = what the
// viewer sees at the top). Some parts have an intentionally flat/feathered base
// that is by-design straight. Ears/nose/tuft BOTTOM edges (the attachment base,
// at the bottom of the image as viewed) are exempt; their TOPS (the ear TIP, the
// nose apex) stay guarded so a truncated tip is still caught.
//   value = set of sides ("top"/"bottom"/"left"/"right") that are exempt.
let straightClipExempt: [String: Set<String>] = [
    // Fully exempt (all sides): pattern bands, shadow, eyelid dome base.
    "pattern_stripes": ["top", "bottom", "left", "right"],
    "pattern_gradient": ["top", "bottom", "left", "right"],
    "shadow_diffuse":  ["top", "bottom", "left", "right"],
    "eyelid":          ["top", "bottom", "left", "right"],
    // Tuft bottoms are intentionally flat/feathered (they sink into the body).
    // "bottom" here = the bottom of the image as viewed (display orientation).
    "chesttuft_small":     ["bottom"],
    "chesttuft_layered":   ["bottom"],
    "chesttuft_cloud":     ["bottom"],
    "headtuft_curl":       ["bottom"],
    "headtuft_split":      ["bottom"],
    "headtuft_windswept":  ["bottom"],
    // Ear bases (the flat attachment) sit at the BOTTOM of the image as viewed;
    // they attach to the head and are intentionally flat. The TIP (top) and
    // sides stay guarded so tip truncation is still caught.
    "ear_pointed":  ["bottom"],
    "ear_rounded":  ["bottom"],
    "ear_long":     ["bottom"],
    "ear_floppy":   ["bottom"],
    "fallback_ear": ["bottom"],
    // Nose base: a triangle nose has a flat base and a heart nose a wide lobed
    // top — the wide edge sits at the TOP of the image as viewed (the nose narrows
    // to a point at the BOTTOM). Exempt that flat/wide TOP; the point (bottom) and
    // sides remain guarded. (Audit: the previous "bottom" exemption only passed
    // because the old check had top/bottom inverted.)
    "nose_triangle": ["top"],
    "nose_heart":    ["top"],
]
func checkStraightClip(_ dir: URL, label: String) {
    for spec in TEXTURES {
        let exemptSides = straightClipExempt[spec.name] ?? []
        if exemptSides.count >= 4 { continue }
        let url = dir.appendingPathComponent("\(spec.name).png")
        guard let px = DisplayPixels(url) else { continue }
        let w = px.w, h = px.h
        // Overall shape extents (solid bounding box) in DISPLAY coordinates
        // (y from top). minY = topmost solid row, maxY = bottommost solid row.
        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h {
            for x in 0..<w where px.solid(x, y) {
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
            }
        }
        if maxX < 0 { continue }   // no solid pixels
        let extentX = max(1, maxX - minX + 1)
        let extentY = max(1, maxY - minY + 1)
        func rowFrac(_ y: Int) -> Double {
            var n = 0
            for x in minX...maxX where px.solid(x, y) { n += 1 }
            return Double(n) / Double(extentX)
        }
        func colFrac(_ x: Int) -> Double {
            var n = 0
            for y in minY...maxY where px.solid(x, y) { n += 1 }
            return Double(n) / Double(extentY)
        }
        // DISPLAY orientation (DisplayPixels: row 0 = TOP, row h-1 = BOTTOM):
        //   TOP    = topmost solid row    = minY
        //   BOTTOM = bottommost solid row = maxY
        let checks: [(String, Double)] = [
            ("top",    rowFrac(minY)),
            ("bottom", rowFrac(maxY)),
            ("left",   colFrac(minX)),
            ("right",  colFrac(maxX)),
        ]
        for (side, frac) in checks {
            if exemptSides.contains(side) { continue }
            if frac > 0.35 {
                failures.append("[\(label) CLIP] \(spec.name): \(side) edge \(String(format: "%.0f%%", frac*100)) solid (> 35%) — straight clip")
            }
        }
    }
}
checkStraightClip(phoneAtlas, label: "phone")

// EAR SIDE-STRAIGHTNESS CHECK (phone atlas). The generic straight-clip check
// above only inspects the single OUTERMOST row/column, so a near-vertical wall
// that sits a few px inside the extreme edge slips through. This dedicated
// check GUARDS the ear LEFT and RIGHT sides against such a straight vertical
// cut: excluding the bottom 12% (the flat attachment base — the ONLY exempt
// side), it histograms, per side, how many rows have their boundary (leftmost /
// rightmost solid pixel) at each column. On a smooth curved taper the boundary
// column advances steadily, so no single column is the boundary for more than a
// small fraction of rows; a straight vertical wall parks the boundary on one
// column for many rows. If any one column is the LEFT or RIGHT boundary for
// > 25% of the (non-base) rows, the side is a straight cut and we fail.
func checkEarSides(_ dir: URL, label: String) {
    for spec in TEXTURES {
        let n = spec.name
        guard n.hasPrefix("ear_") || n == "fallback_ear" else { continue }
        let url = dir.appendingPathComponent("\(n).png")
        guard let px = DisplayPixels(url) else { continue }
        let w = px.w, h = px.h
        var minY = h, maxY = -1
        for y in 0..<h {
            for x in 0..<w where px.solid(x, y) { if y < minY { minY = y }; if y > maxY { maxY = y }; break }
        }
        if maxY < 0 { continue }
        let ext = maxY - minY + 1
        let yEnd = maxY - Int(0.12 * Double(ext))     // exclude the flat base band (bottom = only exempt side)
        if yEnd <= minY { continue }
        let bandRows = yEnd - minY + 1
        var leftHist = [Int: Int](), rightHist = [Int: Int]()
        var y = minY
        while y <= yEnd {
            var lx = -1, rx = -1
            for x in 0..<w where px.solid(x, y) { if lx < 0 { lx = x }; rx = x }
            if lx >= 0 { leftHist[lx, default: 0] += 1; rightHist[rx, default: 0] += 1 }
            y += 1
        }
        let maxLeft = leftHist.values.max() ?? 0
        let maxRight = rightHist.values.max() ?? 0
        let leftFrac = Double(maxLeft) / Double(bandRows)
        let rightFrac = Double(maxRight) / Double(bandRows)
        if leftFrac > 0.25 {
            failures.append("[\(label) EARSIDE] \(n): left side \(String(format: "%.0f%%", leftFrac*100)) of rows share one boundary column (> 25%) — straight vertical cut")
        }
        if rightFrac > 0.25 {
            failures.append("[\(label) EARSIDE] \(n): right side \(String(format: "%.0f%%", rightFrac*100)) of rows share one boundary column (> 25%) — straight vertical cut")
        }
    }
}
checkEarSides(phoneAtlas, label: "phone")

// CONNECTED-COMPONENT CHECK (phone atlas). For parts that MUST be a single
// continuous shape, the opaque (alpha > 128) mask must form exactly ONE
// 4-connected component. tail_curled in particular must be one continuous
// C-curl coil — not several isolated round blobs / petals. (Flood fill via an
// explicit stack; deterministic.)
func opaqueComponentCount(_ px: DisplayPixels, minComponentPx: Int) -> Int {
    let w = px.w, h = px.h
    var seen = [Bool](repeating: false, count: w*h)
    var components = 0
    var stack: [Int] = []
    for start in 0..<(w*h) {
        if seen[start] { continue }
        let sx = start % w, sy = start / w
        if !px.solid(sx, sy) { seen[start] = true; continue }
        // BFS/DFS this component
        var size = 0
        stack.removeAll(keepingCapacity: true)
        stack.append(start); seen[start] = true
        while let cur = stack.popLast() {
            size += 1
            let cx = cur % w, cy = cur / w
            let neigh = [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]
            for (nx, ny) in neigh {
                if nx < 0 || ny < 0 || nx >= w || ny >= h { continue }
                let ni = ny*w + nx
                if seen[ni] { continue }
                if px.solid(nx, ny) { seen[ni] = true; stack.append(ni) }
                else { seen[ni] = true }
            }
        }
        if size >= minComponentPx { components += 1 }
    }
    return components
}
func checkConnectedComponents(_ dir: URL, label: String) {
    // Parts that must be exactly one opaque connected component.
    let singleComponent = ["tail_curled"]
    for name in singleComponent {
        let url = dir.appendingPathComponent("\(name).png")
        guard let px = DisplayPixels(url) else {
            failures.append("[\(label) CC] \(name): cannot read"); continue
        }
        // Ignore specks smaller than 0.05% of the canvas (stray AA pixels).
        let minPx = max(8, (px.w * px.h) / 2000)
        let comps = opaqueComponentCount(px, minComponentPx: minPx)
        if comps != 1 {
            failures.append("[\(label) CC] \(name): opaque mask has \(comps) connected components (must be exactly 1) — not a single continuous shape")
        }
    }
}
checkConnectedComponents(phoneAtlas, label: "phone")

// =====================================================================
// ORIENTATION CHECK (phone atlas) — display orientation via DisplayPixels
// (row 0 = TOP). Guarantees parts are not vertically inverted:
//   • ear_* and fallback_ear: the WIDEST opaque row must lie in the BOTTOM 40%
//     of the image (the flat attachment base sits low), AND the topmost opaque
//     row (the tip) must be narrower than 35% of the widest row.
//   • headtuft_* and chesttuft_*: the WIDEST opaque row must lie in the BOTTOM
//     half (they sprout upward from a base that sits low).
//   • tail_*: no orientation requirement.
// =====================================================================
func checkOrientation(_ dir: URL, label: String) {
    for spec in TEXTURES {
        let n = spec.name
        let isEar = n.hasPrefix("ear_") || n == "fallback_ear"
        let isHeadTuft = n.hasPrefix("headtuft_")
        let isChestTuft = n.hasPrefix("chesttuft_")
        guard isEar || isHeadTuft || isChestTuft else { continue }
        let url = dir.appendingPathComponent("\(n).png")
        guard let px = DisplayPixels(url) else {
            failures.append("[\(label) ORIENT] \(n): cannot read"); continue
        }
        let h = px.h
        // Find widest opaque row and the topmost opaque row (display orientation).
        var widest = 0, widestY = -1, topOpaqueY = -1
        for y in 0..<h {
            let rw = px.rowWidth(y)
            if rw > 0 && topOpaqueY < 0 { topOpaqueY = y }   // first (top) solid row
            if rw > widest { widest = rw; widestY = y }
        }
        if widest <= 0 { failures.append("[\(label) ORIENT] \(n): no opaque pixels"); continue }
        let widestFrac = Double(widestY) / Double(max(1, h - 1))   // 0 top .. 1 bottom
        if isEar {
            // Widest row must be in the BOTTOM 40% (widestFrac >= 0.60).
            if widestFrac < 0.60 {
                failures.append("[\(label) ORIENT] \(n): widest row at \(Int(widestFrac*100))% down (must be in bottom 40%, i.e. >= 60%) — ear appears upside down")
            }
            // Topmost opaque row (the tip) must be < 35% of the widest row.
            let topW = topOpaqueY >= 0 ? px.rowWidth(topOpaqueY) : 0
            let topRatio = Double(topW) / Double(widest)
            if topRatio >= 0.35 {
                failures.append("[\(label) ORIENT] \(n): top (tip) row is \(Int(topRatio*100))% of widest (must be < 35%) — tip not tapered / upside down")
            }
        } else {
            // headtuft_* / chesttuft_*: widest row must be in the BOTTOM half.
            if widestFrac < 0.50 {
                failures.append("[\(label) ORIENT] \(n): widest row at \(Int(widestFrac*100))% down (must be in bottom half, i.e. >= 50%) — appears upside down")
            }
        }
    }
}
checkOrientation(phoneAtlas, label: "phone")

// RigAnchors.json parses and lists all 56 textures.
for dir in [phoneDir, watchDir] {
    let url = dir.appendingPathComponent("RigAnchors.json")
    guard let d = try? Data(contentsOf: url),
          let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else {
        failures.append("RigAnchors.json in \(dir.lastPathComponent) failed to parse"); continue
    }
    guard let texs = obj["textures"] as? [String: Any] else {
        failures.append("RigAnchors.json in \(dir.lastPathComponent) missing textures map"); continue
    }
    if texs.count != TEXTURES.count {
        failures.append("RigAnchors.json in \(dir.lastPathComponent): textures count \(texs.count) != \(TEXTURES.count)")
    }
    for spec in TEXTURES where texs[spec.name] == nil {
        failures.append("RigAnchors.json in \(dir.lastPathComponent) missing texture \(spec.name)")
    }
}

print("========================================")
print("SELF-CHECK SUMMARY")
print("  Textures expected:   \(TEXTURES.count)")
print("  Phone atlas:         \(phoneAtlas.path)")
print("  Watch atlas:         \(watchAtlas.path)")
print("  Phone scale 1.0, Watch scale 0.5")
print("  RigAnchors.json:     written to app/ and 'LumiWatch Watch App/'")
print("  Previews:            \(previewDir2.path)")
if failures.isEmpty {
    print("  RESULT: PASS ✅  (all \(TEXTURES.count) textures in both atlases, sizes correct,")
    print("          transparent corners + opaque content present, RigAnchors valid)")
    print("========================================")
    exit(0)
} else {
    print("  RESULT: FAIL ❌  \(failures.count) problem(s):")
    for f in failures.prefix(60) { print("    - \(f)") }
    print("========================================")
    exit(1)
}
