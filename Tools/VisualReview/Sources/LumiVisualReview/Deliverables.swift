import Foundation
import CoreGraphics
import SpriteKit
import LumiCore
import LumiRendering

// MARK: - Deliverable 1 & 2: contact-sheet matrix

@MainActor
func makeMatrix(
    title: String,
    seeds: [UInt64],
    configs: [UInt64: PetConfiguration],
    catalog: PetTextureCatalog,
    layout: PetRigLayout,
    policy: PetRenderPolicy,
    sceneSizePt: CGSize,
    pxScale: CGFloat,
    cellWidthPx: Int,
    background: Background,
    renderer: OffscreenRenderer,
    outFile: URL,
    collectAnalysis: inout [SeedAnalysis]
) throws {
    let cols = 6
    let rows = Int(ceil(Double(seeds.count) / Double(cols)))
    let cellW = cellWidthPx
    // Preserve scene aspect for the cell.
    let cellH = Int((CGFloat(cellW) * sceneSizePt.height / sceneSizePt.width).rounded())
    let labelH = 22
    let pad = 8

    let sheetW = cols * cellW + (cols + 1) * pad
    let sheetH = rows * (cellH + labelH) + (rows + 1) * pad

    let sheet = Canvas(width: sheetW, height: sheetH)
    // Sheet background: subtle version of the cell background.
    switch background {
    case .gradient(let top, let bottom): sheet.fillGradient(top: top, bottom: bottom)
    case .solid(let c): sheet.fill(r: c.0, g: c.1, b: c.2)
    }

    let labelColor: (CGFloat, CGFloat, CGFloat) = {
        switch background {
        case .gradient: return (0.2, 0.15, 0.35)
        case .solid: return (0.85, 0.85, 0.95)
        }
    }()

    let pxSize = CGSize(width: sceneSizePt.width * pxScale, height: sceneSizePt.height * pxScale)

    print("\n=== \(title) (\(seeds.count) seeds, policy=\(policy)) ===")

    // Warm-up for THIS matrix's renderer/size. SKRenderer's very first render
    // after a fresh scene assignment at a new viewport size can come back empty
    // / un-laid-out — this previously left the FIRST cell (seed 1) blank on
    // phone and tiny/misplaced on watch. Priming with a throwaway render of the
    // first seed's scene at this matrix's exact pixel size lays out the scene
    // and the Metal pipeline before the real capture loop, for BOTH the phone
    // and watch matrices (each has a distinct renderer viewport).
    do {
        let warmSeed = seeds[0]
        let warmStage = try RigStage(
            configuration: configs[warmSeed]!,
            catalog: catalog,
            layout: layout,
            policy: policy,
            sceneSize: sceneSizePt,
            background: background.skColor
        )
        warmStage.resetToBase()
        renderer.warmUp(scene: warmStage.scene, pixelSize: pxSize)
    }

    for (i, seed) in seeds.enumerated() {
        let stage = try RigStage(
            configuration: configs[seed]!,
            catalog: catalog,
            layout: layout,
            policy: policy,
            sceneSize: sceneSizePt,
            background: background.skColor
        )
        stage.resetToBase() // BASE pose, no animation advanced

        // Log character bounds + stage scale so size outliers are quantifiable.
        let cb = stage.characterBounds
        print(String(format: "  seed %-6llu bounds=%.0fx%.0f (longest=%.0f) stageScale=%.4f",
                     seed, cb.width, cb.height, max(cb.width, cb.height), stage.stage.xScale))

        guard let cg = renderer.render(scene: stage.scene, pixelSize: pxSize) else {
            print("  seed \(seed): RENDER FAILED")
            continue
        }

        // Analysis on the full-resolution rendered cell (magic hidden for
        // component/edge checks handled separately below).
        if collectAnalysis.count < seeds.count {
            let row = analyzeSeed(seed: seed, stage: stage, catalog: catalog, layout: layout, policy: policy, sceneSizePt: sceneSizePt, pxSize: pxSize, renderer: renderer)
            collectAnalysis.append(row)
        }

        // Place into sheet cell (downscaled by CoreGraphics interpolation).
        let col = i % cols
        let rowIdx = i / cols
        let x = pad + col * (cellW + pad)
        let y = pad + rowIdx * (cellH + labelH + pad)
        sheet.draw(cg, inTopLeftRect: CGRect(x: x, y: y, width: cellW, height: cellH))
        sheet.drawText("seed \(seed)", atTopLeft: CGPoint(x: CGFloat(x), y: CGFloat(y + cellH + 3)), fontSize: 13, color: labelColor)
    }

    try sheet.writePNG(to: outFile)
    print("  wrote \(outFile.lastPathComponent) (\(sheetW)x\(sheetH))")
}

