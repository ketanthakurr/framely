import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let S: CGFloat = 1024
let out = CommandLine.arguments[1]

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func gradient(_ colors: [CGColor], _ locs: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locs)!
}

// Opaque canvas (App Store icons must not have alpha); flip to y-down.
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)

/// Arch: semicircle top, straight sides, softly rounded bottom corners.
func arch(_ r: CGRect, corner: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let rad = r.width / 2
    p.move(to: CGPoint(x: r.minX, y: r.minY + rad))
    p.addArc(center: CGPoint(x: r.midX, y: r.minY + rad), radius: rad, startAngle: .pi, endAngle: 0, clockwise: false)
    p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - corner))
    p.addQuadCurve(to: CGPoint(x: r.maxX - corner, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
    p.addLine(to: CGPoint(x: r.minX + corner, y: r.maxY))
    p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - corner), control: CGPoint(x: r.minX, y: r.maxY))
    p.closeSubpath()
    return p
}

// 1. Background: deep violet, lighter at top.
ctx.drawLinearGradient(gradient([rgb(0x4A3485), rgb(0x2B1F52), rgb(0x1A1433)], [0, 0.55, 1]),
                       start: CGPoint(x: S * 0.3, y: 0), end: CGPoint(x: S * 0.7, y: S), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
// Warm glow behind the frame.
ctx.drawRadialGradient(gradient([rgb(0xFF9E7D, 0.32), rgb(0xFF9E7D, 0)], [0, 1]),
                       startCenter: CGPoint(x: 512, y: 560), startRadius: 0,
                       endCenter: CGPoint(x: 512, y: 560), endRadius: 470, options: [])

// Frame layers: enlarged a touch and nudged left so the ghost arch balances.
ctx.translateBy(x: 512 - 22, y: 520); ctx.scaleBy(x: 1.1, y: 1.1); ctx.translateBy(x: -512, y: -520)

let outer = CGRect(x: 302, y: 190, width: 420, height: 640)
let inset: CGFloat = 32
let inner = outer.insetBy(dx: inset, dy: inset)

// 2. Ghost arch behind — the "next photo".
ctx.saveGState()
ctx.translateBy(x: 512 + 58, y: 510 - 18)
ctx.rotate(by: 9 * .pi / 180)
ctx.translateBy(x: -512, y: -510)
let ghost = arch(outer, corner: 40)
ctx.addPath(ghost); ctx.setFillColor(rgb(0xFFFFFF, 0.16)); ctx.fillPath()
ctx.addPath(ghost); ctx.setStrokeColor(rgb(0xFFFFFF, 0.35)); ctx.setLineWidth(4); ctx.strokePath()
ctx.restoreGState()

// 3. Cream mat with a soft shadow.
let mat = arch(outer, corner: 40)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 28), blur: 60, color: rgb(0x0B0718, 0.55))
ctx.addPath(mat); ctx.setFillColor(rgb(0xFBF6EE)); ctx.fillPath()
ctx.restoreGState()

// 4. Sunset scene inside the window.
let window = arch(inner, corner: 14)
ctx.saveGState()
ctx.addPath(window); ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0xFF9E7D), rgb(0xFF8A7A), rgb(0xF27F9C), rgb(0xB58BD6)], [0, 0.35, 0.62, 1]),
                       start: CGPoint(x: 0, y: inner.minY), end: CGPoint(x: 0, y: inner.maxY), options: [])

// Sun with a faint halo.
let sun = CGPoint(x: 512, y: 548)
ctx.drawRadialGradient(gradient([rgb(0xFFE6A3, 0.55), rgb(0xFFE6A3, 0)], [0, 1]),
                       startCenter: sun, startRadius: 60, endCenter: sun, endRadius: 150, options: [])
ctx.setFillColor(rgb(0xFFD36E))
ctx.fillEllipse(in: CGRect(x: sun.x - 74, y: sun.y - 74, width: 148, height: 148))

// Back hill (lavender) and front hill (mint).
let back = CGMutablePath()
back.move(to: CGPoint(x: inner.minX, y: 650))
back.addCurve(to: CGPoint(x: inner.maxX, y: 612), control1: CGPoint(x: 400, y: 575), control2: CGPoint(x: 560, y: 690))
back.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY)); back.addLine(to: CGPoint(x: inner.minX, y: inner.maxY)); back.closeSubpath()
ctx.addPath(back); ctx.setFillColor(rgb(0x8E7BC8)); ctx.fillPath()

let front = CGMutablePath()
front.move(to: CGPoint(x: inner.minX, y: 700))
front.addCurve(to: CGPoint(x: inner.maxX, y: 690), control1: CGPoint(x: 470, y: 760), control2: CGPoint(x: 560, y: 640))
front.addLine(to: CGPoint(x: inner.maxX, y: inner.maxY)); front.addLine(to: CGPoint(x: inner.minX, y: inner.maxY)); front.closeSubpath()
ctx.addPath(front)
ctx.clip()
ctx.drawLinearGradient(gradient([rgb(0x7FE0CF), rgb(0x4FB9B0)], [0, 1]),
                       start: CGPoint(x: 0, y: 650), end: CGPoint(x: 0, y: inner.maxY), options: [])
ctx.restoreGState()

// Thin inner bevel so the window reads as set into the mat.
ctx.addPath(window); ctx.setStrokeColor(rgb(0x000000, 0.08)); ctx.setLineWidth(3); ctx.strokePath()

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out)")
