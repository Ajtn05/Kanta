import AppKit

// Drawn at each native icon size so the rings remain legible at 16 pt.
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let rgb = CGColorSpaceCreateDeviceRGB()

func draw(_ pixels: Int) -> Data {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                            bytesPerRow: 0, space: rgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let scale = CGFloat(pixels) / 1024
    context.scaleBy(x: scale, y: scale)
    let face = CGPath(roundedRect: CGRect(x: 98, y: 100, width: 828, height: 828),
                      cornerWidth: 190, cornerHeight: 190, transform: nil)
    context.setShadow(offset: CGSize(width: 0, height: -16), blur: 26,
                      color: CGColor(gray: 0, alpha: 0.35))
    context.addPath(face)
    context.setFillColor(CGColor(red: 0.10, green: 0.24, blue: 0.26, alpha: 1))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0, color: nil)
    context.addPath(face)
    context.clip()

    let colors = [CGColor(red: 0.07, green: 0.14, blue: 0.21, alpha: 1),
                  CGColor(red: 0.13, green: 0.38, blue: 0.38, alpha: 1),
                  CGColor(red: 0.40, green: 0.63, blue: 0.55, alpha: 1)] as CFArray
    let gradient = CGGradient(colorsSpace: rgb, colors: colors, locations: [0, 0.65, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 195, y: 95), end: CGPoint(x: 850, y: 930),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    let disc = CGRect(x: 232, y: 232, width: 560, height: 560)
    context.setFillColor(CGColor(red: 0.055, green: 0.14, blue: 0.17, alpha: 0.72))
    context.fillEllipse(in: disc)
    context.setStrokeColor(CGColor(red: 0.79, green: 0.92, blue: 0.82, alpha: 0.24))
    context.setLineWidth(9)
    for inset in [0.0, 34, 73, 113, 153] {
        context.strokeEllipse(in: disc.insetBy(dx: inset, dy: inset))
    }

    context.setFillColor(CGColor(red: 1, green: 0.78, blue: 0.53, alpha: 1))
    let bars: [CGFloat] = [81, 143, 221, 151, 94]
    for (index, height) in bars.enumerated() {
        let rect = CGRect(x: CGFloat(387 + index * 53), y: 512 - height / 2, width: 37, height: height)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: 18, cornerHeight: 18, transform: nil))
        context.fillPath()
    }
    return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}

func chunk(_ type: String, bytes: Data) -> Data {
    var result = Data(type.utf8)
    var length = UInt32(bytes.count + 8).bigEndian
    withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
    result.append(bytes)
    return result
}

let formats = [("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128), ("ic08", 256),
               ("ic09", 512), ("ic10", 1024), ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)]
var icon = Data()
for (type, size) in formats {
    icon.append(chunk(type, bytes: draw(size)))
}
try chunk("icns", bytes: icon).write(to: destination)
