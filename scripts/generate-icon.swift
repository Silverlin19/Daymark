import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()
guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to create graphics context")
}

context.setAllowsAntialiasing(true)
let outer = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 210, yRadius: 210)
outer.addClip()

let colorSpace = CGColorSpaceCreateDeviceRGB()
let colors = [
    NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.22, alpha: 1).cgColor,
    NSColor(calibratedRed: 0.32, green: 0.27, blue: 0.52, alpha: 1).cgColor
] as CFArray
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!
context.drawLinearGradient(gradient, start: CGPoint(x: 160, y: 900), end: CGPoint(x: 850, y: 90), options: [])

context.setFillColor(NSColor(calibratedRed: 0.99, green: 0.68, blue: 0.25, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 302, y: 330, width: 420, height: 420))

context.setFillColor(NSColor(calibratedRed: 0.96, green: 0.39, blue: 0.30, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 372, y: 400, width: 280, height: 280))

context.setFillColor(NSColor(calibratedRed: 0.13, green: 0.14, blue: 0.22, alpha: 1).cgColor)
context.fill(CGRect(x: 0, y: 300, width: 1024, height: 250))

context.setStrokeColor(NSColor.white.withAlphaComponent(0.93).cgColor)
context.setLineWidth(34)
context.setLineCap(.round)
context.move(to: CGPoint(x: 325, y: 260))
context.addLine(to: CGPoint(x: 440, y: 145))
context.addLine(to: CGPoint(x: 700, y: 405))
context.strokePath()

image.unlockFocus()

guard CommandLine.arguments.count > 1,
      let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to encode icon")
}

try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
