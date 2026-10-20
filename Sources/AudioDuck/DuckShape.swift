import AppKit

/// A side-view duck drawn in an 18×18 box (y up), used for both the menu bar and the app icon.
enum DuckShape {
    static let size: CGFloat = 18

    static var body: NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 1.2, y: 10.6))                       // tail tip
        path.curve(to: NSPoint(x: 4.6, y: 2.4), controlPoint1: NSPoint(x: 0.6, y: 6.2), controlPoint2: NSPoint(x: 1.8, y: 2.4))
        path.line(to: NSPoint(x: 12.2, y: 2.4))
        path.curve(to: NSPoint(x: 16.2, y: 6.8), controlPoint1: NSPoint(x: 14.8, y: 2.4), controlPoint2: NSPoint(x: 16.2, y: 4.4))
        path.curve(to: NSPoint(x: 12.6, y: 9.8), controlPoint1: NSPoint(x: 16.2, y: 8.6), controlPoint2: NSPoint(x: 14.6, y: 9.6))
        path.curve(to: NSPoint(x: 5.2, y: 8.0), controlPoint1: NSPoint(x: 9.8, y: 10.0), controlPoint2: NSPoint(x: 7.2, y: 7.6))
        path.curve(to: NSPoint(x: 1.2, y: 10.6), controlPoint1: NSPoint(x: 3.6, y: 8.3), controlPoint2: NSPoint(x: 2.4, y: 9.6))
        path.close()
        return path
    }

    static var head: NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: 8.6, y: 8.9, width: 6.8, height: 6.8))
    }

    static var beak: NSBezierPath {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 14.6, y: 13.1))
        path.curve(to: NSPoint(x: 17.6, y: 11.9), controlPoint1: NSPoint(x: 16.2, y: 13.2), controlPoint2: NSPoint(x: 17.6, y: 12.7))
        path.curve(to: NSPoint(x: 14.6, y: 10.9), controlPoint1: NSPoint(x: 17.6, y: 11.2), controlPoint2: NSPoint(x: 16.2, y: 10.8))
        path.close()
        return path
    }

    static var eye: NSBezierPath {
        NSBezierPath(ovalIn: NSRect(x: 12.0, y: 12.3, width: 1.5, height: 1.5))
    }

    /// Template image for the menu bar: a solid duck with the eye cut out.
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSColor.black.setFill()
            body.fill()
            head.fill()
            beak.fill()
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            eye.fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Audio Duck"
        return image
    }
}
