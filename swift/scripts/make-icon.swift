#!/usr/bin/env swift
//
// Generates a multi-resolution macOS .icns app icon for Pommy using pure
// AppKit / CoreGraphics drawing (no SwiftUI). Visually mirrors the in-app
// vector mascot but kept as a static idle pose.
//
// Usage:
//   swift scripts/make-icon.swift <output.icns>
//
// Strategy:
//   1. Render the icon directly into a CGContext at each required pixel size.
//   2. Save each as a PNG inside a temp .iconset folder using Apple's naming.
//   3. Run `iconutil -c icns` to produce the final .icns file.

import AppKit
import CoreGraphics

// MARK: - Color helpers

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0,
            blue:  CGFloat(b) / 255.0, alpha: a)
}

let bgTop      = rgb(0xFF, 0xF5, 0xEC)
let bgBottom   = rgb(0xFF, 0xD9, 0xC5)
let bodyTop    = rgb(0xF2, 0x5E, 0x4D)
let bodyBottom = rgb(0xC7, 0x3B, 0x2C)
let bodyShadow = rgb(0x9A, 0x2F, 0x22, 0.35)
let stemDark   = rgb(0x3F, 0x6B, 0x4D)
let stemLight  = rgb(0x5C, 0x8C, 0x6B)
let cheekTint  = rgb(0xFF, 0x6B, 0x5B, 0.40)
let inkColor   = rgb(0x1B, 0x0E, 0x0A)
let highlight  = rgb(0xFF, 0xFF, 0xFF, 0.25)

// MARK: - Drawing primitives

func drawVerticalGradient(_ ctx: CGContext, rect: CGRect, top: CGColor, bottom: CGColor) {
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs,
                          colors: [top, bottom] as CFArray,
                          locations: [0, 1])!
    ctx.drawLinearGradient(
        grad,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end:   CGPoint(x: rect.midX, y: rect.minY),
        options: []
    )
}

func capsulePath(in rect: CGRect) -> CGPath {
    CGPath(roundedRect: rect,
           cornerWidth:  min(rect.width, rect.height) / 2,
           cornerHeight: min(rect.width, rect.height) / 2,
           transform: nil)
}

func fillCapsule(_ ctx: CGContext, rect: CGRect, color: CGColor) {
    ctx.saveGState()
    ctx.setFillColor(color)
    ctx.addPath(capsulePath(in: rect))
    ctx.fillPath()
    ctx.restoreGState()
}

func drawLeaf(_ ctx: CGContext, center: CGPoint, w: CGFloat, h: CGFloat, rotationDeg: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: rotationDeg * .pi / 180)

    let rect = CGRect(x: -w/2, y: -h/2, width: w, height: h)
    let cs = CGColorSpaceCreateDeviceRGB()
    let grad = CGGradient(colorsSpace: cs,
                          colors: [stemLight, stemDark] as CFArray,
                          locations: [0, 1])!

    ctx.addEllipse(in: rect)
    ctx.clip()
    ctx.drawLinearGradient(
        grad,
        start: CGPoint(x: 0, y:  h/2),
        end:   CGPoint(x: 0, y: -h/2),
        options: []
    )
    ctx.restoreGState()
}

// MARK: - Mascot

