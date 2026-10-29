import AppKit
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let background = NSBezierPath(roundedRect: NSRect(x: 48, y: 48, width: 928, height: 928), xRadius: 210, yRadius: 210)
NSGradient(starting: NSColor(calibratedRed: 0.30, green: 0.16, blue: 0.11, alpha: 1), ending: NSColor(calibratedRed: 0.10, green: 0.06, blue: 0.05, alpha: 1))!.draw(in: background, angle: -90)
let cream = NSColor(calibratedRed: 1, green: 0.89, blue: 0.70, alpha: 1)
let copper = NSColor(calibratedRed: 0.95, green: 0.57, blue: 0.28, alpha: 1)
copper.setStroke()
let handle = NSBezierPath(ovalIn: NSRect(x: 625, y: 346, width: 185, height: 200))
handle.lineWidth = 48
handle.stroke()
cream.setFill()
let cup = NSBezierPath()
cup.move(to: NSPoint(x: 255, y: 570))
cup.line(to: NSPoint(x: 695, y: 570))
cup.line(to: NSPoint(x: 666, y: 344))
cup.curve(to: NSPoint(x: 570, y: 268), controlPoint1: NSPoint(x: 660, y: 290), controlPoint2: NSPoint(x: 620, y: 268))
cup.line(to: NSPoint(x: 380, y: 268))
cup.curve(to: NSPoint(x: 284, y: 344), controlPoint1: NSPoint(x: 330, y: 268), controlPoint2: NSPoint(x: 290, y: 290))
cup.close()
cup.fill()
copper.setFill()
NSBezierPath(ovalIn: NSRect(x: 275, y: 540, width: 400, height: 47)).fill()
NSColor(calibratedRed: 0.24, green: 0.12, blue: 0.08, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 296, y: 548, width: 358, height: 24)).fill()
cream.setStroke()
let saucer = NSBezierPath()
saucer.move(to: NSPoint(x: 252, y: 228))
saucer.curve(to: NSPoint(x: 712, y: 228), controlPoint1: NSPoint(x: 365, y: 201), controlPoint2: NSPoint(x: 595, y: 201))
saucer.lineWidth = 25
saucer.lineCapStyle = .round
saucer.stroke()
copper.setStroke()
for x: CGFloat in [382, 482, 582] {
    let steam = NSBezierPath()
    steam.move(to: NSPoint(x: x, y: 637))
    steam.curve(to: NSPoint(x: x + 10, y: 800), controlPoint1: NSPoint(x: x - 62, y: 690), controlPoint2: NSPoint(x: x + 62, y: 745))
    steam.lineWidth = 25
    steam.lineCapStyle = .round
    steam.stroke()
}
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
