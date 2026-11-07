import Foundation

struct LyricsRecord: Codable, Sendable {
    let id: Int
    let trackName: String
    let artistName: String
    let albumName: String?
    let duration: TimeInterval?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?

    var lyrics: Lyrics? {
        if instrumental == true { return Lyrics(lines: [], instrumental: true) }
        if let syncedLyrics {
            let parsed = LRCParser.parse(syncedLyrics)
            if parsed.synchronized, parsed.lines.contains(where: { !$0.text.isEmpty }) { return parsed }
            if plainLyrics == nil, !parsed.lines.isEmpty { return parsed }
        }
        if let plainLyrics {
            let parsed = LRCParser.parse(plainLyrics)
            if !parsed.lines.isEmpty { return parsed }
        }
        return nil
    }
}

enum LyricsMatcher {
    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                     locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func best(_ records: [LyricsRecord], for track: Track) -> Lyrics? {
        let title = normalize(track.title)
        let artist = normalize(track.artist)
        let album = normalize(track.album)

        let matches = records.compactMap { record -> (Lyrics, Double, Int)? in
            guard normalize(record.trackName) == title, normalize(record.artistName) == artist,
                  let lyrics = record.lyrics else { return nil }

            let sameAlbum = !album.isEmpty && normalize(record.albumName ?? "") == album
            let difference = record.duration.map { abs($0 - track.duration) }
            if track.duration > 0 {
                guard let difference, difference.isFinite, difference <= 4 else { return nil }
            } else if !sameAlbum {
                return nil
            }

            let score = (sameAlbum ? 8.0 : 0) + (lyrics.synchronized ? 2 : 0)
                - (track.duration > 0 ? difference ?? 0 : 0)
            return (lyrics, score, record.id)
        }
        return matches.max { lhs, rhs in
            lhs.1 == rhs.1 ? lhs.2 > rhs.2 : lhs.1 < rhs.1
        }?.0
    }

    static func cacheKey(for track: Track) -> String {
        let duration = track.duration.isFinite ? String(format: "%.0f", track.duration) : "0"
        return [track.title, track.artist, track.album].map(normalize).joined(separator: "|") + "|" + duration
    }
}
