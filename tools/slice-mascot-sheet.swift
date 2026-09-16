// Slice mascot sprites out of a sheet: flood-fill the light background from
// the image borders (interior whites like eyes survive; ground shadows are
// light enough to be keyed), un-blend anti-aliased edges, find connected
// components, keep the ones in the requested band, normalize them onto a
// shared bottom-aligned square canvas, export 1x/2x/3x PNGs.
//
// usage: swift slice.swift <sheet> <outDir> <minY> <name1> <name2> ...

import Foundation
import CoreGraphics
import ImageIO
import CoreImage
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 5 else { fatalError("usage: slice.swift <sheet> <outDir> <minY> names...") }
let inputPath = args[1]
let outDir = args[2]
let bandMinY = Int(args[3])!
let names = Array(args[4...])

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: inputPath) as CFURL, nil),
      let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("cannot load \(inputPath)") }

let w = cg.width, h = cg.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let cs = CGColorSpaceCreateDeviceRGB()
px.withUnsafeMutableBytes { buf in
    let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                        bytesPerRow: w * 4, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
}

@inline(__always) func minChannel(_ i: Int) -> Int {
    Int(min(px[i * 4], min(px[i * 4 + 1], px[i * 4 + 2])))
}

// --- 1. Background flood fill from the borders -----------------------------
// Anything this light AND reachable from the borders is background — paper
// or the beige ground shadow. The dark outline seals the body, so the light
// muzzle and eye whites are never reachable and survive whatever this is.
let hardBG = 172
var isBG = [Bool](repeating: false, count: w * h)
var stack: [Int] = []
for x in 0..<w { stack.append(x); stack.append((h - 1) * w + x) }
for y in 0..<h { stack.append(y * w); stack.append(y * w + (w - 1)) }
while let i = stack.popLast() {
    if isBG[i] || minChannel(i) < hardBG { continue }
    isBG[i] = true
    let x = i % w, y = i / w
    if x > 0 { stack.append(i - 1) }
    if x < w - 1 { stack.append(i + 1) }
    if y > 0 { stack.append(i - w) }
    if y < h - 1 { stack.append(i + w) }
}

// --- 2. Alpha per pixel; un-blend the edge ring -----------------------------
var alpha = [Double](repeating: 1, count: w * h)
var rgb = [Double](repeating: 0, count: w * h * 3)
for i in 0..<(w * h) {
    rgb[i * 3] = Double(px[i * 4]); rgb[i * 3 + 1] = Double(px[i * 4 + 1]); rgb[i * 3 + 2] = Double(px[i * 4 + 2])
    if isBG[i] { alpha[i] = 0 }
}
let softLow = 110.0
for i in 0..<(w * h) where !isBG[i] {
    let x = i % w, y = i / w
    var touchesBG = false
    for dy in -1...1 { for dx in -1...1 {
        let nx = x + dx, ny = y + dy
        if nx >= 0, ny >= 0, nx < w, ny < h, isBG[ny * w + nx] { touchesBG = true }
    } }
    guard touchesBG else { continue }
    let m = Double(minChannel(i))
    guard m > softLow else { continue }
    let a = max(0.15, min(1, (Double(hardBG) - m) / (Double(hardBG) - softLow)))
    alpha[i] = a
    for c in 0..<3 {
        let v = (rgb[i * 3 + c] - (1 - a) * 255) / a
        rgb[i * 3 + c] = max(0, min(255, v))
    }
}

// --- 3. Connected components over foreground --------------------------------
struct Box { var minX: Int, minY: Int, maxX: Int, maxY: Int
    var width: Int { maxX - minX + 1 }; var height: Int { maxY - minY + 1 } }
var seen = [Bool](repeating: false, count: w * h)
var boxes: [Box] = []
for start in 0..<(w * h) where !isBG[start] && !seen[start] {
    var box = Box(minX: start % w, minY: start / w, maxX: start % w, maxY: start / w)
    var st = [start]; seen[start] = true
    var count = 0
    while let i = st.popLast() {
        count += 1
        let x = i % w, y = i / w
        box.minX = min(box.minX, x); box.maxX = max(box.maxX, x)
        box.minY = min(box.minY, y); box.maxY = max(box.maxY, y)
        for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
            let j = ny * w + nx
            if !isBG[j] && !seen[j] { seen[j] = true; st.append(j) }
        }
    }
    if count > 400 && box.height > 60 { boxes.append(box) }
}
let band = boxes.filter { $0.minY >= bandMinY }.sorted { $0.minX < $1.minX }
print("components total: \(boxes.count); in band (minY >= \(bandMinY)): \(band.count)")
for b in band { print("  box x:\(b.minX)-\(b.maxX) y:\(b.minY)-\(b.maxY) (\(b.width)x\(b.height))") }
guard band.count == names.count else { fatalError("expected \(names.count) sprites, found \(band.count)") }

// --- 4. Shared square canvas, bottom-aligned --------------------------------
let pad = 8
let side = max(band.map(\.width).max()!, band.map(\.height).max()!) + pad * 2
print("canvas: \(side)x\(side)")

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path) as CFURL
    let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
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

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for (box, name) in zip(band, names) {
    var canvas = [UInt8](repeating: 0, count: side * side * 4)
    let offX = (side - box.width) / 2
    let offY = side - pad - box.height          // feet on a shared baseline
    for y in box.minY...box.maxY {
        for x in box.minX...box.maxX {
            let i = y * w + x
            let a = alpha[i]
            guard a > 0 else { continue }
            let cx = x - box.minX + offX, cy = y - box.minY + offY
            let o = (cy * side + cx) * 4
            canvas[o]     = UInt8(min(255, rgb[i * 3] * a))       // premultiplied
            canvas[o + 1] = UInt8(min(255, rgb[i * 3 + 1] * a))
            canvas[o + 2] = UInt8(min(255, rgb[i * 3 + 2] * a))
            canvas[o + 3] = UInt8(a * 255)
        }
    }
    let image: CGImage = canvas.withUnsafeMutableBytes { buf in
        let ctx = CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 8,
                            bytesPerRow: side * 4, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return ctx.makeImage()!
    }
    // Intrinsic 1x point size drives the native launch screen — keep it at
    // the historical 120pt; 2x/3x are resampled from the native canvas.
    let base: CGFloat = 120
    writePNG(scaled(image, by: base / CGFloat(side)), to: "\(outDir)/\(name)_1x.png")
    writePNG(scaled(image, by: base * 2 / CGFloat(side)), to: "\(outDir)/\(name)_2x.png")
    writePNG(scaled(image, by: base * 3 / CGFloat(side)), to: "\(outDir)/\(name)_3x.png")
    print("wrote \(name) (\(Int(base)) / \(Int(base * 2)) / \(Int(base * 3)) px)")
}
