#!/usr/bin/env swift
//
// Generates the GitHub social preview image (1280×640) — Pommy on a night-sky
// background, saying his line via a speech bubble in the same style as the
// in-app chat bubble (small tinted dot + text). Pure AppKit / CoreGraphics,
// vendoring the same mascot drawing as `make-icon.swift` so the script stays
// self-contained.
//
// Usage:
//   swift scripts/make-social-preview.swift <output.png>
//
//   e.g. swift scripts/make-social-preview.swift docs/social-preview.png

import AppKit
import CoreGraphics
import CoreText

// MARK: - Palette (mirrors Camp.* tokens in DesignTokens.swift)

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1.0) -> CGColor {
    CGColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0,
            blue:  CGFloat(b) / 255.0, alpha: a)
}

let skyDeep   = rgb(0x13, 0x17, 0x22)
let skyMid    = rgb(0x11, 0x16, 0x22)
let skyLow    = rgb(0x0D, 0x11, 0x1A)
let lampWarm  = rgb(0xFF, 0xB0, 0x60)
let starWarm  = rgb(0xF4, 0xEC, 0xDA)

// Mascot palette (same as make-icon.swift)
let bodyTop    = rgb(0xF2, 0x5E, 0x4D)
let bodyBottom = rgb(0xC7, 0x3B, 0x2C)
let bodyShadow = rgb(0x9A, 0x2F, 0x22, 0.35)
let stemDark   = rgb(0x3F, 0x6B, 0x4D)
let stemLight  = rgb(0x5C, 0x8C, 0x6B)
let inkColor   = rgb(0x1B, 0x0E, 0x0A)
let highlight  = rgb(0xFF, 0xFF, 0xFF, 0.25)
let pommyTint  = rgb(0xFF, 0x6B, 0x5B)  // matches PommyChatBubbleContent default

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

// MARK: - Mascot (same drawing as make-icon.swift, tuned for dark bg)

func drawMascot(_ ctx: CGContext, frame: CGRect) {
    let S  = frame.width
    let cx = frame.midX
    let cy = frame.midY

    // Soft shadow under the body — darker against the night sky
    let shadowRect = CGRect(x: cx - S*0.375, y: cy - S*0.55,
                            width:  S*0.75,  height: S*0.10)
    ctx.saveGState()
    ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
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

    // Cheeks
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

    // Eyes
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

    // Mouth — gentle smile
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

    // Stem & leaves
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

// MARK: - Stars (deterministic for reproducible builds)

struct Star { var x: CGFloat; var y: CGFloat; var size: CGFloat; var alpha: CGFloat }

func makeStars(width: CGFloat, height: CGFloat, count: Int) -> [Star] {
    var seed: UInt32 = 0xC0FFEE
    func next() -> CGFloat {
        seed = seed &* 1664525 &+ 1013904223
        return CGFloat(seed) / CGFloat(UInt32.max)
    }
    return (0..<count).map { _ in
        Star(
            x: next() * width,
            y: next() * height,
            size: 0.6 + next() * 1.6,
            alpha: 0.20 + next() * 0.55
        )
    }
}

// MARK: - Speech bubble path
//
// Rounded rect with a small triangular tail on the left edge pointing toward
// the mascot. Mirrors the system popover style of `PommyChatBubbleContent`.

func bubblePath(rect: CGRect, cornerRadius r: CGFloat, tailY: CGFloat,
                tailWidth tw: CGFloat, tailHeight th: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let minX = rect.minX, maxX = rect.maxX
    let minY = rect.minY, maxY = rect.maxY

    // Start at top-left corner (just past it), move around clockwise
    path.move(to: CGPoint(x: minX + r, y: maxY))
    path.addLine(to: CGPoint(x: maxX - r, y: maxY))
    path.addArc(tangent1End: CGPoint(x: maxX, y: maxY),
                tangent2End: CGPoint(x: maxX, y: maxY - r),
                radius: r)
    path.addLine(to: CGPoint(x: maxX, y: minY + r))
    path.addArc(tangent1End: CGPoint(x: maxX, y: minY),
                tangent2End: CGPoint(x: maxX - r, y: minY),
                radius: r)
    path.addLine(to: CGPoint(x: minX + r, y: minY))
    path.addArc(tangent1End: CGPoint(x: minX, y: minY),
                tangent2End: CGPoint(x: minX, y: minY + r),
                radius: r)

    // Left edge with tail jutting out to the left, centered at tailY
    path.addLine(to: CGPoint(x: minX, y: tailY - th / 2))
    path.addLine(to: CGPoint(x: minX - tw, y: tailY))
    path.addLine(to: CGPoint(x: minX, y: tailY + th / 2))
    path.addLine(to: CGPoint(x: minX, y: maxY - r))
    path.addArc(tangent1End: CGPoint(x: minX, y: maxY),
                tangent2End: CGPoint(x: minX + r, y: maxY),
                radius: r)
    path.closeSubpath()
    return path
}

// MARK: - Text (Core Text for predictable layout in non-flipped context)

func makeAttrString(_ text: String, font: CTFont, color: CGColor,
                    lineSpacing: CGFloat = 6) -> NSAttributedString {
    let p = NSMutableParagraphStyle()
    p.lineSpacing = lineSpacing
    p.lineBreakMode = .byWordWrapping
    return NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: color,
        .paragraphStyle: p
    ])
}

