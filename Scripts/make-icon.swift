import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let canvas = NSRect(x: 72, y: 72, width: 880, height: 880)
NSColor(calibratedRed: 0.15, green: 0.17, blue: 0.23, alpha: 1).setFill()
NSBezierPath(roundedRect: canvas, xRadius: 210, yRadius: 210).fill()

var transform = AffineTransform()
transform.translate(x: 128, y: 168)
transform.scale(x: 39, y: 39)
func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: 128 + x * 39, y: 168 + y * 39) }
let back = NSBezierPath(roundedRect: NSRect(x: 1.25, y: 4.25, width: 12, height: 12), xRadius: 2.5, yRadius: 2.5)
back.transform(using: transform)
back.lineWidth = 36
back.lineJoinStyle = .round
NSColor(calibratedWhite: 0.72, alpha: 1).setStroke()
back.stroke()

let front = NSBezierPath()
front.move(to: point(9.25, 13.25))
front.line(to: point(16.25, 13.25))
front.curve(to: point(18.75, 10.75), controlPoint1: point(17.75, 13.25), controlPoint2: point(18.75, 12.25))
front.line(to: point(18.75, 5.75))
front.curve(to: point(16.25, 3.25), controlPoint1: point(18.75, 4.25), controlPoint2: point(17.75, 3.25))
front.line(to: point(15.5, 3.25))
front.line(to: point(13.5, 1.25))
front.line(to: point(12.5, 3.25))
front.line(to: point(9.25, 3.25))
front.curve(to: point(6.75, 5.75), controlPoint1: point(7.75, 3.25), controlPoint2: point(6.75, 4.25))
front.line(to: point(6.75, 10.75))
front.curve(to: point(9.25, 13.25), controlPoint1: point(6.75, 12.25), controlPoint2: point(7.75, 13.25))
front.lineWidth = 37
front.lineJoinStyle = .round
NSColor.white.setStroke()
front.stroke()
let lines = NSBezierPath()
lines.lineWidth = 33
lines.lineCapStyle = .round
for (start, end, y) in [(9.5, 15.5, 9.25), (9.5, 14.0, 6.75), (9.5, 12.5, 4.25)] {
    lines.move(to: point(start, y))
    lines.line(to: point(end, y))
}
lines.stroke()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: output)
