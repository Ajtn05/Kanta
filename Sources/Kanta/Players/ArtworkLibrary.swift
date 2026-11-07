import CoreGraphics
import Foundation
import ImageIO

struct Artwork: @unchecked Sendable {
    let image: CGImage
    let tint: SIMD3<Double>
}

actor ArtworkLibrary {
    private let files: LocalFiles
    init(files: LocalFiles = .cache) { self.files = files }

    func load(_ track: Track, provider: any MusicProvider) async -> Artwork? {
        let key = track.artworkURL?.absoluteString ?? track.identity
        if let data = files.read("Artwork", key), let artwork = decode(data) { return artwork }
        guard !Task.isCancelled, let data = try? await provider.artwork(for: track),
              !Task.isCancelled, let artwork = decode(data) else { return nil }

        try? files.write(data, folder: "Artwork", key: key)
        files.prune("Artwork", maximumBytes: 96_000_000)
        return artwork
    }

    private func decode(_ data: Data) -> Artwork? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024
              ] as CFDictionary) else { return nil }
        let tint: SIMD3<Double>
        if let context = CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let pixels = context.data?.assumingMemoryBound(to: UInt8.self) {
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            tint = SIMD3(Double(pixels[0]), Double(pixels[1]), Double(pixels[2])) / 255
        } else {
            tint = SIMD3(0.3, 0.3, 0.3)
        }
        return Artwork(image: image, tint: tint)
    }
}
