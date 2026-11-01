// NetIcon.swift
// Draws the butterfly-net icon shown in the menu bar.
// It's a "template" image: macOS recolours it automatically for light/dark menu bars.

import AppKit

enum NetIcon {
    static let image: NSImage = {
        // 18 × 18 points is the standard menu bar icon size. `flipped: true` means y grows downwards.
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.setStroke()

            // Handle
            stroke(width: 1.4) { path in
                path.move(to: NSPoint(x: 2, y: 16.2))
                path.line(to: NSPoint(x: 7.4, y: 8.9))
            }

            // Hoop: an oval tilted 35° up to the right
            let hoop = NSBezierPath(ovalIn: NSRect(x: -5, y: -2.1, width: 10, height: 4.2))
            let tilt = NSAffineTransform()
            tilt.translateX(by: 11.5, yBy: 6)
            tilt.rotate(byDegrees: -35)
            hoop.transform(using: tilt as AffineTransform)
            hoop.lineWidth = 1.4
            hoop.stroke()

            // Net bag hanging from the hoop
            stroke(width: 1.2) { path in
                path.move(to: NSPoint(x: 7.6, y: 9.2))
                quad(path, to: NSPoint(x: 15.2, y: 13.2), control: NSPoint(x: 9.8, y: 13.6))
                quad(path, to: NSPoint(x: 15.6, y: 3.4), control: NSPoint(x: 17.2, y: 8.5))
            }

            // Mesh lines
            stroke(width: 0.9) { path in
                path.move(to: NSPoint(x: 12.7, y: 7.7))
                quad(path, to: NSPoint(x: 15.2, y: 13.2), control: NSPoint(x: 13.4, y: 11.4))
                path.move(to: NSPoint(x: 9.2, y: 11.4))
                quad(path, to: NSPoint(x: 16.3, y: 7.6), control: NSPoint(x: 13, y: 10.6))
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "CopyCatch"
        return image
    }()

    private static func stroke(width: CGFloat, _ build: (NSBezierPath) -> Void) {
        let path = NSBezierPath()
        path.lineWidth = width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        build(path)
        path.stroke()
    }

    /// Adds a quadratic curve (one control point) using NSBezierPath's cubic curve.
    private static func quad(_ path: NSBezierPath, to end: NSPoint, control: NSPoint) {
        let start = path.currentPoint
        let c1 = NSPoint(x: start.x + 2 / 3 * (control.x - start.x), y: start.y + 2 / 3 * (control.y - start.y))
        let c2 = NSPoint(x: end.x + 2 / 3 * (control.x - end.x), y: end.y + 2 / 3 * (control.y - end.y))
        path.curve(to: end, controlPoint1: c1, controlPoint2: c2)
    }
}
