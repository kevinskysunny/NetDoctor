import AppKit
import Foundation

let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Assets.xcassets/AppIcon.appiconset", isDirectory: true)
let appIconURL = outputDirectory.appendingPathComponent("AppIcon.png")
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fatalError("Unable to create graphics context")
}

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

let outerRect = NSRect(origin: .zero, size: size)
let backgroundPath = NSBezierPath(roundedRect: outerRect, xRadius: 224, yRadius: 224)
let backgroundGradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.03, green: 0.10, blue: 0.23, alpha: 1.0),
    NSColor(calibratedRed: 0.02, green: 0.42, blue: 0.52, alpha: 1.0)
])!
backgroundGradient.draw(in: backgroundPath, angle: -58)

let center = NSPoint(x: 512, y: 520)
let ringRadius: CGFloat = 252

func circlePath(center: NSPoint, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(
        ovalIn: NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    )
}

NSColor(calibratedWhite: 1.0, alpha: 0.16).setStroke()
let outerRing = circlePath(center: center, radius: ringRadius)
outerRing.lineWidth = 12
outerRing.stroke()

let midRing = circlePath(center: center, radius: 184)
NSColor(calibratedWhite: 1.0, alpha: 0.20).setStroke()
midRing.lineWidth = 10
midRing.stroke()

let nodes = [
    NSPoint(x: center.x, y: center.y + 182),
    NSPoint(x: center.x - 158, y: center.y - 108),
    NSPoint(x: center.x + 158, y: center.y - 108)
]

let linePath = NSBezierPath()
for node in nodes {
    linePath.move(to: center)
    linePath.line(to: node)
}
NSColor(calibratedWhite: 1.0, alpha: 0.72).setStroke()
linePath.lineWidth = 24
linePath.lineCapStyle = .round
linePath.stroke()

for node in nodes {
    let nodePath = circlePath(center: node, radius: 52)
    NSColor(calibratedRed: 0.20, green: 0.84, blue: 0.72, alpha: 1.0).setFill()
    nodePath.fill()

    let highlight = circlePath(center: NSPoint(x: node.x - 14, y: node.y + 14), radius: 15)
    NSColor(calibratedWhite: 1.0, alpha: 0.55).setFill()
    highlight.fill()
}

let centerPath = circlePath(center: center, radius: 92)
NSColor(calibratedWhite: 1.0, alpha: 0.96).setFill()
centerPath.fill()

let healthPath = circlePath(center: center, radius: 42)
NSColor(calibratedRed: 0.05, green: 0.55, blue: 0.52, alpha: 1.0).setFill()
healthPath.fill()

let pulsePath = NSBezierPath()
pulsePath.move(to: NSPoint(x: center.x - 22, y: center.y))
pulsePath.line(to: NSPoint(x: center.x - 4, y: center.y))
pulsePath.line(to: NSPoint(x: center.x + 8, y: center.y + 25))
pulsePath.line(to: NSPoint(x: center.x + 22, y: center.y - 25))
pulsePath.line(to: NSPoint(x: center.x + 30, y: center.y))
pulsePath.line(to: NSPoint(x: center.x + 44, y: center.y))
NSColor(calibratedWhite: 1.0, alpha: 0.92).setStroke()
pulsePath.lineWidth = 16
pulsePath.lineCapStyle = .round
pulsePath.lineJoinStyle = .round
pulsePath.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render app icon")
}

try png.write(to: appIconURL, options: .atomic)
print(appIconURL.path)