/// Render a seed twice (with and without magic) to compute component count and
/// edge/centering checks on the character only.
@MainActor
func analyzeSeed(
    seed: UInt64,
    stage: RigStage,
    catalog: PetTextureCatalog,
    layout: PetRigLayout,
    policy: PetRenderPolicy,
    sceneSizePt: CGSize,
    pxSize: CGSize,
    renderer: OffscreenRenderer
) -> SeedAnalysis {
    // Render with magic + shadow HIDDEN for connectivity/edge/bbox checks
    // (magic halo and soft shadow are excluded per the spec).
    let savedMagic = stage.rig.magic?.isHidden
    let savedShadow = stage.rig.shadow.isHidden
    stage.rig.magic?.isHidden = true
    stage.rig.shadow.isHidden = true
    let cgNoMagic = renderer.render(scene: stage.scene, pixelSize: pxSize)
    if let s = savedMagic { stage.rig.magic?.isHidden = s }
    stage.rig.shadow.isHidden = savedShadow

    var box = BBox(minX: 0, minY: 0, maxX: 0, maxY: 0)
    var touches = false
    var components = 0
    if let cg = cgNoMagic, let bmp = RGBABitmap(cg) {
        box = Analysis.boundingBox(bmp, alphaThreshold: 20)
        touches = Analysis.touchesEdge(bmp, alphaThreshold: 128)
        components = Analysis.connectedComponents(bmp, alphaThreshold: 128, minSize: 60)
    }

    // Eyes-inside-head: compare rig node accumulated frames.
    let headFrame = stage.rig.head.calculateAccumulatedFrame()
    let leftEyeFrame = stage.rig.leftEye.calculateAccumulatedFrame()
    let rightEyeFrame = stage.rig.rightEye.calculateAccumulatedFrame()
    let eyesInside = headFrame.contains(leftEyeFrame.insetBy(dx: 2, dy: 2)) &&
                     headFrame.contains(rightEyeFrame.insetBy(dx: 2, dy: 2))

    // Outside-silhouette check: render the pet twice with magic+shadow hidden —
    // once with the pattern overlays visible, once with them hidden (the base
    // "no-pattern" silhouette) — and measure the fraction of opaque pattern
    // pixels that fall outside that silhouette. A correctly clipped pattern
    // never spills, so this must be ~0 (≤ 0.2% allowed for edge antialiasing).
    var outsideSilhouette = 0.0
    do {
        let savedMagic2 = stage.rig.magic?.isHidden
        let savedShadow2 = stage.rig.shadow.isHidden
        stage.rig.magic?.isHidden = true
        stage.rig.shadow.isHidden = true

        stage.setPatternsHidden(false)
        let cgWith = renderer.render(scene: stage.scene, pixelSize: pxSize)
        stage.setPatternsHidden(true)
        let cgWithout = renderer.render(scene: stage.scene, pixelSize: pxSize)
        stage.setPatternsHidden(false)

        if let a = cgWith, let b = cgWithout,
           let bmpWith = RGBABitmap(a), let bmpWithout = RGBABitmap(b) {
            outsideSilhouette = Analysis.outsideSilhouetteFraction(
                withPatterns: bmpWith,
                silhouette: bmpWithout
            )
        }

        if let s = savedMagic2 { stage.rig.magic?.isHidden = s }
        stage.rig.shadow.isHidden = savedShadow2
    }

    // Color sanity: base vs secondary contrast from the configuration palette.
    let pal = stage.configuration.palette
    let base = (UInt8(pal.baseColor.red * 255), UInt8(pal.baseColor.green * 255), UInt8(pal.baseColor.blue * 255), UInt8(255))
    let sec = (UInt8(pal.secondaryColor.red * 255), UInt8(pal.secondaryColor.green * 255), UInt8(pal.secondaryColor.blue * 255), UInt8(255))
    let contrast = Analysis.colorDistance(base, sec)

    return SeedAnalysis(
        seed: seed,
        canvasW: Int(pxSize.width.rounded()),
        canvasH: Int(pxSize.height.rounded()),
        box: box,
        touchesEdge: touches,
        components: components,
        eyesInsideHead: eyesInside,
        baseSecondaryContrast: contrast,
        outsideSilhouette: outsideSilhouette
    )
}

