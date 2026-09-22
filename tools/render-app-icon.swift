// Render the three 1024×1024 App Store icons (light / dark / tinted) from the
// horse mascot on the teal-on-cream palette.
//
//   light  : horse on a teal radial gradient (#2A9D8F → #1F7A70), opaque, no alpha
//   dark   : same horse on a deeper teal (#1F7A70 → #14574F), opaque
//   tinted : grayscale horse on black — iOS applies the user's tint on top
//
// usage: swift tools/render-app-icon.swift <horse.png> <outDir> [scale=0.80] [yOffset=-0.02]
//   horse.png : transparent PNG, the largest mascot pose available
//   scale     : horse height as a fraction of the canvas
//   yOffset   : vertical nudge as a fraction of the canvas (+ = down)

import Foundation
import CoreGraphics
import CoreImage
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else { fatalError("usage: render-app-icon.swift <horse.png> <outDir> [scale] [yOffset]") }
let horsePath = args[1]
let outDir = args[2]
let scale = args.count > 3 ? CGFloat(Double(args[3])!) : 0.80
let yOffset = args.count > 4 ? CGFloat(Double(args[4])!) : -0.02
let size = 1024

guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: horsePath) as CFURL, nil),
      let horse = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("cannot load \(horsePath)") }

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

/// Trim transparent padding so the horse fills its box predictably.
func opaqueBounds(_ img: CGImage) -> CGRect {
    let w = img.width, h = img.height
    var px = [UInt8](repeating: 0, count: w * h * 4)
    px.withUnsafeMutableBytes { buf in
        let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h { for x in 0..<w where px[(y * w + x) * 4 + 3] > 8 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    } }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

let bounds = opaqueBounds(horse)
let trimmed = horse.cropping(to: bounds)!

/// Lanczos upscale via CoreImage — noticeably cleaner than CG's bilinear at ~2×.
func upscaled(_ img: CGImage, toHeight target: CGFloat) -> CGImage {
    let factor = target / CGFloat(img.height)
    let ci = CIImage(cgImage: img)
    let f = CIFilter(name: "CILanczosScaleTransform")!
    f.setValue(ci, forKey: kCIInputImageKey)
    f.setValue(factor, forKey: kCIInputScaleKey)
    f.setValue(1.0, forKey: kCIInputAspectRatioKey)
    let out = f.outputImage!
    let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    return ctx.createCGImage(out, from: out.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))!
}

func grayscale(_ img: CGImage) -> CGImage {
    let ci = CIImage(cgImage: img)
    let mono = CIFilter(name: "CIPhotoEffectMono")!
    mono.setValue(ci, forKey: kCIInputImageKey)
    // Lift the midtones so the horse reads as light gray on black once tinted.
    let gamma = CIFilter(name: "CIGammaAdjust")!
    gamma.setValue(mono.outputImage!, forKey: kCIInputImageKey)
    gamma.setValue(0.55, forKey: "inputPower")
    let out = gamma.outputImage!
    let ctx = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
    return ctx.createCGImage(out, from: out.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB))!
}

func render(name: String, top: CGColor, bottom: CGColor, mono: Bool) {
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    // noneSkipLast → opaque output; App Store rejects alpha in the 1024 marketing icon.
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                        space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.interpolationQuality = .high

    // Background: soft radial gradient, lighter where the horse sits.
    let grad = CGGradient(colorsSpace: cs, colors: [top, bottom] as CFArray, locations: [0, 1])!
    let c = CGPoint(x: CGFloat(size) * 0.5, y: CGFloat(size) * 0.58)
    ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c,
                           endRadius: CGFloat(size) * 0.78, options: [.drawsAfterEndLocation])

    let targetH = CGFloat(size) * scale
    var sprite = upscaled(trimmed, toHeight: targetH)
    if mono { sprite = grayscale(sprite) }
    let w = CGFloat(sprite.width), h = CGFloat(sprite.height)
    let x = (CGFloat(size) - w) / 2
    let y = (CGFloat(size) - h) / 2 - yOffset * CGFloat(size) // CG origin is bottom-left
    if !mono {
        // A whisper of drop shadow lifts the horse off the teal.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -CGFloat(size) * 0.012),
                      blur: CGFloat(size) * 0.03, color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28))
        ctx.draw(sprite, in: CGRect(x: x, y: y, width: w, height: h))
        ctx.restoreGState()
    } else {
        ctx.draw(sprite, in: CGRect(x: x, y: y, width: w, height: h))
    }

    let out = ctx.makeImage()!
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("AppIcon-\(name).png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, out, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(url.path) (\(out.width)×\(out.height), alpha: \(out.alphaInfo != .noneSkipLast))")
}

render(name: "light",  top: rgb(0x2A9D8F), bottom: rgb(0x1F7A70), mono: false)
render(name: "dark",   top: rgb(0x1F7A70), bottom: rgb(0x14574F), mono: false)
render(name: "tinted", top: rgb(0x000000), bottom: rgb(0x000000), mono: true)
