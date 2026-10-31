import Cocoa

// Usage: swift make_icon.swift <output.png>  (renders the 1024x1024 HoverFocus icon)
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}
func white(_ a: CGFloat) -> NSColor { NSColor.white.withAlphaComponent(a) }
let blue = rgb(52, 152, 255), cyan = rgb(110, 214, 255)

/// Strokes `path` with a gradient instead of a flat colour.
func strokeGradient(_ path: NSBezierPath, width: CGFloat, _ g: NSGradient, angle: CGFloat) {
    ctx.saveGState()
    ctx.addPath(path.cgPath)
    ctx.setLineWidth(width)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    g.draw(in: path.bounds.insetBy(dx: -width, dy: -width), angle: angle)
    ctx.restoreGState()
}

// MARK: Tile — dark graphite
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -16), blur: 30, color: NSColor.black.withAlphaComponent(0.45).cgColor)
rgb(20, 21, 24).setFill(); tilePath.fill()
ctx.restoreGState()
ctx.saveGState()
tilePath.addClip()
NSGradient(colors: [rgb(74, 78, 86), rgb(38, 40, 45), rgb(16, 17, 20)], atLocations: [0, 0.5, 1],
           colorSpace: .sRGB)!.draw(in: tile, angle: -65)
// soft top sheen
NSGradient(colors: [white(0.16), white(0)])!.draw(in: NSRect(x: 100, y: 560, width: 824, height: 364), angle: -90)
// faint blue ambient glow behind the focused window
NSGradient(colors: [blue.withAlphaComponent(0.28), blue.withAlphaComponent(0)])!
    .draw(fromCenter: NSPoint(x: 600, y: 420), radius: 0, toCenter: NSPoint(x: 600, y: 420), radius: 420, options: [])
ctx.restoreGState()
// silver rim light
strokeGradient(NSBezierPath(roundedRect: tile.insetBy(dx: 2, dy: 2), xRadius: 183, yRadius: 183), width: 4,
               NSGradient(colors: [white(0.55), white(0.05), white(0.2)])!, angle: -70)

// MARK: Glass windows
func glassWindow(_ r: NSRect, strength: CGFloat, dots: Bool) {
    let body = NSBezierPath(roundedRect: r, xRadius: 46, yRadius: 46)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 34, color: NSColor.black.withAlphaComponent(0.5 * strength).cgColor)
    rgb(30, 32, 36, 0.9).setFill(); body.fill()
    ctx.restoreGState()
    ctx.saveGState()
    body.addClip()
    NSGradient(colors: [white(0.20 * strength), white(0.05 * strength)])!.draw(in: r, angle: -90)
    // title bar
    white(0.07 * strength).setFill()
    NSRect(x: r.minX, y: r.maxY - 78, width: r.width, height: 78).fill()
    white(0.14 * strength).setFill()
    NSRect(x: r.minX, y: r.maxY - 79, width: r.width, height: 2).fill()
    // diagonal specular streak
    ctx.saveGState()
    ctx.translateBy(x: r.minX + r.width * 0.62, y: r.midY)
    ctx.rotate(by: .pi / 5.5)
    NSGradient(colors: [white(0), white(0.10 * strength), white(0)])!
        .draw(in: NSRect(x: -34, y: -r.height, width: 68, height: r.height * 2), angle: 0)
    ctx.restoreGState()
    ctx.restoreGState()
    if dots {
        for i in 0..<3 {
            white(0.55 * strength).setFill()
            NSBezierPath(ovalIn: NSRect(x: r.minX + 36 + CGFloat(i) * 36, y: r.maxY - 53, width: 22, height: 22)).fill()
        }
    }
    // silver edge
    strokeGradient(body, width: 5, NSGradient(colors: [white(0.75 * strength), white(0.12 * strength), white(0.3 * strength)])!, angle: -80)
}

glassWindow(NSRect(x: 170, y: 470, width: 410, height: 300), strength: 0.7, dots: false)
let front = NSRect(x: 335, y: 255, width: 470, height: 350)
glassWindow(front, strength: 1.0, dots: true)

// MARK: Electric-blue focus ring with glow
let ring = NSBezierPath(roundedRect: front.insetBy(dx: -20, dy: -20), xRadius: 64, yRadius: 64)
ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 46, color: blue.withAlphaComponent(0.95).cgColor)
strokeGradient(ring, width: 12, NSGradient(colors: [cyan, blue, rgb(40, 110, 255)])!, angle: -45)
ctx.restoreGState()
strokeGradient(ring, width: 12, NSGradient(colors: [cyan, blue, rgb(40, 110, 255)])!, angle: -45)
// inner highlight line on the ring
strokeGradient(NSBezierPath(roundedRect: front.insetBy(dx: -15, dy: -15), xRadius: 60, yRadius: 60), width: 2,
               NSGradient(colors: [white(0.8), white(0)])!, angle: -80)

// MARK: Cursor — polished silver with blue halo
let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 0.85), (0.2, 0.67), (0.34, 1.0), (0.5, 0.93), (0.37, 0.62), (0.62, 0.62)]
let size: CGFloat = 225, origin = NSPoint(x: 575, y: 530)
let cursor = NSBezierPath()
for (i, p) in pts.enumerated() {
    let pt = NSPoint(x: origin.x + p.0 * size, y: origin.y - p.1 * size)
    i == 0 ? cursor.move(to: pt) : cursor.line(to: pt)
}
cursor.close()
cursor.lineJoinStyle = .round
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.6).cgColor)
rgb(30, 32, 36).setFill(); cursor.fill()
ctx.restoreGState()
ctx.saveGState()
cursor.addClip()
NSGradient(colors: [rgb(250, 252, 255), rgb(190, 196, 206), rgb(120, 126, 138)])!.draw(in: cursor.bounds, angle: -60)
NSGradient(colors: [white(0.9), white(0)])!.draw(in: NSRect(x: cursor.bounds.minX, y: cursor.bounds.midY, width: cursor.bounds.width * 0.55, height: cursor.bounds.height * 0.5), angle: -45)
ctx.restoreGState()
cursor.lineWidth = 7
rgb(20, 22, 26).setStroke()
cursor.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
