#!/usr/bin/swift
// Generates AppIcon.icns from yamaha_white.png
// Usage: swift scripts/make_icon.swift <source.png> <output.icns>
import Foundation
import AppKit
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
let srcPath  = args.count > 1 ? args[1] : "yamaha_white.png"
let outPath  = args.count > 2 ? args[2] : "AppIcon.icns"
let iconset  = NSTemporaryDirectory() + "AppIcon_\(Int.random(in: 1000...9999)).iconset"

guard let sourceImg = NSImage(contentsOfFile: srcPath) else {
    fputs("Error: cannot load \(srcPath)\n", stderr); exit(1)
}

try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// iconset spec: (filename, pixel size)
let sizes: [(String, Int)] = [
    ("icon_16x16.png",      16),
    ("icon_16x16@2x.png",   32),
    ("icon_32x32.png",      32),
    ("icon_32x32@2x.png",   64),
    ("icon_128x128.png",   128),
    ("icon_128x128@2x.png",256),
    ("icon_256x256.png",   256),
    ("icon_256x256@2x.png",512),
    ("icon_512x512.png",   512),
    ("icon_512x512@2x.png",1024),
]

var nsRect = NSRect(origin: .zero, size: sourceImg.size)
guard let logoCG = sourceImg.cgImage(forProposedRect: &nsRect, context: nil, hints: nil) else {
    fputs("Error: cannot get CGImage from source\n", stderr); exit(1)
}

for (filename, px) in sizes {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: px, height: px,
        bitsPerComponent: 8, bytesPerRow: 0, space: cs,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }

    // Dark background to fill squircle corners
    ctx.setFillColor(CGColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: px, height: px))

    // Draw logo slightly oversized so the circle fills the square edge-to-edge
    let pad = CGFloat(px) * 0.04
    let logoRect = CGRect(x: pad, y: pad, width: CGFloat(px) - pad*2, height: CGFloat(px) - pad*2)
    ctx.saveGState()
    ctx.translateBy(x: 0, y: CGFloat(px))
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(logoCG, in: logoRect)
    ctx.restoreGState()

    guard let outImg = ctx.makeImage() else { continue }
    let url = URL(fileURLWithPath: "\(iconset)/\(filename)")
    if let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
        CGImageDestinationAddImage(dest, outImg, nil)
        CGImageDestinationFinalize(dest)
    }
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset, "-o", outPath]
try! p.run(); p.waitUntilExit()

try? FileManager.default.removeItem(atPath: iconset)

if p.terminationStatus == 0 {
    print("✔ Icon: \(outPath)")
} else {
    fputs("✗ iconutil failed\n", stderr); exit(1)
}
