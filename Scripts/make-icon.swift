import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
NSBezierPath(roundedRect: canvas.insetBy(dx: 72, dy: 72), xRadius: 230, yRadius: 230).fill()
let center = NSPoint(x: 512, y: 430)
let arc = NSBezierPath()
arc.lineWidth = 74
arc.lineCapStyle = .round
arc.appendArc(withCenter: center, radius: 240, startAngle: 20, endAngle: 160, clockwise: false)
NSColor(calibratedWhite: 0.45, alpha: 1).setStroke()
arc.stroke()
let active = NSBezierPath()
active.lineWidth = 74
active.lineCapStyle = .round
active.appendArc(withCenter: center, radius: 240, startAngle: 68, endAngle: 160, clockwise: false)
NSColor.white.setStroke()
active.stroke()
let needle = NSBezierPath()
needle.lineWidth = 28
needle.lineCapStyle = .round
needle.move(to: center)
needle.line(to: NSPoint(x: 610, y: 602))
needle.stroke()
NSBezierPath(ovalIn: NSRect(x: 477, y: 395, width: 70, height: 70)).fill()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
let png = rep.representation(using: .png, properties: [:])!
try png.write(to: output)