// MARK: - Deliverable 3: breathing sheet

@MainActor
func makeBreathingSheet(
    seed: UInt64,
    config: PetConfiguration,
    catalog: PetTextureCatalog,
    layout: PetRigLayout,
    renderer: OffscreenRenderer
) throws {
    let sceneSizePt = CGSize(width: 402, height: 874)
    let policy: PetRenderPolicy = .phone
    let frames = 12
    let pxScale: CGFloat = 2.0
    let pxSize = CGSize(width: sceneSizePt.width * pxScale, height: sceneSizePt.height * pxScale)

    print("\n=== breathing-\(seed).png (personality=\(config.motionPersonality.rawValue)) ===")

    // A single stage we drive across phases. Print measured offsets per frame.
    let stage = try RigStage(
        configuration: config,
        catalog: catalog,
        layout: layout,
        policy: policy,
        sceneSize: sceneSizePt,
        background: .init(red: 0.93, green: 0.90, blue: 0.99, alpha: 1)
    )

    // Base transforms for measuring deltas.
    let base = stage.rig.base
    let bodyH = (stage.rig.body.childNode(withName: "pet.body.base") as? SKSpriteNode)?.size.height ?? 380

    print(String(format: "  body sprite height (pt) = %.1f", bodyH))
    print("  frame | phase  | abdomen xScale/yScale (Δ%)      | chest dy(pt / frac)     | head dy(pt / frac)")

    // Render each frame, crop to pet, collect images.
    var frameImages: [CGImage] = []
    var cropBoxes: [BBox] = []

    // Determine a common crop box from the union across frames (base render).
    for k in 0..<frames {
        let phase = Double(k) / Double(frames)
        stage.applyBreathingPhase(phase)

        // Measure rig node transforms.
        let abX = stage.rig.abdomen.xScale
        let abY = stage.rig.abdomen.yScale
        let chestDy = stage.rig.chest.position.y - base.chest.position.y
        let headDy = stage.rig.head.position.y - base.head.position.y
        let abXpct = (abX / base.abdomen.xScale - 1) * 100
        let abYpct = (abY / base.abdomen.yScale - 1) * 100
        print(String(format: "  %5d | %.4f | x=%.4f(%+.2f%%) y=%.4f(%+.2f%%) | %+.3f pt / %+.5f | %+.3f pt / %+.5f",
                     k, phase,
                     abX, abXpct, abY, abYpct,
                     chestDy, chestDy / bodyH,
                     headDy, headDy / bodyH))

        guard let cg = renderer.render(scene: stage.scene, pixelSize: pxSize) else { continue }
        frameImages.append(cg)
        if let bmp = RGBABitmap(cg) {
            cropBoxes.append(Analysis.boundingBox(bmp, alphaThreshold: 20))
        }
    }
    stage.resetToBase()

    guard !frameImages.isEmpty else {
        print("  RENDER FAILED — no frames")
        return
    }

    // Union crop box (a little padding), then a common size.
    var union = cropBoxes.first!
    for b in cropBoxes where !b.isEmpty {
        union.minX = min(union.minX, b.minX); union.minY = min(union.minY, b.minY)
        union.maxX = max(union.maxX, b.maxX); union.maxY = max(union.maxY, b.maxY)
    }
    let padPx = 24
    let cropX = max(0, union.minX - padPx)
    let cropY = max(0, union.minY - padPx)
    let cropW = min(Int(pxSize.width) - cropX, union.width + 2 * padPx)
    let cropH = min(Int(pxSize.height) - cropY, union.height + 2 * padPx)
    let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

    let cropped: [CGImage] = frameImages.compactMap { $0.cropping(to: cropRect) }

    // Build the film-strip: 12 frames in a row + a DIFF strip below.
    let cellDisplayH = 260
    let scale = CGFloat(cellDisplayH) / CGFloat(cropH)
    let cellDisplayW = Int((CGFloat(cropW) * scale).rounded())
    let gap = 6
    let labelH = 18
    let stripW = frames * cellDisplayW + (frames + 1) * gap
    let stripH = 2 * (cellDisplayH + labelH) + 3 * gap + 24

    let canvas = Canvas(width: stripW, height: stripH)
    canvas.fill(r: 0.10, g: 0.09, b: 0.16)
    canvas.drawText("breathing seed \(seed) — top: frames (phase 0..11/12); bottom: frame k @50% over frame 0 (motion diff)",
                    atTopLeft: CGPoint(x: 8, y: 4), fontSize: 12, color: (0.9, 0.9, 0.95))

    let topY = 24 + gap
    for (k, img) in cropped.enumerated() {
        let x = gap + k * (cellDisplayW + gap)
        canvas.draw(img, inTopLeftRect: CGRect(x: x, y: topY, width: cellDisplayW, height: cellDisplayH))
        canvas.drawText("\(k)/12", atTopLeft: CGPoint(x: CGFloat(x + 4), y: CGFloat(topY + cellDisplayH + 2)), fontSize: 11, color: (0.8, 0.8, 0.9))
    }

    // DIFF strip: frame0 base, overlay frame k at 50%.
    let bottomY = topY + cellDisplayH + labelH + gap
    let frame0 = cropped[0]
    for (k, img) in cropped.enumerated() {
        let x = gap + k * (cellDisplayW + gap)
        canvas.draw(frame0, inTopLeftRect: CGRect(x: x, y: bottomY, width: cellDisplayW, height: cellDisplayH), alpha: 1.0)
        canvas.draw(img, inTopLeftRect: CGRect(x: x, y: bottomY, width: cellDisplayW, height: cellDisplayH), alpha: 0.5)
        canvas.drawText("Δ\(k)", atTopLeft: CGPoint(x: CGFloat(x + 4), y: CGFloat(bottomY + cellDisplayH + 2)), fontSize: 11, color: (0.8, 0.8, 0.9))
    }

    let out = outputDir.appendingPathComponent("breathing-\(seed).png")
    try canvas.writePNG(to: out)
    print("  wrote \(out.lastPathComponent) (\(stripW)x\(stripH))")
}

