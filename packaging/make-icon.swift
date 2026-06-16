#!/usr/bin/env swift
//
// Renders the Pawmodoro app icon — "Dozy" on a warm rounded tile — at every
// size macOS needs, into packaging/AppIcon.iconset/. The art is drawn in code
// (the same vector style as the in-app cat) so the icon is fully reproducible.
//
// Run via packaging/make-icon.sh, which then runs `iconutil` to build the .icns.

import AppKit

// Canonical 1024-unit design space; everything below is authored here.
let D: CGFloat = 1024

func color(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func tri(_ pts: [(CGFloat, CGFloat)], fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 8) {
    let p = NSBezierPath()
    p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
    p.line(to: CGPoint(x: pts[1].0, y: pts[1].1))
    p.line(to: CGPoint(x: pts[2].0, y: pts[2].1))
    p.close()
    fill.setFill(); p.fill()
    if let stroke { stroke.setStroke(); p.lineWidth = width; p.stroke() }
}

extension NSBezierPath {
    func quad(to end: CGPoint, c: CGPoint) {
        let s = currentPoint
        curve(to: end,
              controlPoint1: CGPoint(x: s.x + 2.0 / 3 * (c.x - s.x), y: s.y + 2.0 / 3 * (c.y - s.y)),
              controlPoint2: CGPoint(x: end.x + 2.0 / 3 * (c.x - end.x), y: end.y + 2.0 / 3 * (c.y - end.y)))
    }
}

// Draws the icon into the current graphics context, in the 1024 design space.
func drawIcon() {
    let body = color(0x43434F)
    let rim = color(0x5A5A68)
    let earPink = color(0xFF9EB0)
    let eyeLine = color(0xCFD4E0)
    let cheek = color(0xFF7E9C, 0.45)
    let mouthLine = color(0x2B2B36)

    // Warm rounded-tile background.
    let bg = NSBezierPath(roundedRect: CGRect(x: 0, y: 0, width: D, height: D),
                          xRadius: 225, yRadius: 225)
    let grad = NSGradient(starting: color(0xFFE3B8), ending: color(0xFFB36B))!
    grad.draw(in: bg, angle: -90)

    // Ears (outer + pink inner).
    tri([(330, 300), (268, 96), (478, 250)], fill: body, stroke: rim, width: 8)
    tri([(694, 300), (756, 96), (546, 250)], fill: body, stroke: rim, width: 8)
    tri([(348, 276), (300, 150), (452, 250)], fill: earPink)
    tri([(676, 276), (724, 150), (572, 250)], fill: earPink)

    // Head.
    let head = NSBezierPath(ovalIn: CGRect(x: 212, y: 252, width: 600, height: 560))
    body.setFill(); head.fill()
    rim.setStroke(); head.lineWidth = 8; head.stroke()

    // Sleepy, content eyes.
    let eyes = NSBezierPath()
    eyes.move(to: CGPoint(x: 372, y: 520)); eyes.quad(to: CGPoint(x: 470, y: 520), c: CGPoint(x: 421, y: 575))
    eyes.move(to: CGPoint(x: 554, y: 520)); eyes.quad(to: CGPoint(x: 652, y: 520), c: CGPoint(x: 603, y: 575))
    eyes.lineWidth = 18; eyes.lineCapStyle = .round
    eyeLine.setStroke(); eyes.stroke()

    // Cheeks.
    for cx in [360.0, 664.0] {
        let c = NSBezierPath(ovalIn: CGRect(x: CGFloat(cx) - 46, y: 556, width: 92, height: 52))
        cheek.setFill(); c.fill()
    }

    // Nose + mouth.
    tri([(486, 566), (538, 566), (512, 596)], fill: earPink)
    let mouth = NSBezierPath()
    mouth.move(to: CGPoint(x: 512, y: 596)); mouth.quad(to: CGPoint(x: 468, y: 608), c: CGPoint(x: 490, y: 616))
    mouth.move(to: CGPoint(x: 512, y: 596)); mouth.quad(to: CGPoint(x: 556, y: 608), c: CGPoint(x: 534, y: 616))
    mouth.lineWidth = 11; mouth.lineCapStyle = .round
    mouthLine.setStroke(); mouth.stroke()

    // Whiskers.
    let w = NSBezierPath()
    w.move(to: CGPoint(x: 330, y: 540)); w.line(to: CGPoint(x: 228, y: 520))
    w.move(to: CGPoint(x: 332, y: 580)); w.line(to: CGPoint(x: 232, y: 596))
    w.move(to: CGPoint(x: 694, y: 540)); w.line(to: CGPoint(x: 796, y: 520))
    w.move(to: CGPoint(x: 692, y: 580)); w.line(to: CGPoint(x: 792, y: 596))
    w.lineWidth = 9; w.lineCapStyle = .round
    eyeLine.setStroke(); w.stroke()

    // A couple of dozing "z"s.
    for (zx, zy, sz, a) in [(710.0, 360.0, 70.0, 0.9), (790.0, 270.0, 50.0, 0.7)] {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: CGFloat(sz), weight: .bold),
            .foregroundColor: color(0xFFFFFF, CGFloat(a)),
        ]
        ("z" as NSString).draw(at: CGPoint(x: CGFloat(zx), y: CGFloat(zy)), withAttributes: attrs)
    }
}

func renderPNG(pixels: Int, to url: URL) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let t = NSAffineTransform()
    t.translateX(by: 0, yBy: CGFloat(pixels))         // origin to top-left
    t.scaleX(by: CGFloat(pixels) / D, yBy: -CGFloat(pixels) / D)   // flip to y-down, scale to px
    t.concat()
    drawIcon()
    NSGraphicsContext.current?.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

// Build the .iconset (point size + scale → pixel size + filename).
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let iconset = scriptDir.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for pt in [16, 32, 128, 256, 512] {
    renderPNG(pixels: pt, to: iconset.appendingPathComponent("icon_\(pt)x\(pt).png"))
    renderPNG(pixels: pt * 2, to: iconset.appendingPathComponent("icon_\(pt)x\(pt)@2x.png"))
}
print("Wrote \(iconset.path)")
