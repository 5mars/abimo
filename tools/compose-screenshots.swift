// Compose App Store screenshots: raw simulator captures → framed, captioned
// 1320×2868 PNGs on the cream/teal palette.
//
// usage: swift tools/compose-screenshots.swift <captions.json> <rawDir> <outDir>
//
// captions.json: [ { "file": "01-stable.png", "title": "Say it out loud.",
//                    "subtitle": "No forms. Just talk." }, ... ]
// Each raw file must be a portrait PNG (any iPhone size; it is scaled to fit).
// Output keeps the raw filename. Title is set in SF Rounded Heavy, subtitle in
// SF Rounded Medium; text is ink on cream, with a teal band at the very top so
// the set reads as one row on the product page.

import AppKit
import Foundation
import UniformTypeIdentifiers

struct Caption: Decodable { let file: String; let title: String; let subtitle: String? }

let args = CommandLine.arguments
guard args.count == 4 else { fatalError("usage: compose-screenshots.swift <captions.json> <rawDir> <outDir>") }
let captions = try JSONDecoder().decode([Caption].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let rawDir = URL(fileURLWithPath: args[2]), outDir = URL(fileURLWithPath: args[3])
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let W: CGFloat = 1320, H: CGFloat = 2868
let paper = NSColor(srgbRed: 1.0, green: 0.984, blue: 0.961, alpha: 1)        // #FFFBF5
let ink   = NSColor(srgbRed: 0.118, green: 0.169, blue: 0.180, alpha: 1)      // #1E2B2E
let muted = NSColor(srgbRed: 0.357, green: 0.420, blue: 0.431, alpha: 1)      // #5B6B6E
let teal  = NSColor(srgbRed: 0.165, green: 0.616, blue: 0.561, alpha: 1)      // #2A9D8F

func rounded(_ size: CGFloat, _ weight: NSFont.Weight) -> NSFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = base.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { return f }
    return base
}

func draw(_ text: String, font: NSFont, color: NSColor, in rect: CGRect, lineHeight: CGFloat) {
    let ps = NSMutableParagraphStyle(); ps.alignment = .center; ps.minimumLineHeight = lineHeight; ps.maximumLineHeight = lineHeight
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: ps, .kern: -0.5]
    NSAttributedString(string: text, attributes: attrs).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
}

for c in captions {
    guard let raw = NSImage(contentsOf: rawDir.appendingPathComponent(c.file)), let rawCG = raw.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("skip \(c.file): cannot load"); continue
    }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gc
    let ctx = gc.cgContext
    ctx.interpolationQuality = .high

    // Paper + teal cap
    paper.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    teal.setFill(); ctx.fill(CGRect(x: 0, y: H - 28, width: W, height: 28))

    // Caption block (top 19%)
    let hasSub = (c.subtitle?.isEmpty == false)
    let titleTop = H - 150
    draw(c.title, font: rounded(104, .heavy), color: ink,
         in: CGRect(x: 80, y: titleTop - 260, width: W - 160, height: 260), lineHeight: 116)
    if let s = c.subtitle, hasSub {
        draw(s, font: rounded(50, .medium), color: muted,
             in: CGRect(x: 100, y: titleTop - 260 - 150, width: W - 200, height: 140), lineHeight: 62)
    }

    // Device frame: rounded rect with the capture inside, bleeding off the bottom
    let frameTop = H - 600
    let frameW = W - 140, frameH = frameTop + 120
    let frame = CGRect(x: (W - frameW) / 2, y: -120, width: frameW, height: frameH)
    let path = CGPath(roundedRect: frame, cornerWidth: 96, cornerHeight: 96, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 60, color: CGColor(srgbRed: 0.12, green: 0.17, blue: 0.18, alpha: 0.22))
    ink.withAlphaComponent(0.9).setFill(); ctx.addPath(path); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    let inset = frame.insetBy(dx: 18, dy: 18)
    ctx.addPath(CGPath(roundedRect: inset, cornerWidth: 80, cornerHeight: 80, transform: nil)); ctx.clip()
    let scale = inset.width / CGFloat(rawCG.width)
    let imgH = CGFloat(rawCG.height) * scale
    ctx.draw(rawCG, in: CGRect(x: inset.minX, y: inset.maxY - imgH, width: inset.width, height: imgH))
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    // Flatten to opaque RGB (App Store rejects alpha channels)
    let opaque = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 3,
                                  hasAlpha: false, isPlanar: false, colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: opaque)
    rep.draw(in: CGRect(x: 0, y: 0, width: W, height: H))
    NSGraphicsContext.restoreGraphicsState()
    let png = opaque.representation(using: .png, properties: [:])!
    let out = outDir.appendingPathComponent(c.file)
    try png.write(to: out)
    print("wrote \(out.lastPathComponent) \(Int(W))×\(Int(H))")
}