// MARK: - Deliverable 4: magic check

@MainActor
func makeMagicCheck(
    seeds: [UInt64],
    configs: [UInt64: PetConfiguration],
    phoneCatalog: PetTextureCatalog,
    watchCatalog: PetTextureCatalog,
    layout: PetRigLayout,
    renderer: OffscreenRenderer
) throws {
    print("\n=== magic-check.png ===")

    let magicSeeds = seeds.filter { configs[$0]!.details.magicalFeature != .none }
    print("  seeds with a magical feature: \(magicSeeds.count) of \(seeds.count)")

    if magicSeeds.isEmpty {
        print("  (none) — skipping magic-check.png")
        return
    }

    // Each row: [phone full] [watch full] [phone magic hidden]  with a label.
    let phoneScenePt = CGSize(width: 402, height: 874)
    let watchScenePt = CGSize(width: 208, height: 248)
    let cellH = 240
    let phoneCellW = Int((CGFloat(cellH) * phoneScenePt.width / phoneScenePt.height).rounded())
    let watchCellW = Int((CGFloat(cellH) * watchScenePt.width / watchScenePt.height).rounded())
    let gap = 8
    let labelW = 260
    let rowH = cellH + gap

    let sheetW = labelW + 3 * (max(phoneCellW, watchCellW) + gap) + gap
    let sheetH = magicSeeds.count * rowH + gap
    let canvas = Canvas(width: sheetW, height: sheetH)
    canvas.fill(r: 0.10, g: 0.09, b: 0.16)

    let pxScale: CGFloat = 2.0

    for (i, seed) in magicSeeds.enumerated() {
        let config = configs[seed]!
        let feature = config.details.magicalFeature
        let texName = PetTextureCatalog.magicTextureName(for: feature)
        let y = gap + i * rowH

        // phone full
        let phoneStage = try RigStage(configuration: config, catalog: phoneCatalog, layout: layout, policy: .phone, sceneSize: phoneScenePt, background: SKColor(red: 0.16, green: 0.14, blue: 0.26, alpha: 1))
        phoneStage.resetToBase()

        // Magic node metrics (from phone rig).
        var magicInfo = "no magic node built"
        if let magic = phoneStage.rig.magic as? SKSpriteNode {
            let headFrame = phoneStage.rig.head.calculateAccumulatedFrame()
            let bodyFrame = phoneStage.rig.body.calculateAccumulatedFrame()
            let magicFrame = magic.calculateAccumulatedFrame()
            magicInfo = String(format: "tex=%@ alpha=%.2f size=%.0fx%.0f pos=(%.0f,%.0f)",
                               (magic.texture != nil ? texName : "MISSING"),
                               magic.alpha, magic.size.width, magic.size.height,
                               magic.position.x, magic.position.y)
            print("  seed \(seed): feature=\(feature.rawValue) \(magicInfo)")
            print(String(format: "            magic frame=%@ vs head=%@ body=%@ (magic covers head:%@ body:%@)",
                         rectStr(magicFrame), rectStr(headFrame), rectStr(bodyFrame),
                         magicFrame.intersects(headFrame) ? "yes" : "no",
                         magicFrame.intersects(bodyFrame) ? "yes" : "no"))
        } else {
            print("  seed \(seed): feature=\(feature.rawValue) — \(magicInfo)")
        }

        let phonePx = CGSize(width: phoneScenePt.width * pxScale, height: phoneScenePt.height * pxScale)
        if let cg = renderer.render(scene: phoneStage.scene, pixelSize: phonePx) {
            canvas.draw(cg, inTopLeftRect: CGRect(x: labelW, y: y, width: phoneCellW, height: cellH))
        }

        // phone with magic hidden
        phoneStage.setMagicHidden(true)
        if let cg = renderer.render(scene: phoneStage.scene, pixelSize: phonePx) {
            canvas.draw(cg, inTopLeftRect: CGRect(x: labelW + 2 * (phoneCellW + gap), y: y, width: phoneCellW, height: cellH))
        }
        phoneStage.setMagicHidden(false)

        // watch full
        let watchStage = try RigStage(configuration: config, catalog: watchCatalog, layout: layout, policy: .watch, sceneSize: watchScenePt, background: SKColor(red: 0.10, green: 0.09, blue: 0.19, alpha: 1))
        watchStage.resetToBase()
        let watchPx = CGSize(width: watchScenePt.width * pxScale, height: watchScenePt.height * pxScale)
        if let cg = renderer.render(scene: watchStage.scene, pixelSize: watchPx) {
            canvas.draw(cg, inTopLeftRect: CGRect(x: labelW + (phoneCellW + gap), y: y, width: watchCellW, height: cellH))
        }

        canvas.drawText("seed \(seed)  \(feature.rawValue)", atTopLeft: CGPoint(x: 6, y: CGFloat(y + 8)), fontSize: 13, color: (0.95, 0.9, 1.0))
        canvas.drawText("intensity \(String(format: "%.2f", config.details.magicalIntensity))", atTopLeft: CGPoint(x: 6, y: CGFloat(y + 28)), fontSize: 11, color: (0.8, 0.8, 0.9))
        canvas.drawText("phone | watch | phone(no magic)", atTopLeft: CGPoint(x: 6, y: CGFloat(y + 48)), fontSize: 10, color: (0.7, 0.7, 0.85))
    }

    let out = outputDir.appendingPathComponent("magic-check.png")
    try canvas.writePNG(to: out)
    print("  wrote \(out.lastPathComponent) (\(sheetW)x\(sheetH))")
}

