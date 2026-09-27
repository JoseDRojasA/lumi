import Foundation
import CoreGraphics
import SpriteKit
import LumiCore
import LumiRendering

// MARK: - Configuration constants

let referenceSeeds: [UInt64] = [
    1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987,
    1597, 2584, 4181, 6765, 10946, 17711, 28657, 46368, 75025
]

let outputDir = URL(fileURLWithPath: "/tmp/lumi-review")

// Repo root: the tool is run from the repo root (…/app/app) via
// `swift run --package-path Tools/VisualReview`. Resolve atlases relative to CWD.
let repoRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let phoneAtlasDir = repoRoot.appendingPathComponent("app/LumiPet.atlas")
let watchAtlasDir = repoRoot.appendingPathComponent("LumiWatch Watch App/LumiPetWatch.atlas")
let layoutURL = repoRoot.appendingPathComponent("app/RigAnchors.json")

// Backgrounds
let lavenderTop = (CGFloat(0.93), CGFloat(0.90), CGFloat(0.99))
let lavenderBottom = (CGFloat(0.86), CGFloat(0.82), CGFloat(0.96))
let watchBG = (CGFloat(0x1a) / 255, CGFloat(0x18) / 255, CGFloat(0x30) / 255)

@MainActor
func run() throws {
    let fm = FileManager.default
    try? fm.createDirectory(at: outputDir, withIntermediateDirectories: true)

    guard let renderer = OffscreenRenderer() else {
        throw NSError(domain: "main", code: 1, userInfo: [NSLocalizedDescriptionKey: "no Metal device / cannot create SKRenderer"])
    }

    let layoutData = try Data(contentsOf: layoutURL)
    let layout = try PetRigLayout.decode(layoutData)
    let phoneCatalog = try DiskAtlas.makeCatalog(atlasDir: phoneAtlasDir)
    let watchCatalog = try DiskAtlas.makeCatalog(atlasDir: watchAtlasDir)

    print("=== Lumi Visual + Motion Review ===")
    print("Repo root: \(repoRoot.path)")
    print("Phone atlas missing textures: \(phoneCatalog.missingTextureNames.sorted())")
    print("Watch atlas missing textures: \(watchCatalog.missingTextureNames.sorted())")

    // Generate configs once.
    var configs: [UInt64: PetConfiguration] = [:]
    for seed in referenceSeeds {
        configs[seed] = try PetGenerator.generate(seed: seed, version: 1)
    }

    // Analysis rows collected from the phone matrix render pass.
    var analysisRows: [SeedAnalysis] = []

    // Each matrix (phone and watch) warms up its own renderer/size internally
    // (see makeMatrix), so the first cell of every matrix is laid out before
    // capture — no separate one-off warm-up needed here.

    // ---- Deliverable 1: matrix-phone.png ----
    try makeMatrix(
        title: "matrix-phone",
        seeds: referenceSeeds,
        configs: configs,
        catalog: phoneCatalog,
        layout: layout,
        policy: .phone,
        sceneSizePt: CGSize(width: 402, height: 874),
        pxScale: 2.0,          // render at 2x device pixels for crisp downscale
        cellWidthPx: 200,
        background: .gradient(top: lavenderTop, bottom: lavenderBottom),
        renderer: renderer,
        outFile: outputDir.appendingPathComponent("matrix-phone.png"),
        collectAnalysis: &analysisRows
    )

    // ---- Deliverable 2: matrix-watch.png ----
    var ignored: [SeedAnalysis] = []
    try makeMatrix(
        title: "matrix-watch",
        seeds: referenceSeeds,
        configs: configs,
        catalog: watchCatalog,
        layout: layout,
        policy: .watch,
        sceneSizePt: CGSize(width: 208, height: 248),
        pxScale: 3.0,
        cellWidthPx: 200,
        background: .solid(watchBG),
        renderer: renderer,
        outFile: outputDir.appendingPathComponent("matrix-watch.png"),
        collectAnalysis: &ignored
    )

    // ---- Deliverable 3: breathing-<seed>.png ----
    // First reference seed + one with a different motionPersonality.
    let firstSeed = referenceSeeds[0]
    let firstPersonality = configs[firstSeed]!.motionPersonality
    let secondSeed = referenceSeeds.first(where: { configs[$0]!.motionPersonality != firstPersonality }) ?? referenceSeeds[1]
    print("\n=== Breathing seeds ===")
    print("seed \(firstSeed): personality=\(firstPersonality.rawValue)")
    print("seed \(secondSeed): personality=\(configs[secondSeed]!.motionPersonality.rawValue)")

    for seed in [firstSeed, secondSeed] {
        try makeBreathingSheet(
            seed: seed,
            config: configs[seed]!,
            catalog: phoneCatalog,
            layout: layout,
            renderer: renderer
        )
    }

    // ---- Deliverable 4: magic-check.png ----
    try makeMagicCheck(
        seeds: referenceSeeds,
        configs: configs,
        phoneCatalog: phoneCatalog,
        watchCatalog: watchCatalog,
        layout: layout,
        renderer: renderer
    )

    // ---- Analysis report ----
    printAnalysisReport(rows: analysisRows, configs: configs)

    print("\n=== Files written to /tmp/lumi-review ===")
    for f in (try? fm.contentsOfDirectory(atPath: outputDir.path))?.sorted() ?? [] {
        print("  \(f)")
    }
}

// MARK: - Background helper

enum Background {
    case solid((CGFloat, CGFloat, CGFloat))
    case gradient(top: (CGFloat, CGFloat, CGFloat), bottom: (CGFloat, CGFloat, CGFloat))

    var skColor: SKColor {
        switch self {
        case .solid(let c): return SKColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        case .gradient(let top, _): return SKColor(red: top.0, green: top.1, blue: top.2, alpha: 1)
        }
    }

    func paint(_ canvas: Canvas) {
        switch self {
        case .solid(let c): canvas.fill(r: c.0, g: c.1, b: c.2)
        case .gradient(let top, let bottom): canvas.fillGradient(top: top, bottom: bottom)
        }
    }
}

// MARK: - Analysis record

struct SeedAnalysis {
    let seed: UInt64
    let canvasW: Int
    let canvasH: Int
    let box: BBox
    let touchesEdge: Bool
    let components: Int
    let eyesInsideHead: Bool
    let baseSecondaryContrast: Double
    /// Fraction of opaque pattern pixels that spill outside the pattern-free
    /// silhouette (0 = perfectly clipped; ≤ 0.002 allowed for antialiasing).
    let outsideSilhouette: Double
}

// Entry
do {
    try MainActor.assumeIsolated { try run() }
} catch {
    FileHandle.standardError.write("ERROR: \(error)\n".data(using: .utf8)!)
    exit(1)
}
