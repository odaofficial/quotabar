import AppKit

// Original monochrome menu-bar mark: two overlapping context cards with short usage lines.
enum OdaMark {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let back = NSBezierPath(roundedRect: NSRect(x: 1.25, y: 4.25, width: 12, height: 12), xRadius: 2.5, yRadius: 2.5)
            back.lineWidth = 1.25
            back.stroke()
            let front = NSBezierPath(roundedRect: NSRect(x: 6.75, y: 1.25, width: 12, height: 12), xRadius: 2.5, yRadius: 2.5)
            front.lineWidth = 1.25
            front.stroke()
            let lines = NSBezierPath()
            lines.lineWidth = 1.25
            lines.lineCapStyle = .round
            lines.move(to: NSPoint(x: 9.5, y: 9.25))
            lines.line(to: NSPoint(x: 15.5, y: 9.25))
            lines.move(to: NSPoint(x: 9.5, y: 6.75))
            lines.line(to: NSPoint(x: 14, y: 6.75))
            lines.move(to: NSPoint(x: 9.5, y: 4.25))
            lines.line(to: NSPoint(x: 12.5, y: 4.25))
            lines.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