func rectStr(_ r: CGRect) -> String {
    String(format: "(%.0f,%.0f,%.0fx%.0f)", r.minX, r.minY, r.width, r.height)
}

// MARK: - Report

@MainActor
func printAnalysisReport(rows: [SeedAnalysis], configs: [UInt64: PetConfiguration]) {
    print("\n================ AUTOMATED CHECK TABLE (phone .phone renders) ================")
    print("seed   | canvas    | bbox WxH      | centerΔx% centerΔy% | edge | comps | eyesInHead | base/sec contrast | outsideSil%")
    var failures: [(UInt64, String)] = []

    for row in rows.sorted(by: { $0.seed < $1.seed }) {
        let cx = row.box.midX
        let cy = row.box.midY
        let dxPct = (cx - Double(row.canvasW) / 2) / Double(row.canvasW) * 100
        let dyPct = (cy - Double(row.canvasH) / 2) / Double(row.canvasH) * 100
        let centered = abs(dxPct) <= 3.0 && abs(dyPct) <= 3.0
        let contrastOK = row.baseSecondaryContrast >= 0.12
        let outsidePct = row.outsideSilhouette * 100
        let outsideOK = row.outsideSilhouette <= 0.002   // ≤ 0.2%

        print(String(format: "%-6llu | %4dx%-4d | %4dx%-4d    | %+7.2f  %+7.2f  | %-4@ | %5d | %-10@ | %.3f | %7.3f%% %@",
                     row.seed, row.canvasW, row.canvasH, row.box.width, row.box.height,
                     dxPct, dyPct,
                     (row.touchesEdge ? "YES" : "no") as NSString,
                     row.components,
                     (row.eyesInsideHead ? "yes" : "NO") as NSString,
                     row.baseSecondaryContrast,
                     outsidePct,
                     (outsideOK ? "" : "<<FAIL") as NSString))

        var reasons: [String] = []
        if !centered { reasons.append(String(format: "off-center (Δx=%.1f%%, Δy=%.1f%%)", dxPct, dyPct)) }
        if row.touchesEdge { reasons.append("clips canvas edge") }
        if row.components != 1 { reasons.append("detached parts (\(row.components) components, expected 1)") }
        if !row.eyesInsideHead { reasons.append("eye(s) outside head bounds") }
        if !contrastOK { reasons.append(String(format: "low base/secondary contrast (%.3f < 0.12)", row.baseSecondaryContrast)) }
        if !outsideOK { reasons.append(String(format: "pattern spills outside silhouette (%.3f%% > 0.2%%)", outsidePct)) }
        if !reasons.isEmpty { failures.append((row.seed, reasons.joined(separator: "; "))) }
    }

    print("\n================ FAILURES ================")
    if failures.isEmpty {
        print("  none — all seeds pass centering / edge / connectivity / eyes / contrast checks.")
    } else {
        for (seed, reason) in failures {
            let c = configs[seed]!
            let ctx = String(format: "tail=%@ len=%.2f thick=%.2f | eyeShape=%@ eyeScale=%.2f | ears=%@ earScale=%.2f",
                             c.tail.tailStyle.rawValue, c.tail.tailLength, c.tail.tailThickness,
                             c.face.eyeShape.rawValue, c.face.eyeScale,
                             c.ears.earStyle.rawValue, c.ears.earScale)
            print("  seed \(seed): \(reason)\n            [\(ctx)]")
        }
    }

    // Breathing amplitude vs spec.
    print("\n================ BREATHING AMPLITUDE SPEC ================")
    print("  spec: abdomenX .028, abdomenY .018, chestRise .015, headRise .008 (fractions).")
    let profile = BreathingProfile(personality: .calm, reduceMotion: false, includesSecondaryMotion: true)
    print(String(format: "  profile (non-reduced): abdomenX=%.3f abdomenY=%.3f chestRise=%.3f headRise=%.3f secondary=%.4f",
                 profile.abdomenXAmplitude, profile.abdomenYAmplitude, profile.chestRise, profile.headRise, profile.secondaryAmplitude))
    print("  → see the per-frame tables in the breathing-<seed> sections above for measured peak offsets.")
}
