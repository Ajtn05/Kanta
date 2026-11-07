import AppKit

actor DemoProvider: MusicProvider {
    nonisolated let source = MusicSource.spotify
    private var index = 0
    private var anchor = 18.0
    private var state = PlaybackState.playing
    private var sampledAt = ProcessInfo.processInfo.systemUptime
    private let titles = ["A Quiet Kind of Light", "After the Rain"]

    func read() async throws -> Playback {
        let now = ProcessInfo.processInfo.systemUptime
        if state == .playing, anchor + now - sampledAt >= 194 {
            index = (index + 1) % titles.count
            anchor = 0
            sampledAt = now
        }
        return Playback(track: Track(source: source, id: "kanta-demo-\(index)", title: titles[index], artist: "Isla June",
                              album: "Low Tide", duration: 194), state: state, anchor: anchor, sampledAt: sampledAt)
    }

    func send(_ command: PlayerCommand) async throws {
        let playback = try await read()
        anchor = playback.position()
        sampledAt = ProcessInfo.processInfo.systemUptime
        switch command {
        case .toggle: state = state == .playing ? .paused : .playing
        case .next, .previous:
            index = (index + 1) % titles.count
            anchor = 0
        case .seek(let time): anchor = time
        }
    }

    func artwork(for track: Track) async throws -> Data? {
        let size = 700
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [CGColor(red: 0.11, green: 0.19, blue: 0.27, alpha: 1),
                      CGColor(red: 0.27, green: 0.49, blue: 0.49, alpha: 1),
                      CGColor(red: 0.95, green: 0.59, blue: 0.42, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.56, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 350, y: 700),
                                       options: [.drawsAfterEndLocation])
        }
        context.setFillColor(CGColor(red: 1, green: 0.78, blue: 0.51, alpha: 1))
        context.fillEllipse(in: CGRect(x: 280, y: 338, width: 225, height: 225))
        for layer in 0..<6 {
            let y = Double(323 - layer * 49)
            let wave = pathForRidge(height: y, layer: layer, width: Double(size))
            context.setFillColor(CGColor(red: 0.065 + Double(5 - layer) * 0.029,
                                         green: 0.16 + Double(5 - layer) * 0.044,
                                         blue: 0.21 + Double(5 - layer) * 0.034, alpha: 1))
            context.addPath(wave)
            context.fillPath()
        }
        guard let image = context.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.92])
    }

    private func pathForRidge(height: Double, layer: Int, width: Double) -> CGPath {
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: 0, y: height))
        for x in stride(from: 0.0, through: width, by: 3) {
            let ripple = sin(x / 113 + Double(layer)) * 38 + sin(x / 46 + Double(layer) * 0.7) * 13
            path.addLine(to: CGPoint(x: x, y: height + ripple))
        }
        path.addLine(to: CGPoint(x: width, y: 0))
        path.closeSubpath()
        return path
    }

    static let lyrics = LRCParser.parse("""
    [00:03.00]The evening comes in shades of blue
    [00:09.00]It leaves a little room for you
    [00:15.00]A quiet kind of light
    [00:22.00]Still dancing on the water
    [00:29.00]We take the longer way
    [00:36.00]And let the city fade away
    [00:44.00]
    [00:50.00]Somewhere the tide is turning
    [00:57.00]Somewhere a lamp is burning
    [01:04.00]Let the night fall slow
    [01:11.00]There’s nowhere else we have to go
    [01:19.00]A quiet kind of light
    [01:26.00]Still dancing on the water
    [01:34.00]
    [01:45.00]We take the longer way
    [01:52.00]And let the city fade away
    [02:02.00]The evening comes in shades of blue
    [02:12.00]It leaves a little room for you
    [02:25.00]A quiet kind of light
    [02:40.00]Still dancing on the water
    [03:00.00]
    """)
}
