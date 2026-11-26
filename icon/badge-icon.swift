// Draws a round badge with an SF Symbol onto an app icon.
// Usage: swift badge-icon.swift <input.icns|png> <output.png> [symbol] [hexcolor]
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("usage: badge-icon.swift <input> <output.png> [symbol] [hexcolor]\n".data(using: .utf8)!)
    exit(64)
}
let symbolName = args.count > 3 ? args[3] : "house.fill"
let hex = args.count > 4 ? args[4] : "34A853"

func color(_ hex: String) -> NSColor {
    var v: UInt64 = 0
    Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}
func fail(_ msg: String) -> Never {
    FileHandle.standardError.write("badge-icon: \(msg)\n".data(using: .utf8)!); exit(1)
}

guard let base = NSImage(contentsOfFile: args[1]) else { fail("cannot read \(args[1])") }
guard let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
    fail("unknown SF Symbol '\(symbolName)'")
}

let size: CGFloat = 1024
guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fail("bitmap") }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

base.draw(in: NSRect(x: 0, y: 0, width: size, height: size))

// Badge: bottom-right, white ring around a filled circle.
let d = size * 0.40
let badge = NSRect(x: size * 0.92 - d, y: size * 0.08, width: d, height: d)
let ring = size * 0.022
NSColor.white.setFill()
NSBezierPath(ovalIn: badge).fill()
color(hex).setFill()
NSBezierPath(ovalIn: badge.insetBy(dx: ring, dy: ring)).fill()

let config = NSImage.SymbolConfiguration(pointSize: d * 0.42, weight: .bold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
if let glyph = symbol.withSymbolConfiguration(config) {
    let g = glyph.size
    glyph.draw(in: NSRect(x: badge.midX - g.width / 2, y: badge.midY - g.height / 2, width: g.width, height: g.height))
}

NSGraphicsContext.restoreGraphicsState()
guard let png = rep.representation(using: .png, properties: [:]) else { fail("png encode") }
do { try png.write(to: URL(fileURLWithPath: args[2])) } catch { fail("write \(args[2]): \(error)") }
