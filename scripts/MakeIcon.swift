// Renders the app icon from DuckShape into the asset catalog. Run with `make icon`.
// Pass a file path as an argument to also write a large preview of the menu bar icon there.
import AppKit

@main
enum MakeIcon {
    static let iconSet = URL(fileURLWithPath: "Sources/AudioDuck/Assets.xcassets/AppIcon.appiconset")

    static func main() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: iconSet, withIntermediateDirectories: true)
        try write(#"{ "info" : { "author" : "xcode", "version" : 1 } }"#, to: iconSet.deletingLastPathComponent().appendingPathComponent("Contents.json"))

        var images: [String] = []
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
                try png(pixels: points * scale) { drawIcon() }.write(to: iconSet.appendingPathComponent(name))
                images.append(#"{ "idiom" : "mac", "size" : "\#(points)x\#(points)", "scale" : "\#(scale)x", "filename" : "\#(name)" }"#)
            }
        }
        try write(#"{ "images" : [ "# + images.joined(separator: ",\n") + #" ], "info" : { "author" : "xcode", "version" : 1 } }"#,
                  to: iconSet.appendingPathComponent("Contents.json"))

        if CommandLine.arguments.count > 1 {
            let preview = try png(pixels: 360) {
                NSColor.white.setFill()
                NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()
                let image = DuckShape.menuBarImage()
                image.isTemplate = false
                image.draw(in: NSRect(x: 112, y: 112, width: 800, height: 800))
            }
            try preview.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        }
        print("Wrote \(iconSet.path)")
    }

    /// Draws in a 1024×1024 canvas, following the macOS icon grid (824pt rounded square).
    static func drawIcon() {
        let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
        let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -10)
        shadow.set()
        NSColor(hex: 0x58B7EE).setFill()
        tilePath.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        tilePath.addClip()
        NSGradient(starting: NSColor(hex: 0x9BDDFB), ending: NSColor(hex: 0x3E9FE0))!.draw(in: tile, angle: -90)

        // The duck, scaled from its 18pt box. The water is drawn over it so it looks afloat.
        let scale: CGFloat = 36
        let transform = NSAffineTransform()
        transform.translateX(by: 512 - DuckShape.size * scale / 2, yBy: 225)
        transform.scale(by: scale)
        func fill(_ path: NSBezierPath, _ color: NSColor) {
            color.setFill()
            transform.transform(path).fill()
        }
        fill(DuckShape.body, NSColor(hex: 0xFFC83D))
        fill(DuckShape.beak, NSColor(hex: 0xFF7A2F))
        fill(DuckShape.head, NSColor(hex: 0xFFC83D))
        fill(DuckShape.eye, NSColor(hex: 0x2A2A2A))

        // Water, with a gentle wave along the top.
        let water = NSBezierPath()
        water.move(to: NSPoint(x: 100, y: 330))
        for i in 0..<4 {
            let x = 100 + CGFloat(i) * 206
            water.curve(to: NSPoint(x: x + 206, y: 330),
                        controlPoint1: NSPoint(x: x + 70, y: 360), controlPoint2: NSPoint(x: x + 136, y: 300))
        }
        water.line(to: NSPoint(x: 924, y: 100))
        water.line(to: NSPoint(x: 100, y: 100))
        water.close()
        NSColor(hex: 0x1F78C1).setFill()
        water.fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    static func png(pixels: Int, draw: () -> Void) throws -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let scale = NSAffineTransform()
        scale.scale(by: CGFloat(pixels) / 1024)
        scale.concat()
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])!
    }

    static func write(_ string: String, to url: URL) throws {
        try string.write(to: url, atomically: true, encoding: .utf8)
    }
}

private extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