func drawAttrString(_ ctx: CGContext, _ attr: NSAttributedString, in rect: CGRect) {
    let framesetter = CTFramesetterCreateWithAttributedString(attr)
    let path = CGPath(rect: rect, transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
    CTFrameDraw(frame, ctx)
}

// MARK: - Card composition

func drawSocialCard(_ ctx: CGContext, size: CGSize) {
    let W = size.width
    let H = size.height
    let rect = CGRect(origin: .zero, size: size)

    // 1. Night sky gradient — top of frame is `maxY` (high y) due to bottom-left origin
    drawVerticalGradient(ctx, rect: rect, top: skyDeep, bottom: skyLow)
    // Soft middle band so the gradient feels layered, not flat
    ctx.saveGState()
    ctx.setFillColor(skyMid.copy(alpha: 0.35) ?? skyMid)
    ctx.fill(CGRect(x: 0, y: H * 0.30, width: W, height: H * 0.45))
    ctx.restoreGState()

    // 2. Faint moonlight wash, top-left of the visible composition
    let cs = CGColorSpaceCreateDeviceRGB()
    let moonGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            rgb(0xB3, 0xC1, 0xE6, 0.10),
            rgb(0xB3, 0xC1, 0xE6, 0.0)
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.saveGState()
    ctx.setBlendMode(.plusLighter)
    ctx.drawRadialGradient(
        moonGrad,
        startCenter: CGPoint(x: W * 0.18, y: H * 0.85),
        startRadius: 0,
        endCenter:   CGPoint(x: W * 0.18, y: H * 0.85),
        endRadius:   H * 0.7,
        options: []
    )
    ctx.restoreGState()

    // 3. Stars
    for star in makeStars(width: W, height: H, count: 70) {
        ctx.setFillColor(starWarm.copy(alpha: star.alpha) ?? starWarm)
        ctx.fillEllipse(in: CGRect(x: star.x, y: star.y, width: star.size, height: star.size))
    }

    // 4. Warm bloom behind the mascot — like firelight from off-frame
    let bloomGrad = CGGradient(
        colorsSpace: cs,
        colors: [
            lampWarm.copy(alpha: 0.20) ?? lampWarm,
            lampWarm.copy(alpha: 0.0) ?? lampWarm
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.saveGState()
    ctx.setBlendMode(.plusLighter)
    ctx.drawRadialGradient(
        bloomGrad,
        startCenter: CGPoint(x: W * 0.26, y: H * 0.45),
        startRadius: 0,
        endCenter:   CGPoint(x: W * 0.26, y: H * 0.45),
        endRadius:   H * 0.55,
        options: []
    )
    ctx.restoreGState()

    // 5. Mascot — centered around (350, 320)
    let mascotSize: CGFloat = 320
    let mascotCx: CGFloat = 270
    let mascotCy: CGFloat = H * 0.50
    let mascotRect = CGRect(
        x: mascotCx - mascotSize / 2,
        y: mascotCy - mascotSize / 2,
        width:  mascotSize,
        height: mascotSize
    )
    drawMascot(ctx, frame: mascotRect)

    // 6. Speech bubble — to the right of the mascot, at mouth height
    let bubbleRect = CGRect(x: 510, y: 200, width: 700, height: 240)
    let tailY = mascotCy + 10  // align with mouth area
    let bubblePath = bubblePath(
        rect: bubbleRect,
        cornerRadius: 24,
        tailY: tailY,
        tailWidth: 22,
        tailHeight: 36
    )

    // Soft drop shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6),
                  blur: 20,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(bubblePath)
    // Bubble fill — warm near-white on the dark sky
    ctx.setFillColor(rgb(0xFD, 0xF8, 0xEE, 0.97))
    ctx.fillPath()
    ctx.restoreGState()

    // Hairline border — adds the "lit from above" feel the rest of the app uses
    ctx.saveGState()
    ctx.addPath(bubblePath)
    ctx.setStrokeColor(rgb(0xFF, 0xFF, 0xFF, 0.30))
    ctx.setLineWidth(1)
    ctx.strokePath()
    ctx.restoreGState()

    // 7. Tinted dot (the in-app PommyChatBubbleContent signature element)
    let dotSize: CGFloat = 12
    let dotRect = CGRect(
        x: bubbleRect.minX + 28,
        y: bubbleRect.maxY - 36 - dotSize,
        width: dotSize,
        height: dotSize
    )
    ctx.setFillColor(pommyTint.copy(alpha: 0.85) ?? pommyTint)
    ctx.fillEllipse(in: dotRect)

    // 8. Text — Pommy's line. Canon, from the onboarding welcome card.
    let line = "I'm a focus timer. I look like a tomato. I will not apologize for either."
    let textFont = CTFontCreateWithName("SFPro-Medium" as CFString, 32, nil)
    let textColor = rgb(0x1B, 0x0E, 0x0A, 0.88)
    let attr = makeAttrString(line, font: textFont, color: textColor, lineSpacing: 8)

    let textRect = CGRect(
        x: bubbleRect.minX + 56,  // leave room for the dot
        y: bubbleRect.minY + 32,
        width:  bubbleRect.width - 80,
        height: bubbleRect.height - 60
    )
    drawAttrString(ctx, attr, in: textRect)

    // 9. Tiny watermark — bottom right, very subtle. Helps when the OG image
    // is shared without surrounding repo context.
    let markFont = CTFontCreateWithName("SFMono-Regular" as CFString, 14, nil)
    let markAttr = makeAttrString("github.com/kirubanath/Pommy-public",
                                   font: markFont,
                                   color: starWarm.copy(alpha: 0.40) ?? starWarm)
    drawAttrString(ctx, markAttr,
                   in: CGRect(x: W - 360, y: 22, width: 340, height: 24))
}

// MARK: - Render to PNG

func renderPNG(width: Int, height: Int, to url: URL) throws {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide:        width,
        pixelsHigh:        height,
        bitsPerSample:     8,
        samplesPerPixel:   4,
        hasAlpha:          true,
        isPlanar:          false,
        colorSpaceName:    .deviceRGB,
        bytesPerRow:       0,
        bitsPerPixel:      32
    ) else {
        throw NSError(domain: "MakeSocial", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else {
        throw NSError(domain: "MakeSocial", code: 2)
    }
    nsCtx.imageInterpolation = .high
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext

    drawSocialCard(ctx, size: CGSize(width: width, height: height))

    guard let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "MakeSocial", code: 3)
    }
    try png.write(to: url)
}

// MARK: - Entry

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: make-social-preview.swift <output.png>\n".utf8))
    exit(2)
}
let outputURL = URL(fileURLWithPath: args[1])

print("▶ Rendering 1280×640 social preview…")
try renderPNG(width: 1280, height: 640, to: outputURL)
print("✓ Wrote \(outputURL.path)")
