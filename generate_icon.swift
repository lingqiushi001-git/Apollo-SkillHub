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

let space = CGColorSpace(name: CGColorSpace.sRGB)!

func ink(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}

func renderIcon(px: Int) -> Data? {
    guard let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                            bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    // Design units use a 1000-square grid with the origin at bottom left.
    let scale = CGFloat(px) / 1000
    c.scaleBy(x: scale, y: scale)
    let small = px <= 32
    let hairline = max(1.4, 0.55 / scale)

    func gradient(_ path: CGPath, _ colors: [CGColor]) {
        c.saveGState()
        c.addPath(path)
        c.clip()
        let bounds = path.boundingBoxOfPath
        let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
        c.drawLinearGradient(gradient, start: CGPoint(x: bounds.midX, y: bounds.maxY),
                             end: CGPoint(x: bounds.midX, y: bounds.minY), options: [])
        c.restoreGState()
    }

    func stroke(_ path: CGPath, _ color: CGColor, _ width: CGFloat) {
        c.addPath(path)
        c.setStrokeColor(color)
        c.setLineWidth(width)
        c.setLineCap(.round)
        c.strokePath()
    }

    func raisedPanel(_ path: CGPath, top: Int, bottom: Int, depth: CGFloat) {
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -depth * scale),
                    blur: depth * 2.4 * scale, color: ink(0, 0.5))
        c.addPath(path)
        c.setFillColor(ink(bottom))
        c.fillPath()
        c.restoreGState()
        gradient(path, [ink(top), ink(bottom)])
    }

    let face = CGRect(x: 80, y: 80, width: 840, height: 840)
    let radius = face.width * 0.225
    let base = CGPath(roundedRect: face, cornerWidth: radius, cornerHeight: radius, transform: nil)
    raisedPanel(base, top: 0x181D27, bottom: 0x0B0E14, depth: 14)
    c.saveGState()
    c.addPath(base)
    c.clip()
    let reflection = CGGradient(colorsSpace: space, colors: [ink(0xBCCFE3, 0.07), ink(0xBCCFE3, 0)] as CFArray, locations: nil)!
    c.saveGState()
    c.translateBy(x: 500, y: 76)
    c.scaleBy(x: 1, y: 0.23)
    c.drawRadialGradient(reflection, startCenter: .zero, startRadius: 0,
                         endCenter: .zero, endRadius: 370, options: [])
    c.restoreGState()
    if !small {
        c.setFillColor(ink(0xffffff, 0.045))
        for x in stride(from: 100, through: 900, by: 20) {
            for y in stride(from: 100, through: 900, by: 20) {
                c.fillEllipse(in: CGRect(x: CGFloat(x)-1.2, y: CGFloat(y)-1.2, width: 2.4, height: 2.4))
            }
        }
    }
    let edge = base.copy(strokingWithWidth: hairline * 2, lineCap: .round, lineJoin: .round, miterLimit: 1)
    gradient(edge, [ink(0xffffff, 0.22), ink(0xffffff, 0.05)])
    c.restoreGState()

    let routes: [(y: CGFloat, signal: Int, light: Int)] = [
        (710, 0x10B981, 0xD1FAE5), (290, 0xF59E0B, 0xFEF3C7), (500, 0x3B82F6, 0xDBEAFE)
    ]
    let gauge: CGFloat = small ? 49 : 42
    for route in routes {
        let trace = CGMutablePath()
        trace.move(to: CGPoint(x: 432, y: 500))
        trace.addCurve(to: CGPoint(x: 760, y: route.y), control1: CGPoint(x: 590, y: 500),
                       control2: CGPoint(x: 565, y: route.y))
        stroke(trace, ink(0x06090D), gauge + 10)
        c.saveGState()
        c.setShadow(offset: .zero, blur: 9 * scale, color: ink(route.signal, 0.32))
        stroke(trace, ink(route.signal), gauge)
        c.restoreGState()
        let wire = trace.copy(strokingWithWidth: gauge, lineCap: .round, lineJoin: .round, miterLimit: 1)
        gradient(wire, [ink(route.light, 0.14), ink(route.signal, 0), ink(0, 0.09)])
    }
    for route in routes {
        func disc(_ diameter: CGFloat) -> CGPath {
            CGPath(ellipseIn: CGRect(x: 760-diameter/2, y: route.y-diameter/2,
                                     width: diameter, height: diameter), transform: nil)
        }
        let socket = disc(small ? 133 : 115)
        raisedPanel(socket, top: 0x36404D, bottom: 0x10151E, depth: 4)
        stroke(socket, ink(0xffffff, 0.15), hairline)
        let lens = disc(small ? 92 : 76)
        stroke(lens, ink(0x070B10), 5)
        gradient(lens, [ink(route.light), ink(route.signal), ink(route.signal)])
        c.addPath(disc(small ? 33 : 24))
        c.setFillColor(ink(route.light))
        c.fillPath()
    }

    let core = CGRect(x: small ? 166 : 189, y: small ? 350 : 368,
                      width: small ? 300 : 264, height: small ? 300 : 264)
    let corner = core.width * 0.24
    let plate = CGPath(roundedRect: core, cornerWidth: corner, cornerHeight: corner, transform: nil)
    raisedPanel(plate, top: 0x202736, bottom: 0x141923, depth: 10)
    c.addPath(plate)
    c.clip()
    stroke(plate, ink(0xffffff, 0.18), hairline * 2)

    // A single cut-metal silhouette. Widen the legs at list-icon sizes.
    c.translateBy(x: core.midX, y: core.midY)
    let markScale: CGFloat = small ? 1.30 : 1
    c.scaleBy(x: markScale, y: markScale)
    let mark = CGMutablePath()
    mark.move(to: CGPoint(x: 0, y: 86))
    for point in [CGPoint(x: 86, y: -72), CGPoint(x: small ? 40 : 49, y: -72),
                  CGPoint(x: 33, y: -43), CGPoint(x: -33, y: -43),
                  CGPoint(x: small ? -40 : -49, y: -72), CGPoint(x: -86, y: -72)] {
        mark.addLine(to: point)
    }
    mark.closeSubpath()
    mark.move(to: CGPoint(x: 0, y: 21))
    mark.addLine(to: CGPoint(x: -17, y: -15))
    mark.addLine(to: CGPoint(x: 17, y: -15))
    mark.closeSubpath()
    c.addPath(mark)
    c.setFillColor(ink(0xffffff))
    c.drawPath(using: .eoFill)

    guard let image = c.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}

let scriptDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().path
let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "\(scriptDir)/AppIcon.iconset"

try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
var rendered = [Int: Data]()
for item in sizes {
    guard let data = rendered[item.px] ?? renderIcon(px: item.px) else {
        throw CocoaError(.fileWriteUnknown)
    }
    rendered[item.px] = data
    try data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(item.name), options: .atomic)
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
    if let png = rendered[entry.px] {
        bodyData.append(entry.ostype.data(using: .ascii)!)
        bodyData.append(u32BE(UInt32(8 + png.count)))
        bodyData.append(png)
    }
}

var icnsData = Data()
icnsData.append("icns".data(using: .ascii)!)
icnsData.append(u32BE(UInt32(8 + bodyData.count)))
icnsData.append(bodyData)
try icnsData.write(to: URL(fileURLWithPath: icnsPath), options: .atomic)
print("Generated Apollo AgentHub AppIcon.icns (\(icnsData.count) bytes)")
