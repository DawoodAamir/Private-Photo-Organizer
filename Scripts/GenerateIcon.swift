import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let output = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
var entries: [[String: String]] = []
func render(_ dimension: Int, filename: String, opaque: Bool) throws {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: dimension,
    pixelsHigh: dimension, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
    isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  let d = CGFloat(dimension)
  NSColor(calibratedRed: 0.13, green: 0.36, blue: 0.31, alpha: 1).setFill()
  if opaque {
    NSRect(x: 0, y: 0, width: d, height: d).fill()
  } else {
    NSBezierPath(
      roundedRect: NSRect(x: d * 0.04, y: d * 0.04, width: d * 0.92, height: d * 0.92),
      xRadius: d * 0.2, yRadius: d * 0.2
    ).fill()
  }
  NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.85, alpha: 1).setFill()
  NSBezierPath(
    roundedRect: NSRect(x: d * 0.21, y: d * 0.22, width: d * 0.58, height: d * 0.56),
    xRadius: d * 0.05, yRadius: d * 0.05
  ).fill()
  NSColor(calibratedRed: 0.65, green: 0.77, blue: 0.69, alpha: 1).setFill()
  NSBezierPath(
    roundedRect: NSRect(x: d * 0.26, y: d * 0.3, width: d * 0.48, height: d * 0.43),
    xRadius: d * 0.02, yRadius: d * 0.02
  ).fill()
  NSColor(calibratedRed: 0.91, green: 0.69, blue: 0.31, alpha: 1).setFill()
  NSBezierPath(ovalIn: NSRect(x: d * 0.56, y: d * 0.56, width: d * 0.11, height: d * 0.11)).fill()
  NSColor(calibratedRed: 0.22, green: 0.46, blue: 0.37, alpha: 1).setFill()
  let hills = NSBezierPath()
  hills.move(to: NSPoint(x: d * 0.26, y: d * 0.3))
  hills.line(to: NSPoint(x: d * 0.26, y: d * 0.4))
  hills.line(to: NSPoint(x: d * 0.42, y: d * 0.58))
  hills.line(to: NSPoint(x: d * 0.56, y: d * 0.43))
  hills.line(to: NSPoint(x: d * 0.65, y: d * 0.5))
  hills.line(to: NSPoint(x: d * 0.74, y: d * 0.4))
  hills.line(to: NSPoint(x: d * 0.74, y: d * 0.3))
  hills.close()
  hills.fill()
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(
    to: output.appendingPathComponent(filename))
}
for size in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let filename = "icon-\(size)-\(scale).png"
    try render(size * scale, filename: filename, opaque: false)
    entries.append([
      "idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename,
    ])
  }
}
try render(1024, filename: "ios-1024.png", opaque: true)
entries.append([
  "idiom": "universal", "platform": "ios", "size": "1024x1024", "filename": "ios-1024.png",
])
try JSONSerialization.data(
  withJSONObject: ["images": entries, "info": ["version": 1, "author": "xcode"]],
  options: [.prettyPrinted, .sortedKeys]
).write(to: output.appendingPathComponent("Contents.json"))
