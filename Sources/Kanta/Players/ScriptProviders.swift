import Foundation

struct SpotifyProvider: ScriptProvider {
    let runner: AppleScriptRunner
    let source = MusicSource.spotify
    let trackIdentifier = "«property ID  »"
    let artworkProperty = "«property aUrl» of song"
    let durationScale = 0.001
    let transportSuite = "spfy"

    func artwork(for track: Track) async throws -> Data? {
        guard let url = track.artworkURL, url.scheme?.lowercased() == "https" else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              data.count <= 16_000_000 else { return nil }
        return data
    }
}

struct AppleMusicProvider: ScriptProvider {
    let runner: AppleScriptRunner
    let source = MusicSource.music
    let trackIdentifier = "«property pPIS»"
    let artworkProperty = "\"\""
    let durationScale = 1.0
    let transportSuite = "hook"

    func artwork(for track: Track) async throws -> Data? {
        // Persistent IDs are hexadecimal. Never interpolate arbitrary metadata into AppleScript.
        guard !track.id.isEmpty, track.id.utf8.allSatisfy({
            (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0)
        }) else { return nil }
        let output = try await runner.run(artworkScript(track.id), in: source)
        return Self.decodeArtwork(output)
    }

    func artworkScript(_ trackID: String) -> String {
        """
        set song to «property pTrk»
        if («property pPIS» of song as text) is not "\(trackID)" then return ""
        if (count of every «class cArt» of song) is 0 then return ""
        return «property pRaw» of «class cArt» 1 of song
        """
    }

    static func decodeArtwork(_ output: String) -> Data? {
        // osascript prints raw Apple Event data as «data TYPE<hex>».
        guard output.hasPrefix("«data "), output.hasSuffix("»"), output.count > 11 else { return nil }
        let hex = output.dropFirst(10).dropLast().utf8
        guard hex.count.isMultiple(of: 2), hex.count <= 32_000_000 else { return nil }
        var data = Data(capacity: hex.count / 2)
        var bytes = hex.makeIterator()
        while let first = bytes.next(), let second = bytes.next() {
            guard let high = Self.nibble(first), let low = Self.nibble(second) else { return nil }
            data.append(high << 4 | low)
        }
        return data
    }

    private static func nibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 48...57: return byte - 48
        case 65...70: return byte - 55
        case 97...102: return byte - 87
        default: return nil
        }
    }
}

protocol ScriptProvider: MusicProvider {
    var runner: AppleScriptRunner { get }
    var trackIdentifier: String { get }
    var artworkProperty: String { get }
    var durationScale: Double { get }
    var transportSuite: String { get }
}

extension ScriptProvider {
    func read() async throws -> Playback {
        let output = try await runner.run(snapshotScript, in: source)
        return try decodeSnapshot(output)
    }

    // Four-character terms come from the apps’ public scripting dictionaries.
    // They let AppleScript compile with a runtime bundle ID, without asking LaunchServices to open an app.
    var snapshotScript: String {
        """
        set mode to "stopped"
        set statusValue to «property pPlS»
        if statusValue is «constant ePlSkPSP» then set mode to "playing"
        if statusValue is «constant ePlSkPSp» then set mode to "paused"
        set song to «property pTrk»
        if song is missing value then return ""
        set trackID to ""
        try
            set identifier to \(trackIdentifier) of song
            if identifier is not missing value then set trackID to identifier as text
        end try
        set songName to («property pnam» of song) as text
        set artistName to ""
        set albumName to ""
        set songDuration to 0
        set elapsed to 0
        set imageURL to ""
        try
            set artistName to («property pArt» of song) as text
        end try
        try
            set albumName to («property pAlb» of song) as text
        end try
        try
            set songDuration to «property pDur» of song
        end try
        try
            set elapsed to «property pPos»
        end try
        try
            set imageURL to \(artworkProperty)
        end try
        set AppleScript's text item delimiters to character id 31
        return {trackID, songName, artistName, albumName, songDuration, elapsed, mode, imageURL} as text
        """
    }

    func decodeSnapshot(_ output: String, uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) throws -> Playback {
        let fields = output.components(separatedBy: "\u{1F}")
        guard fields.count == 8, !fields[1].isEmpty else { throw PlayerFailure.noTrack }
        let duration = number(fields[4]) * durationScale
        let metadataID = fields[1...4].joined(separator: "\u{1F}")
        let identity = fields[0].isEmpty ? "metadata:" + metadataID : fields[0]
        let track = Track(
            source: source, id: identity, title: fields[1], artist: fields[2], album: fields[3],
            duration: duration, artworkURL: fields[7].isEmpty ? nil : URL(string: fields[7])
        )
        let state: PlaybackState
        switch fields[6] {
        case "playing": state = .playing
        case "paused": state = .paused
        default: state = .stopped
        }
        return Playback(track: track, state: state, anchor: number(fields[5]), sampledAt: uptime)
    }

    func send(_ command: PlayerCommand) async throws {
        guard let script = commandScript(command) else { return }
        _ = try await runner.run(script, in: source)
    }

    func commandScript(_ command: PlayerCommand) -> String? {
        switch command {
        case .toggle: return "«event \(transportSuite)PlPs»"
        case .previous: return "«event \(transportSuite)Prev»"
        case .next: return "«event \(transportSuite)Next»"
        case .seek(let seconds):
            guard seconds.isFinite, seconds >= 0 else { return nil }
            return "set «property pPos» to \(seconds)"
        }
    }

    private func number(_ value: String) -> Double {
        let parsed = Double(value.replacingOccurrences(of: ",", with: ".")) ?? 0
        return parsed.isFinite ? max(0, parsed) : 0
    }
}
