import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - Helpers

func deg(_ d: CGFloat) -> CGFloat { d * .pi / 180 }

func makeContext(width: Int, height: Int) -> CGContext {
    let cs = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                        bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    return ctx
}

func makeContext(_ px: Int) -> CGContext {
    makeContext(width: px, height: px)
}

func writePNG(_ ctx: CGContext, to path: String) {
    let img = ctx.makeImage()!
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

func roundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// MARK: - Gauge drawing (shared by app icon & menu bar template)

/// Draws a speedometer gauge whose needle is the "hand" of the meter.
/// `tint` is the stroke/fill color. Drawn within a square of side `S`,
/// scaled by `scale` (fraction of S the gauge occupies).
func drawGauge(_ ctx: CGContext, S: CGFloat, tint: CGColor, scale: CGFloat) {
    let cx = S / 2
    let cy = S * 0.435            // pivot slightly below center so arc + needle fit
    let r  = S * 0.30 * (scale / 0.6)
    let lw = max(S * 0.052, 1)

    ctx.saveGState()
    ctx.setStrokeColor(tint)
    ctx.setFillColor(tint)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)

    let startA = deg(212), endA = deg(-32)   // ~244° sweep, open at the bottom

    // Main arc
    ctx.setLineWidth(lw)
    ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r,
               startAngle: startA, endAngle: endA, clockwise: true)
    ctx.strokePath()

    // Tick marks along the arc
    let ticks = 9
    let tickLong = S * 0.055
    let tickShort = S * 0.032
    for i in 0..<ticks {
        let t = CGFloat(i) / CGFloat(ticks - 1)
        let a = startA - (startA - endA) * t
        let isMajor = (i % 2 == 0)
        let inner = r - lw * 0.7 - (isMajor ? tickLong : tickShort)
        let outer = r - lw * 0.7
        let p1 = CGPoint(x: cx + cos(a) * inner, y: cy + sin(a) * inner)
        let p2 = CGPoint(x: cx + cos(a) * outer, y: cy + sin(a) * outer)
        ctx.setLineWidth(isMajor ? S * 0.022 : S * 0.014)
        ctx.move(to: p1); ctx.addLine(to: p2); ctx.strokePath()
    }

    // Needle ("the hand") pointing toward the upper-right / high reading
    let needleA = deg(52)
    let tip = CGPoint(x: cx + cos(needleA) * (r * 0.80),
                      y: cy + sin(needleA) * (r * 0.80))
    let back = CGPoint(x: cx - cos(needleA) * (r * 0.16),
                       y: cy - sin(needleA) * (r * 0.16))
    ctx.setLineWidth(S * 0.030)
    ctx.move(to: back); ctx.addLine(to: tip); ctx.strokePath()

    // Hub
    let hub = S * 0.052
    ctx.addEllipse(in: CGRect(x: cx - hub, y: cy - hub, width: hub * 2, height: hub * 2))
    ctx.fillPath()

    ctx.restoreGState()
}

// MARK: - App icon (rounded-square, gradient background, white gauge)

func drawAppIcon(_ px: Int) -> CGContext {
    let ctx = makeContext(px)
    let S = CGFloat(px)

    // macOS app-icon canvas: rounded square inset within the full bitmap.
    let inset = S * 0.094
    let rect = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let radius = rect.width * 0.2237

    let path = roundedRectPath(rect, radius: radius)
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()

    // Fond bleu ciel uniforme.
    let cs = CGColorSpaceCreateDeviceRGB()
    let sky = CGColor(colorSpace: cs, components: [0.318, 0.690, 0.965, 1])!   // #51B0F6
    ctx.setFillColor(sky)
    ctx.fill(rect)
    ctx.restoreGState()

    drawGauge(ctx, S: S, tint: CGColor(gray: 1, alpha: 1), scale: 0.62)
    return ctx
}

// MARK: - Menu bar template (black gauge on transparent, no background)

func drawMenuBar(_ px: Int) -> CGContext {
    let ctx = makeContext(px)
    let S = CGFloat(px)
    // Fill the frame more since there's no rounded-square padding.
    drawGauge(ctx, S: S, tint: CGColor(gray: 0, alpha: 1), scale: 0.80)
    return ctx
}

// MARK: - Brand logo (white gauge + « Handometer » wordmark, fond transparent)

/// Logo horizontal utilisé sur les cartes d'achievement (fond sombre) :
/// même jauge que l'icône d'app, suivie du wordmark en SF Rounded bold.
/// Retourne un contexte dont la largeur dépend du texte mesuré.
func drawBrandLogo(height: Int) -> CGContext {
    let H = CGFloat(height)
    let tint = NSColor(white: 1, alpha: 0.92)

    let font: NSFont = {
        let base = NSFont.systemFont(ofSize: H * 0.56, weight: .bold)
        if let rounded = base.fontDescriptor.withDesign(.rounded),
           let f = NSFont(descriptor: rounded, size: base.pointSize) {
            return f
        }
        return base
    }()
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: tint]
    let text = NSAttributedString(string: "Handometer", attributes: attributes)
    let textSize = text.size()

    let gaugeSide = H
    let spacing = H * 0.18
    let width = Int((gaugeSide + spacing + textSize.width).rounded(.up))

    let ctx = makeContext(width: width, height: height)
    drawGauge(ctx, S: gaugeSide, tint: tint.cgColor, scale: 0.85)

    let gc = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    text.draw(at: NSPoint(x: gaugeSide + spacing, y: (H - textSize.height) / 2))
    NSGraphicsContext.restoreGraphicsState()

    return ctx
}

// MARK: - Output

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconset = outDir + "/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// iconset members (Apple-required names)
let entries: [(name: String, px: Int)] = [
    ("icon_16x16",      16), ("icon_16x16@2x",   32),
    ("icon_32x32",      32), ("icon_32x32@2x",   64),
    ("icon_128x128",   128), ("icon_128x128@2x",256),
    ("icon_256x256",   256), ("icon_256x256@2x",512),
    ("icon_512x512",   512), ("icon_512x512@2x",1024),
]
for e in entries {
    writePNG(drawAppIcon(e.px), to: "\(iconset)/\(e.name).png")
}

// Menu bar template images (18pt @1x/@2x)
writePNG(drawMenuBar(18), to: "\(outDir)/menubar.png")
writePNG(drawMenuBar(36), to: "\(outDir)/menubar@2x.png")

// Brand logo (cartes d'achievement) — même jauge que l'icône d'app
writePNG(drawBrandLogo(height: 41), to: "\(outDir)/brand-logo.png")
writePNG(drawBrandLogo(height: 82), to: "\(outDir)/brand-logo@2x.png")

// A standalone large preview
writePNG(drawAppIcon(512), to: "\(outDir)/preview.png")

print("done")
