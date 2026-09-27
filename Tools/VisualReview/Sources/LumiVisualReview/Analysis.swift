import Foundation
import CoreGraphics

// MARK: - Automated visual checks operating on rendered RGBA bitmaps

struct BBox {
    var minX: Int
    var minY: Int
    var maxX: Int
    var maxY: Int
    var isEmpty: Bool { maxX < minX || maxY < minY }
    var width: Int { maxX - minX + 1 }
    var height: Int { maxY - minY + 1 }
    var midX: Double { (Double(minX) + Double(maxX)) / 2 }
    var midY: Double { (Double(minY) + Double(maxY)) / 2 }
}

enum Analysis {
    /// Opaque-pixel bounding box using alpha threshold (0-255).
    static func boundingBox(_ bmp: RGBABitmap, alphaThreshold: UInt8 = 20) -> BBox {
        var box = BBox(minX: bmp.width, minY: bmp.height, maxX: -1, maxY: -1)
        for y in 0..<bmp.height {
            for x in 0..<bmp.width {
                if bmp.alpha(x: x, y: y) > alphaThreshold {
                    if x < box.minX { box.minX = x }
                    if y < box.minY { box.minY = y }
                    if x > box.maxX { box.maxX = x }
                    if y > box.maxY { box.maxY = y }
                }
            }
        }
        return box
    }

    /// True if any opaque pixel lies on the outermost 1px border.
    static func touchesEdge(_ bmp: RGBABitmap, alphaThreshold: UInt8 = 128) -> Bool {
        let w = bmp.width, h = bmp.height
        for x in 0..<w {
            if bmp.alpha(x: x, y: 0) > alphaThreshold { return true }
            if bmp.alpha(x: x, y: h - 1) > alphaThreshold { return true }
        }
        for y in 0..<h {
            if bmp.alpha(x: 0, y: y) > alphaThreshold { return true }
            if bmp.alpha(x: w - 1, y: y) > alphaThreshold { return true }
        }
        return false
    }

    /// Count connected components of pixels with alpha > threshold (4-connity).
    /// Optionally ignore a rectangular region (e.g. an isolated magic halo is
    /// not applicable here because magic is excluded before render).
    static func connectedComponents(_ bmp: RGBABitmap, alphaThreshold: UInt8 = 128, minSize: Int = 40) -> Int {
        let w = bmp.width, h = bmp.height
        var visited = [Bool](repeating: false, count: w * h)
        var count = 0
        var stack = [Int]()
        for start in 0..<(w * h) {
            if visited[start] { continue }
            let sx = start % w, sy = start / w
            if bmp.alpha(x: sx, y: sy) <= alphaThreshold {
                visited[start] = true
                continue
            }
            // BFS/DFS flood fill
            var size = 0
            stack.removeAll(keepingCapacity: true)
            stack.append(start)
            visited[start] = true
            while let idx = stack.popLast() {
                size += 1
                let x = idx % w, y = idx / w
                let neighbors = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                for (nx, ny) in neighbors {
                    if nx < 0 || ny < 0 || nx >= w || ny >= h { continue }
                    let nIdx = ny * w + nx
                    if visited[nIdx] { continue }
                    if bmp.alpha(x: nx, y: ny) > alphaThreshold {
                        visited[nIdx] = true
                        stack.append(nIdx)
                    } else {
                        visited[nIdx] = true
                    }
                }
            }
            if size >= minSize { count += 1 }
        }
        return count
    }

    /// Euclidean distance between two RGBA colors (0..1 per channel scaled from 0..255).
    static func colorDistance(_ a: (UInt8, UInt8, UInt8, UInt8), _ b: (UInt8, UInt8, UInt8, UInt8)) -> Double {
        let dr = (Double(a.0) - Double(b.0)) / 255.0
        let dg = (Double(a.1) - Double(b.1)) / 255.0
        let db = (Double(a.2) - Double(b.2)) / 255.0
        return (dr * dr + dg * dg + db * db).squareRoot()
    }
}