/// Draws the static idle Pommy centred in `frame`. Uses the same proportions
/// as the in-app SwiftUI mascot. Coordinates are macOS / CG (origin bottom-left).
func drawMascot(_ ctx: CGContext, frame: CGRect) {
    let S  = frame.width
    let cx = frame.midX
    let cy = frame.midY

    // Soft shadow under the body
    let shadowRect = CGRect(x: cx - S*0.375, y: cy - S*0.55,
                            width:  S*0.75,  height: S*0.10)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.30))
    ctx.fillEllipse(in: shadowRect)
    ctx.restoreGState()

    // Body
    let bodyRect = frame
    ctx.saveGState()
    ctx.addEllipse(in: bodyRect)
    ctx.clip()

    drawVerticalGradient(ctx, rect: bodyRect, top: bodyTop, bottom: bodyBottom)

    // Bottom shadow band
    let bandRect = CGRect(x: cx - S*0.39, y: bodyRect.minY + S*0.05,
                          width: S*0.78,  height: S*0.30)
    ctx.setFillColor(bodyShadow)
    ctx.fillEllipse(in: bandRect)

    // Specular highlight top-left
    let hiRect = CGRect(x: cx - S*0.33, y: cy + S*0.13,
                        width: S*0.30,  height: S*0.18)
    ctx.setFillColor(highlight)
    ctx.fillEllipse(in: hiRect)

    // Cheeks (soft, layered for fake blur)
    func cheek(at p: CGPoint) {
        for (alphaScale, expand) in [(0.35, CGFloat(0.0)), (0.65, CGFloat(0.04)), (1.0, CGFloat(0.10))] {
            let w = S * 0.16 * (1 - expand)
            let h = S * 0.10 * (1 - expand)
            ctx.setFillColor(rgb(0xFF, 0x6B, 0x5B, 0.40 * alphaScale))
            ctx.fillEllipse(in: CGRect(x: p.x - w/2, y: p.y - h/2, width: w, height: h))
        }
    }
    cheek(at: CGPoint(x: cx - S*0.20, y: cy - S*0.06))
    cheek(at: CGPoint(x: cx + S*0.20, y: cy - S*0.06))

    // Eyes (capsules, slight upward offset)
    let eyeW = S * 0.05
    let eyeH = S * 0.07
    let eyeY = cy + S*0.04
    fillCapsule(ctx,
                rect: CGRect(x: cx - S*0.16 - eyeW/2, y: eyeY - eyeH/2,
                             width: eyeW, height: eyeH),
                color: inkColor)
    fillCapsule(ctx,
                rect: CGRect(x: cx + S*0.16 - eyeW/2, y: eyeY - eyeH/2,
                             width: eyeW, height: eyeH),
                color: inkColor)

    // Mouth — gentle smile (arc opening upward in CG coords)
    ctx.saveGState()
    ctx.setStrokeColor(inkColor)
    ctx.setLineWidth(S * 0.018)
    ctx.setLineCap(.round)
    ctx.beginPath()
    let mouthY    = cy - S*0.16
    let mouthHalf = S * 0.08
    ctx.move(to: CGPoint(x: cx - mouthHalf, y: mouthY))
    ctx.addQuadCurve(
        to:      CGPoint(x: cx + mouthHalf, y: mouthY),
        control: CGPoint(x: cx,             y: mouthY - S*0.06)
    )
    ctx.strokePath()
    ctx.restoreGState()

    ctx.restoreGState() // end body clip

    // Body hairline
    ctx.saveGState()
    ctx.setStrokeColor(rgb(0xFF, 0xFF, 0xFF, 0.10))
    ctx.setLineWidth(max(1, S * 0.005))
    ctx.strokeEllipse(in: bodyRect)
    ctx.restoreGState()

    // Stem & leaves on top
    let stemY = cy + S * 0.46
    let stemRect = CGRect(x: cx - S*0.05, y: stemY - S*0.04,
                          width: S*0.10,  height: S*0.18)
    fillCapsule(ctx, rect: stemRect, color: stemDark)

    drawLeaf(ctx,
             center:      CGPoint(x: cx - S*0.16, y: stemY + S*0.04),
             w: S*0.32, h: S*0.18, rotationDeg: -32)
    drawLeaf(ctx,
             center:      CGPoint(x: cx + S*0.17, y: stemY + S*0.05),
             w: S*0.30, h: S*0.16, rotationDeg:  28)
}

// MARK: - Icon composition

func drawIcon(_ ctx: CGContext, size S: CGFloat) {
    let rect    = CGRect(x: 0, y: 0, width: S, height: S)
    let corner  = S * 0.225
    let bgPath  = CGPath(roundedRect: rect,
                         cornerWidth:  corner,
                         cornerHeight: corner,
                         transform: nil)

    // Background squircle with warm gradient
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    drawVerticalGradient(ctx, rect: rect, top: bgTop, bottom: bgBottom)

    // Subtle bottom vignette for grounding
    drawVerticalGradient(
        ctx, rect: rect,
        top:    CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
        bottom: CGColor(red: 0, green: 0, blue: 0, alpha: 0.06)
    )
    ctx.restoreGState()

    // Top inner sheen
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()
    let cs = CGColorSpaceCreateDeviceRGB()
    let sheenGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.28),
            CGColor(red: 1, green: 1, blue: 1, alpha: 0.0)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(
        sheenGrad,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end:   CGPoint(x: rect.midX, y: rect.midY),
        options: []
    )
    ctx.restoreGState()

    // Mascot, slightly above center for visual balance with the rounded base
    let mascotSize = S * 0.66
    let mascotRect = CGRect(
        x: (S - mascotSize) / 2,
        y: (S - mascotSize) / 2 - S * 0.02,
        width:  mascotSize,
        height: mascotSize
    )
    drawMascot(ctx, frame: mascotRect)

    // Outer hairline border for crispness on light desktops
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setStrokeColor(rgb(0, 0, 0, 0.06))
    ctx.setLineWidth(max(1, S * 0.004))
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Render to PNG

func renderPNG(pixels: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide:        pixels,
        pixelsHigh:        pixels,
        bitsPerSample:     8,
        samplesPerPixel:   4,
        hasAlpha:          true,
        isPlanar:          false,
        colorSpaceName:    .deviceRGB,
        bytesPerRow:       0,
        bitsPerPixel:      32
    ) else {
        throw NSError(domain: "MakeIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "MakeIcon", code: 2)
    }
    nsCtx.imageInterpolation = .high
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext

    drawIcon(ctx, size: CGFloat(pixels))

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MakeIcon", code: 3)
    }
    try png.write(to: url)
}

// MARK: - Entry

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.icns>\n".utf8))
    exit(2)
}
let outputURL = URL(fileURLWithPath: args[1])

let tmp = FileManager.default.temporaryDirectory
    .appendingPathComponent("Pommy-AppIcon-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tmp) }

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

print("▶ Rendering icon variants…")
for v in variants {
    let url = tmp.appendingPathComponent(v.name)
    try renderPNG(pixels: v.pixels, to: url)
    print("  · \(v.name)")
}

print("▶ Composing .icns via iconutil…")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments     = ["-c", "icns", "-o", outputURL.path, tmp.path]
try proc.run()
proc.waitUntilExit()

if proc.terminationStatus != 0 {
    FileHandle.standardError.write(Data("iconutil failed (\(proc.terminationStatus))\n".utf8))
    exit(proc.terminationStatus)
}

print("✓ Wrote \(outputURL.path)")
