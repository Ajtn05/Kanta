import AppKit

// Drawn at each native icon size, with simpler lyric lines for small icons.
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

    let small = pixels <= 32
    let cream = CGColor(red: 0.85, green: 0.95, blue: 0.89, alpha: 1)
    let peach = CGColor(red: 1, green: 0.80, blue: 0.57, alpha: 1)

    func lyricLine(x: CGFloat, y: CGFloat, width: CGFloat, weight: CGFloat,
                   color: CGColor, opacity: CGFloat = 1) {
        context.setAlpha(opacity)
        context.setStrokeColor(color)
        context.setLineWidth(weight)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: x, y: y))
        context.addLine(to: CGPoint(x: x + width, y: y))
        context.strokePath()
        context.setAlpha(1)
    }

    // Surrounding lyrics recede above and below the current line.
    if !small {
        lyricLine(x: 398, y: 728, width: 228, weight: 30, color: cream, opacity: 0.20)
        lyricLine(x: 368, y: 300, width: 288, weight: 30, color: cream, opacity: 0.20)
    }
    lyricLine(x: 302, y: 630, width: 420, weight: small ? 48 : 34, color: cream, opacity: 0.48)
    lyricLine(x: 322, y: 398, width: 380, weight: small ? 48 : 34, color: cream, opacity: 0.48)

    if !small {
        context.setFillColor(CGColor(red: 0.025, green: 0.12, blue: 0.15, alpha: 0.30))
        context.addPath(CGPath(roundedRect: CGRect(x: 220, y: 444, width: 584, height: 142),
                               cornerWidth: 52, cornerHeight: 52, transform: nil))
        context.fillPath()
    }

    // A musical note leads the warm, highlighted lyric, like a karaoke cursor.
    context.setFillColor(peach)
    context.fillEllipse(in: CGRect(x: 266, y: 474, width: 78, height: 58))
    context.setStrokeColor(peach)
    context.setLineWidth(28)
    context.move(to: CGPoint(x: 330, y: 506))
    context.addLine(to: CGPoint(x: 330, y: 566))
    context.addLine(to: CGPoint(x: 376, y: 552))
    context.strokePath()

    if small {
        lyricLine(x: 430, y: 514, width: 306, weight: 58, color: peach)
    } else {
        lyricLine(x: 430, y: 514, width: 116, weight: 46, color: peach)
        lyricLine(x: 604, y: 514, width: 132, weight: 46, color: peach)
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
if CommandLine.arguments.count > 2 {
    try draw(256).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
