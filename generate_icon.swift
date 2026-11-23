import AppKit
import CoreGraphics

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

func renderIcon(px: Int) -> Data? {
    let s = CGFloat(px)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil,
        width: px,
        height: px,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // 1. macOS squircle background (sibling style to Apollo AgentMeter)
    let margin = s * 0.08
    let rect = CGRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let corner = rect.width * 0.225
    let bgPath = CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)

    ctx.saveGState()
    ctx.setShadow(
        offset: CGSize(width: 0, height: -s * 0.02),
        blur: s * 0.05,
        color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.45)
    )
    ctx.addPath(bgPath)
    ctx.setFillColor(CGColor(srgbRed: 0.06, green: 0.07, blue: 0.14, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.clip()

    // Deep obsidian-to-violet-indigo gradient
    let bgColors = [
        CGColor(srgbRed: 0.13, green: 0.14, blue: 0.28, alpha: 1.0),
        CGColor(srgbRed: 0.05, green: 0.07, blue: 0.14, alpha: 1.0)
    ] as CFArray
    if let grad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            grad,
            start: CGPoint(x: s * 0.5, y: rect.maxY),
            end: CGPoint(x: s * 0.5, y: rect.minY),
            options: []
        )
    }

    // Ambient top-right violet-cyan glow
    let glowColors = [
        CGColor(srgbRed: 0.45, green: 0.38, blue: 1.0, alpha: 0.30),
        CGColor(srgbRed: 0.45, green: 0.38, blue: 1.0, alpha: 0.0)
    ] as CFArray
    if let rGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(
            rGrad,
            startCenter: CGPoint(x: s * 0.65, y: s * 0.72),
            startRadius: 0,
            endCenter: CGPoint(x: s * 0.65, y: s * 0.72),
            endRadius: s * 0.58,
            options: []
        )
    }

    // 2. 2x2 Modular Skill Tiles Grid
    let tileSize = s * 0.255
    let gap = s * 0.058
    let totalGrid = tileSize * 2 + gap
    let startX = (s - totalGrid) * 0.5
    let startY = (s - totalGrid) * 0.5 + s * 0.015
    let tileCorner = tileSize * 0.26

    func drawGradientTile(x: CGFloat, y: CGFloat, c1: CGColor, c2: CGColor, glow: CGColor) {
        let r = CGRect(x: x, y: y, width: tileSize, height: tileSize)
        let p = CGPath(roundedRect: r, cornerWidth: tileCorner, cornerHeight: tileCorner, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.035, color: glow)
        ctx.addPath(p)
        ctx.setFillColor(c1)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(p)
        ctx.clip()
        if let g = CGGradient(colorsSpace: colorSpace, colors: [c1, c2] as CFArray, locations: [0.0, 1.0]) {
            ctx.drawLinearGradient(
                g,
                start: CGPoint(x: r.minX, y: r.maxY),
                end: CGPoint(x: r.maxX, y: r.minY),
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )
        }
        ctx.restoreGState()

        // Crisp inner highlight stroke
        ctx.saveGState()
        ctx.addPath(p)
        ctx.setLineWidth(max(1.0, s * 0.01))
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.28))
        ctx.strokePath()
        ctx.restoreGState()
    }

    // Top-Left Tile: Emerald -> Teal (Active Skill / Antigravity)
    drawGradientTile(
        x: startX,
        y: startY + tileSize + gap,
        c1: CGColor(srgbRed: 0.16, green: 0.90, blue: 0.58, alpha: 1.0),
        c2: CGColor(srgbRed: 0.10, green: 0.66, blue: 0.64, alpha: 1.0),
        glow: CGColor(srgbRed: 0.16, green: 0.90, blue: 0.58, alpha: 0.35)
    )

    // Top-Right Tile: Sky Blue -> Indigo (Codex)
    drawGradientTile(
        x: startX + tileSize + gap,
        y: startY + tileSize + gap,
        c1: CGColor(srgbRed: 0.28, green: 0.72, blue: 1.00, alpha: 1.0),
        c2: CGColor(srgbRed: 0.28, green: 0.42, blue: 0.96, alpha: 1.0),
        glow: CGColor(srgbRed: 0.28, green: 0.72, blue: 1.00, alpha: 0.35)
    )

    // Bottom-Left Tile: Violet -> Magenta-Purple (Claude / Categories)
    drawGradientTile(
        x: startX,
        y: startY,
        c1: CGColor(srgbRed: 0.64, green: 0.46, blue: 1.00, alpha: 1.0),
        c2: CGColor(srgbRed: 0.48, green: 0.26, blue: 0.90, alpha: 1.0),
        glow: CGColor(srgbRed: 0.64, green: 0.46, blue: 1.00, alpha: 0.35)
    )

    // Bottom-Right Tile: Glassy Toggle Track Tile (representing 1-click switch hub)
    let brRect = CGRect(x: startX + tileSize + gap, y: startY, width: tileSize, height: tileSize)
    let brPath = CGPath(roundedRect: brRect, cornerWidth: tileCorner, cornerHeight: tileCorner, transform: nil)
    ctx.saveGState()
    ctx.addPath(brPath)
    ctx.setFillColor(CGColor(srgbRed: 0.18, green: 0.22, blue: 0.36, alpha: 0.92))
    ctx.fillPath()
    ctx.addPath(brPath)
    ctx.setLineWidth(max(1.0, s * 0.012))
    ctx.setStrokeColor(CGColor(srgbRed: 0.45, green: 0.75, blue: 1.0, alpha: 0.55))
    ctx.strokePath()
    ctx.restoreGState()

    // Mini iOS Toggle Switch inside Bottom-Right Tile
    let swW = tileSize * 0.66
    let swH = tileSize * 0.36
    let swRect = CGRect(
        x: brRect.midX - swW * 0.5,
        y: brRect.midY - swH * 0.5,
        width: swW,
        height: swH
    )
    let swPath = CGPath(roundedRect: swRect, cornerWidth: swH * 0.5, cornerHeight: swH * 0.5, transform: nil)
    ctx.saveGState()
    ctx.addPath(swPath)
    ctx.setFillColor(CGColor(srgbRed: 0.18, green: 0.86, blue: 0.54, alpha: 1.0))
    ctx.fillPath()
    let thumbD = swH * 0.76
    let thumbRect = CGRect(
        x: swRect.maxX - thumbD - swH * 0.12,
        y: swRect.midY - thumbD * 0.5,
        width: thumbD,
        height: thumbD
    )
    ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1.0))
    ctx.fillEllipse(in: thumbRect)
    ctx.restoreGState()

    // 3. Central Glowing AI Sparkle Hub uniting all 4 skill tiles
    let center = CGPoint(x: s * 0.5, y: startY + totalGrid * 0.5)
    let hubBgR = s * 0.095
    ctx.saveGState()
    ctx.setFillColor(CGColor(srgbRed: 0.07, green: 0.09, blue: 0.18, alpha: 0.96))
    ctx.fillEllipse(in: CGRect(x: center.x - hubBgR, y: center.y - hubBgR, width: hubBgR * 2, height: hubBgR * 2))
    ctx.setLineWidth(max(1.0, s * 0.012))
    ctx.setStrokeColor(CGColor(srgbRed: 0.65, green: 0.86, blue: 1.0, alpha: 0.65))
    ctx.strokeEllipse(in: CGRect(x: center.x - hubBgR, y: center.y - hubBgR, width: hubBgR * 2, height: hubBgR * 2))
    ctx.restoreGState()

    let spR = s * 0.062
    let spIn = s * 0.018
    let spPath = CGMutablePath()
    spPath.move(to: CGPoint(x: center.x, y: center.y + spR))
    spPath.addQuadCurve(to: CGPoint(x: center.x + spR, y: center.y), control: CGPoint(x: center.x + spIn, y: center.y + spIn))
    spPath.addQuadCurve(to: CGPoint(x: center.x, y: center.y - spR), control: CGPoint(x: center.x + spIn, y: center.y - spIn))
    spPath.addQuadCurve(to: CGPoint(x: center.x - spR, y: center.y), control: CGPoint(x: center.x - spIn, y: center.y - spIn))
    spPath.addQuadCurve(to: CGPoint(x: center.x, y: center.y + spR), control: CGPoint(x: center.x - spIn, y: center.y + spIn))
    spPath.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.03, color: CGColor(srgbRed: 0.4, green: 0.88, blue: 1.0, alpha: 0.85))
    ctx.addPath(spPath)
    ctx.setFillColor(CGColor(srgbRed: 0.98, green: 0.99, blue: 1.0, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.restoreGState() // end squircle clip

    // Outer squircle border highlight
    ctx.saveGState()
    ctx.addPath(bgPath)
    ctx.setLineWidth(max(1.0, s * 0.014))
    ctx.setStrokeColor(CGColor(srgbRed: 0.52, green: 0.62, blue: 1.0, alpha: 0.35))
    ctx.strokePath()
    ctx.restoreGState()

    guard let cgImg = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImg)
    return rep.representation(using: .png, properties: [:])
}

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "\(scriptDir)/AppIcon.iconset"

try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

for item in sizes {
    if let data = renderIcon(px: item.px) {
        let url = URL(fileURLWithPath: "\(outDir)/\(item.name)")
        try! data.write(to: url)
    }
}

let icnsPath = CommandLine.arguments.count > 2
    ? CommandLine.arguments[2]
    : "\(scriptDir)/AppIcon.icns"

let icnsTypes: [(ostype: String, px: Int)] = [
    ("icp4", 16), ("icp5", 32), ("icp6", 64),
    ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024),
    ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)
]

func u32BE(_ val: UInt32) -> Data {
    var v = val.bigEndian
    return Data(bytes: &v, count: 4)
}

var bodyData = Data()
for entry in icnsTypes {
    if let png = renderIcon(px: entry.px) {
        bodyData.append(entry.ostype.data(using: .ascii)!)
        bodyData.append(u32BE(UInt32(8 + png.count)))
        bodyData.append(png)
    }
}

var icnsData = Data()
icnsData.append("icns".data(using: .ascii)!)
icnsData.append(u32BE(UInt32(8 + bodyData.count)))
icnsData.append(bodyData)
try! icnsData.write(to: URL(fileURLWithPath: icnsPath))
print("Generated Apollo SkillHub AppIcon.icns (\(icnsData.count) bytes)")
