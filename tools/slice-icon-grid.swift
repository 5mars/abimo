// Slice a grid sheet of icons into transparent PNG imagesets.
//
// Per cell: sample the paper colour from the cell's corners, key out every
// pixel that is close to that colour AND reachable from the cell border
// (so pale interior details — lenses, snowflake fill, steam — survive), un-
// blend the anti-aliased ring, take the bounding box of EVERYTHING left
// (detached raindrops and sparkle ticks included), centre it on a padded
// square canvas and export 1x/2x/3x into `<outDir>/Icon<Name>.imageset/`
// with a Contents.json.
//
// usage: swift slice-icon-grid.swift <sheet> <outDir> <cols> <rows> <basePt> name1 name2 ... (cols*rows names, row-major)

import Foundation
import CoreGraphics
import ImageIO
import CoreImage
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 7 else { fatalError("usage: slice-icon-grid.swift <sheet> <outDir> <cols> <rows> <basePt> names...") }
let inputPath = args[1]
let outDir = args[2]
let cols = Int(args[3])!, rows = Int(args[4])!
let basePt = CGFloat(Double(args[5])!)
let names = Array(args[6...])
guard names.count == cols * rows else { fatalError("expected \(cols * rows) names, got \(names.count)") }

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inputPath) as CFURL, nil),
      let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("cannot load \(inputPath)") }

let W = cg.width, H = cg.height
var px = [UInt8](repeating: 0, count: W * H * 4)
let cs = CGColorSpaceCreateDeviceRGB()
px.withUnsafeMutableBytes { buf in
    let ctx = CGContext(data: buf.baseAddress, width: W, height: H, bitsPerComponent: 8,
                        bytesPerRow: W * 4, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
}

@inline(__always) func rgb(_ x: Int, _ y: Int) -> (Double, Double, Double) {
    let i = (y * W + x) * 4
    return (Double(px[i]), Double(px[i + 1]), Double(px[i + 2]))
}
@inline(__always) func dist(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
    let dr = a.0 - b.0, dg = a.1 - b.1, db = a.2 - b.2
    return (dr * dr + dg * dg + db * db).squareRoot()
}

func writePNG(_ image: CGImage, to path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("write failed \(path)") }
}

let ciContext = CIContext(options: [.workingColorSpace: cs, .outputColorSpace: cs])
func scaled(_ image: CGImage, by factor: CGFloat) -> CGImage {
    let filter = CIFilter(name: "CILanczosScaleTransform")!
    filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
    filter.setValue(factor, forKey: kCIInputScaleKey)
    filter.setValue(1.0, forKey: kCIInputAspectRatioKey)
    let out = filter.outputImage!
    let rect = CGRect(x: 0, y: 0, width: CGFloat(image.width) * factor, height: CGFloat(image.height) * factor)
    return ciContext.createCGImage(out, from: rect, format: .RGBA8, colorSpace: cs)!
}

let keyDistance = 40.0     // ≤ this from the paper colour → background candidate
let softDistance = 90.0    // edge ring: alpha ramps from keyDistance to here

