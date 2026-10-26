import AppKit

// Original monochrome context/chat mark shared with the app icon.
enum QuotaMark {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            let back = NSBezierPath(roundedRect: NSRect(x: 1.25, y: 4.25, width: 12, height: 12), xRadius: 2.5, yRadius: 2.5)
            back.lineWidth = 1.25
            back.stroke()
            let front = NSBezierPath()
            front.move(to: NSPoint(x: 9.25, y: 13.25))
            front.line(to: NSPoint(x: 16.25, y: 13.25))
            front.curve(to: NSPoint(x: 18.75, y: 10.75), controlPoint1: NSPoint(x: 17.75, y: 13.25), controlPoint2: NSPoint(x: 18.75, y: 12.25))
            front.line(to: NSPoint(x: 18.75, y: 5.75))
            front.curve(to: NSPoint(x: 16.25, y: 3.25), controlPoint1: NSPoint(x: 18.75, y: 4.25), controlPoint2: NSPoint(x: 17.75, y: 3.25))
            front.line(to: NSPoint(x: 15.5, y: 3.25))
            front.line(to: NSPoint(x: 13.5, y: 1.25))
            front.line(to: NSPoint(x: 12.5, y: 3.25))
            front.line(to: NSPoint(x: 9.25, y: 3.25))
            front.curve(to: NSPoint(x: 6.75, y: 5.75), controlPoint1: NSPoint(x: 7.75, y: 3.25), controlPoint2: NSPoint(x: 6.75, y: 4.25))
            front.line(to: NSPoint(x: 6.75, y: 10.75))
            front.curve(to: NSPoint(x: 9.25, y: 13.25), controlPoint1: NSPoint(x: 6.75, y: 12.25), controlPoint2: NSPoint(x: 7.75, y: 13.25))
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