// Sheets are rarely a clean uniform grid (margins, uneven pitch), so cut
// between the occupied bands instead: a row/column is "occupied" when
// enough of its pixels are far from the global paper colour. Falls back to
// a uniform grid if the band count doesn't match.
let globalPaper = rgb(2, 2)
func bands(_ occupancy: [Int], threshold: Int) -> [(Int, Int)] {
    var out: [(Int, Int)] = []; var start: Int? = nil
    for (i, c) in occupancy.enumerated() {
        if c > threshold, start == nil { start = i }
        if c <= threshold, let s = start { out.append((s, i - 1)); start = nil }
    }
    if let s = start { out.append((s, occupancy.count - 1)) }
    // Ignore hairline bands (sheet border lines).
    return out.filter { $0.1 - $0.0 > 12 }
}
func cuts(from bands: [(Int, Int)], total: Int) -> [Int] {
    var c = [0]
    for i in 0..<(bands.count - 1) { c.append((bands[i].1 + bands[i + 1].0) / 2) }
    c.append(total)
    return c
}
var rowOcc = [Int](repeating: 0, count: H), colOcc = [Int](repeating: 0, count: W)
for y in 0..<H {
    for x in 0..<W where dist(rgb(x, y), globalPaper) > 60 { rowOcc[y] += 1; colOcc[x] += 1 }
}
let rowBands = bands(rowOcc, threshold: 3), colBands = bands(colOcc, threshold: 3)
let rowCuts: [Int] = rowBands.count == rows ? cuts(from: rowBands, total: H) : (0...rows).map { Int(Double($0) * Double(H) / Double(rows)) }
let colCuts: [Int] = colBands.count == cols ? cuts(from: colBands, total: W) : (0...cols).map { Int(Double($0) * Double(W) / Double(cols)) }
print(rowBands.count == rows ? "row cuts from bands: \(rowCuts)" : "row bands \(rowBands.count) ≠ \(rows); uniform rows")
print(colBands.count == cols ? "col cuts from bands: \(colCuts)" : "col bands \(colBands.count) ≠ \(cols); uniform cols")

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for (idx, rawName) in names.enumerated() {
    let col = idx % cols, row = idx / cols
    let x0 = colCuts[col], x1 = colCuts[col + 1] - 1
    let y0 = rowCuts[row], y1 = rowCuts[row + 1] - 1
    let cw = x1 - x0 + 1, ch = y1 - y0 + 1

    // 1. Paper colour: median of the four 12x12 corner patches.
    var samples: [(Double, Double, Double)] = []
    for (cx, cy) in [(x0, y0), (x1 - 11, y0), (x0, y1 - 11), (x1 - 11, y1 - 11)] {
        for y in cy..<(cy + 12) { for x in cx..<(cx + 12) { samples.append(rgb(x, y)) } }
    }
    func median(_ k: KeyPath<(Double, Double, Double), Double>) -> Double {
        let s = samples.map { $0[keyPath: k] }.sorted(); return s[s.count / 2]
    }
    let paper = (median(\.0), median(\.1), median(\.2))

    // 2. Background = near paper AND reachable from the cell border.
    var isBG = [Bool](repeating: false, count: cw * ch)
    var stack: [Int] = []
    for x in 0..<cw { stack.append(x); stack.append((ch - 1) * cw + x) }
    for y in 0..<ch { stack.append(y * cw); stack.append(y * cw + (cw - 1)) }
    while let i = stack.popLast() {
        if isBG[i] { continue }
        let lx = i % cw, ly = i / cw
        if dist(rgb(x0 + lx, y0 + ly), paper) > keyDistance { continue }
        isBG[i] = true
        if lx > 0 { stack.append(i - 1) }
        if lx < cw - 1 { stack.append(i + 1) }
        if ly > 0 { stack.append(i - cw) }
        if ly < ch - 1 { stack.append(i + cw) }
    }

    // 3. Alpha + un-blend for foreground pixels touching the background.
    var alpha = [Double](repeating: 1, count: cw * ch)
    var color = [Double](repeating: 0, count: cw * ch * 3)
    for i in 0..<(cw * ch) {
        let c = rgb(x0 + i % cw, y0 + i / cw)
        color[i * 3] = c.0; color[i * 3 + 1] = c.1; color[i * 3 + 2] = c.2
        if isBG[i] { alpha[i] = 0 }
    }
    for i in 0..<(cw * ch) where !isBG[i] {
        let lx = i % cw, ly = i / cw
        var touches = false
        for dy in -1...1 { for dx in -1...1 {
            let nx = lx + dx, ny = ly + dy
            if nx >= 0, ny >= 0, nx < cw, ny < ch, isBG[ny * cw + nx] { touches = true }
        } }
        guard touches else { continue }
        let d = dist((color[i * 3], color[i * 3 + 1], color[i * 3 + 2]), paper)
        guard d < softDistance else { continue }
        let a = max(0.12, min(1, (d - keyDistance) / (softDistance - keyDistance) + 0.35))
        alpha[i] = a
        let paperArr = [paper.0, paper.1, paper.2]
        for c in 0..<3 {
            let v = (color[i * 3 + c] - (1 - a) * paperArr[c]) / a
            color[i * 3 + c] = max(0, min(255, v))
        }
    }

    // 4. Connected components. Neighbouring icons bleed into the cell (a
    //    book's bottom edge, the sheet's border line) — those pieces touch
    //    the cell border, the icon itself never does. Keep the biggest
    //    component plus anything near it (raindrops, sparkle ticks, steam).
    struct Comp { var count = 0; var minX: Int; var minY: Int; var maxX: Int; var maxY: Int; var touchesBorder = false }
    var label = [Int](repeating: -1, count: cw * ch)
    var comps: [Comp] = []
    for start in 0..<(cw * ch) where !isBG[start] && label[start] < 0 {
        var comp = Comp(minX: start % cw, minY: start / cw, maxX: start % cw, maxY: start / cw)
        var st = [start]; label[start] = comps.count
        while let i = st.popLast() {
            comp.count += 1
            let lx = i % cw, ly = i / cw
            comp.minX = min(comp.minX, lx); comp.maxX = max(comp.maxX, lx)
            comp.minY = min(comp.minY, ly); comp.maxY = max(comp.maxY, ly)
            if lx == 0 || ly == 0 || lx == cw - 1 || ly == ch - 1 { comp.touchesBorder = true }
            for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                let nx = lx + dx, ny = ly + dy
                guard nx >= 0, ny >= 0, nx < cw, ny < ch else { continue }
                let j = ny * cw + nx
                if !isBG[j] && label[j] < 0 { label[j] = comps.count; st.append(j) }
            }
        }
        comps.append(comp)
    }
    guard let mainIdx = comps.indices.filter({ !comps[$0].touchesBorder }).max(by: { comps[$0].count < comps[$1].count })
        ?? comps.indices.max(by: { comps[$0].count < comps[$1].count }) else { fatalError("cell \(idx) (\(rawName)) is empty") }
    let main = comps[mainIdx]
    let reach = 40
    var keep = Set<Int>()
    for (ci, c) in comps.enumerated() {
        if ci == mainIdx { keep.insert(ci); continue }
        if c.touchesBorder || c.count < 15 { continue }
        let near = c.maxX + reach >= main.minX && c.minX - reach <= main.maxX
               && c.maxY + reach >= main.minY && c.minY - reach <= main.maxY
        if near { keep.insert(ci) }
    }
    let dropped = comps.count - keep.count
    if dropped > 0 { print("  \(rawName): dropped \(dropped) stray component(s) (neighbour bleed / specks)") }
    for i in 0..<(cw * ch) where !isBG[i] && !keep.contains(label[i]) { isBG[i] = true; alpha[i] = 0 }

    var minX = cw, minY = ch, maxX = -1, maxY = -1
    for i in 0..<(cw * ch) where !isBG[i] {
        let lx = i % cw, ly = i / cw
        minX = min(minX, lx); maxX = max(maxX, lx); minY = min(minY, ly); maxY = max(maxY, ly)
    }
    if minX == 0 || minY == 0 || maxX == cw - 1 || maxY == ch - 1 {
        print("warning: \(rawName) still touches its cell edge (x \(minX)-\(maxX), y \(minY)-\(maxY))")
    }
    let bw = maxX - minX + 1, bh = maxY - minY + 1
    let side = Int(Double(max(bw, bh)) * 1.12)
    let offX = (side - bw) / 2, offY = (side - bh) / 2

    var canvas = [UInt8](repeating: 0, count: side * side * 4)
    for ly in minY...maxY {
        for lx in minX...maxX {
            let i = ly * cw + lx
            let a = alpha[i]
            guard a > 0 else { continue }
            let o = ((ly - minY + offY) * side + (lx - minX + offX)) * 4
            canvas[o]     = UInt8(min(255, color[i * 3] * a))
            canvas[o + 1] = UInt8(min(255, color[i * 3 + 1] * a))
            canvas[o + 2] = UInt8(min(255, color[i * 3 + 2] * a))
            canvas[o + 3] = UInt8(a * 255)
        }
    }
    let image: CGImage = canvas.withUnsafeMutableBytes { buf in
        let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                            bytesPerRow: side * 4, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }

    let name = "Icon" + rawName.prefix(1).uppercased() + rawName.dropFirst()
    let dir = "\(outDir)/\(name).imageset"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    for (scale, suffix) in [(1, "1x"), (2, "2x"), (3, "3x")] {
        writePNG(scaled(image, by: basePt * CGFloat(scale) / CGFloat(side)), to: "\(dir)/\(rawName)_\(suffix).png")
    }
    let contents = """
    {
      "images" : [
        { "filename" : "\(rawName)_1x.png", "idiom" : "universal", "scale" : "1x" },
        { "filename" : "\(rawName)_2x.png", "idiom" : "universal", "scale" : "2x" },
        { "filename" : "\(rawName)_3x.png", "idiom" : "universal", "scale" : "3x" }
      ],
      "info" : { "author" : "xcode", "version" : 1 }
    }

    """
    try! contents.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
    print("wrote \(name) from cell \(col),\(row) bbox \(bw)x\(bh) paper \(Int(paper.0)),\(Int(paper.1)),\(Int(paper.2))")
}
